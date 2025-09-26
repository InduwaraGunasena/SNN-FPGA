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

UPDATE_INTERVAL = 0.25   # seconds between frames (float seconds)
BRUSH_RADIUS = 2.0       # brush size in work-grid units
ACK_TIMEOUT = 0.5        # seconds to wait for ACK

PREAMBLE = bytes([0xAA, 0x55])
ACK_BYTE = b'\x06'
NAK_BYTE = b'\x15'

# ------------------- Initialize UART -------------------
ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=0.05)
time.sleep(0.2)  # Give time for Basys3 to reset

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
    """Map 0–255 intensity to grayscale hex color"""
    gray = 255 - int(val)  # invert (0=white, 255=black)
    return f"#{gray:02x}{gray:02x}{gray:02x}"

def draw_grid():
    """Draw the work grid"""
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
    """Add intensity (0–255) to a cell, clipped"""
    if 0 <= row < WORK_GRID_SIZE and 0 <= col < WORK_GRID_SIZE:
        with grid_lock:
            work_grid[row][col] = min(255, max(0, work_grid[row][col] + intensity))
            canvas.itemconfig(rects[row][col], fill=intensity_to_color(work_grid[row][col]))

def brush_paint(event):
    """Continuous drawing with brush + antialiasing effect"""
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
    with grid_lock:
        for i in range(WORK_GRID_SIZE):
            for j in range(WORK_GRID_SIZE):
                work_grid[i][j] = 0
                canvas.itemconfig(rects[i][j], fill=intensity_to_color(0))

def downsample_grid_copy():
    """Return a downsampled 16x16 list copy; thread-safe."""
    with grid_lock:
        flat = [work_grid[i][j] for i in range(WORK_GRID_SIZE) for j in range(WORK_GRID_SIZE)]
    img = Image.new("L", (WORK_GRID_SIZE, WORK_GRID_SIZE))
    img.putdata(flat)
    img = img.resize((FINAL_GRID_SIZE, FINAL_GRID_SIZE), Image.ANTIALIAS)
    return list(img.getdata())

def send_frame_and_wait_ack(payload_bytes):
    """Send preamble + payload + checksum; wait for ACK (returns True if ACK)."""
    checksum = sum(payload_bytes) & 0xFF
    pkt = PREAMBLE + bytes(payload_bytes) + bytes([checksum])
    try:
        ser.reset_input_buffer()
        ser.write(pkt)
        ser.flush()
    except Exception as e:
        print("Serial write error:", e)
        return False

    # wait for ACK or NAK, small timeout loop
    deadline = time.time() + ACK_TIMEOUT
    while time.time() < deadline:
        resp = ser.read(1)
        if resp == ACK_BYTE:
            return True
        if resp == NAK_BYTE:
            return False
        time.sleep(0.01)
    # timeout
    return False

def sender_thread_fn():
    while True:
        payload = downsample_grid_copy()  # list of 256 integers 0..255
        ok = send_frame_and_wait_ack(payload)
        if ok:
            print("Frame acknowledged by FPGA")
        else:
            print("No ACK or NAK (timeout or NAK). Will retry next interval.")
        time.sleep(UPDATE_INTERVAL)  # wait before sending next frame

# start sender background thread
sender_thread = threading.Thread(target=sender_thread_fn, daemon=True)
sender_thread.start()

# Bindings and GUI buttons
canvas.bind("<B1-Motion>", brush_paint)
canvas.bind("<Button-1>", brush_paint)

btn_frame = tk.Frame(root)
btn_frame.pack(pady=10)
tk.Button(btn_frame, text="Clear", command=clear_grid).pack(side=tk.LEFT, padx=10)

# -------- Start --------
draw_grid()
root.mainloop()
