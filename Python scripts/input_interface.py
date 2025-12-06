import tkinter as tk
import serial
import time
import math
import threading
from PIL import Image

# ------------------- Configuration -------------------
SERIAL_PORT = "COM3"    # Replace with your Basys3 UART port
BAUD_RATE = 115200

WORK_GRID_SIZE = 32     # internal high-res grid
FINAL_GRID_SIZE = 16    # FPGA input grid
CELL_SIZE = 10          # size of each work-grid cell in GUI
PADDING = 20            # padding around grid in window

# This now acts as a "Cooldown" to prevent flooding UART while dragging mouse
MIN_SEND_INTERVAL = 0.5
BRUSH_RADIUS = 2.0       
ACK_TIMEOUT = 0.5        

PREAMBLE = bytes([0xAA, 0x55])
ACK_BYTE = b'\x06'
NAK_BYTE = b'\x15'

# ------------------- Initialize UART -------------------
try:
    ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=0.05)
    time.sleep(0.2) 
except serial.SerialException as e:
    print(f"Error opening serial port: {e}")
    ser = None

# ------------------- Global State -------------------
needs_send = False  # <--- NEW: Flag to track changes

# ------------------- GUI -------------------
root = tk.Tk()
root.title("16x16 Digit Input Interface")

work_grid = [[0 for _ in range(WORK_GRID_SIZE)] for _ in range(WORK_GRID_SIZE)]
rects = [[None for _ in range(WORK_GRID_SIZE)] for _ in range(WORK_GRID_SIZE)]
grid_lock = threading.Lock()

canvas_size = WORK_GRID_SIZE * CELL_SIZE + 2 * PADDING
canvas = tk.Canvas(root, width=canvas_size, height=canvas_size, bg="white")
canvas.pack()

def intensity_to_color(val):
    gray = 255 - int(val) 
    return f"#{gray:02x}{gray:02x}{gray:02x}"

def draw_grid():
    for i in range(WORK_GRID_SIZE):
        for j in range(WORK_GRID_SIZE):
            x0 = PADDING + j*CELL_SIZE
            y0 = PADDING + i*CELL_SIZE
            x1 = x0 + CELL_SIZE
            y1 = y0 + CELL_SIZE
            rects[i][j] = canvas.create_rectangle(
                x0, y0, x1, y1,
                fill=intensity_to_color(0),
                outline="gray"
            )

def paint_cell(row, col, intensity):
    global needs_send
    """Add intensity (0–255) to a cell, clipped"""
    if 0 <= row < WORK_GRID_SIZE and 0 <= col < WORK_GRID_SIZE:
        with grid_lock:
            # Only update if the value actually changes to save processing
            if work_grid[row][col] < 255:
                work_grid[row][col] = min(255, max(0, work_grid[row][col] + intensity))
                canvas.itemconfig(rects[row][col], fill=intensity_to_color(work_grid[row][col]))
                needs_send = True  # <--- Mark that data has changed

def brush_paint(event):
    col = (event.x - PADDING) // CELL_SIZE
    row = (event.y - PADDING) // CELL_SIZE
    if 0 <= row < WORK_GRID_SIZE and 0 <= col < WORK_GRID_SIZE:
        for di in range(-int(BRUSH_RADIUS*2), int(BRUSH_RADIUS*2)+1):
            for dj in range(-int(BRUSH_RADIUS*2), int(BRUSH_RADIUS*2)+1):
                r, c = row + di, col + dj
                dist = math.sqrt(di*di + dj*dj)
                if dist <= BRUSH_RADIUS:
                    add_intensity = int(255 * (1 - dist / (BRUSH_RADIUS+0.1)))
                    paint_cell(r, c, add_intensity)

def clear_grid():
    global needs_send
    with grid_lock:
        for i in range(WORK_GRID_SIZE):
            for j in range(WORK_GRID_SIZE):
                work_grid[i][j] = 0
                canvas.itemconfig(rects[i][j], fill=intensity_to_color(0))
        needs_send = True # <--- Mark that data has changed

def downsample_grid_copy():
    with grid_lock:
        flat = [work_grid[i][j] for i in range(WORK_GRID_SIZE) for j in range(WORK_GRID_SIZE)]
    img = Image.new("L", (WORK_GRID_SIZE, WORK_GRID_SIZE))
    img.putdata(flat)
    img = img.resize((FINAL_GRID_SIZE, FINAL_GRID_SIZE), Image.Resampling.LANCZOS)
    return list(img.getdata())

def send_frame_and_wait_ack(payload_bytes):
    if ser is None: return False
    
    checksum = sum(payload_bytes) & 0xFF
    pkt = PREAMBLE + bytes(payload_bytes) + bytes([checksum])
    try:
        ser.reset_input_buffer()
        ser.write(pkt)
        ser.flush()
    except Exception as e:
        print("Serial write error:", e)
        return False

    deadline = time.time() + ACK_TIMEOUT
    while time.time() < deadline:
        if ser.in_waiting > 0:
            resp = ser.read(1)
            if resp == ACK_BYTE:
                return True
            if resp == NAK_BYTE:
                return False
        time.sleep(0.005) # Check tighter loop
    return False

def sender_thread_fn():
    global needs_send
    while True:
        if needs_send:
            # 1. Reset flag immediately so we catch changes that happen 
            #    while we are busy sending this frame.
            needs_send = False 
            
            # 2. Prepare data
            payload = downsample_grid_copy()
            
            # 3. Send
            print("Grid changed -> Sending frame...")
            ok = send_frame_and_wait_ack(payload)
            
            if ok:
                print("Success")
            else:
                print("Failed (No ACK)")
                # If failed, force a retry next loop by setting flag back to True
                needs_send = True 
            
            # 4. Cooldown (Debounce)
            # This prevents sending 100 packets per second while you drag the mouse.
            time.sleep(MIN_SEND_INTERVAL)
            
        else:
            # If no changes, sleep to save CPU
            time.sleep(0.05)

# start sender background thread
sender_thread = threading.Thread(target=sender_thread_fn, daemon=True)
sender_thread.start()

# Bindings and GUI buttons
canvas.bind("<B1-Motion>", brush_paint)
canvas.bind("<Button-1>", brush_paint)
# Optional: Trigger a final send immediately on mouse release to catch the final pixel
canvas.bind("<ButtonRelease-1>", lambda e: None) 

btn_frame = tk.Frame(root)
btn_frame.pack(pady=10)
tk.Button(btn_frame, text="Clear", command=clear_grid).pack(side=tk.LEFT, padx=10)

# -------- Start --------
draw_grid()
root.mainloop()