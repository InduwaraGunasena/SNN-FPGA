import tkinter as tk
import serial
import time
import math
import threading
import numpy as np
from PIL import Image
from scipy.ndimage import center_of_mass, shift


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
root.title("FPGA Digit Classifier")

work_grid = [[0 for _ in range(WORK_GRID_SIZE)] for _ in range(WORK_GRID_SIZE)]
rects = [[None for _ in range(WORK_GRID_SIZE)] for _ in range(WORK_GRID_SIZE)]
grid_lock = threading.Lock()

# 1. Canvas (Top)
canvas_size = WORK_GRID_SIZE * CELL_SIZE + 2 * PADDING
canvas = tk.Canvas(root, width=canvas_size, height=canvas_size, bg="white")
canvas.pack()

# 2. Info Stack (Middle)
info_frame = tk.Frame(root, pady=5)
info_frame.pack()

lbl_chk = tk.Label(info_frame, text="Checksum: --", font=("Consolas", 12))
lbl_chk.pack()

lbl_pred = tk.Label(info_frame, text="Prediction: --", font=("Arial", 16, "bold"), fg="blue")
lbl_pred.pack()

lbl_time = tk.Label(info_frame, text="Latency: -- ms", font=("Consolas", 10), fg="gray")
lbl_time.pack()

# 3. Buttons (Bottom)
btn_frame = tk.Frame(root)
btn_frame.pack(pady=10)


# ------------------- Preprocessing ---------------------
def preprocess_input_image(img_arr, target_size=16, occupy_frac=0.80):
    """
    Convert a small image array (flattened, values 0..1, stroke=1.0 background=0.0)
    into a MNIST-like target_size x target_size image:

    Steps:
     1. reshape
     2. threshold to detect content and crop tight bounding box
     3. resize to occupy ~occupy_frac of target_size (preserve aspect ratio)
     4. paste into center of target frame
     5. center by center-of-mass (shift)
     6. clip and return flattened float array (0..1)
    """
    # 0. Safety
    arr = np.asarray(img_arr, dtype=np.float32)
    if arr.size == 0:
        return np.zeros(target_size * target_size, dtype=np.float32)

    original_size = int(np.sqrt(arr.size))
    img2 = arr.reshape((original_size, original_size))

    # If entirely empty -> return zeros
    if img2.max() <= 1e-6:
        return np.zeros(target_size * target_size, dtype=np.float32)

    # 1. Detect content: adaptive threshold (helps if stroke intensities vary)
    # Use simple threshold relative to max (keeps robust for different pen thickness)
    thresh = max(0.05, img2.max() * 0.15)
    rows = np.any(img2 > thresh, axis=1)
    cols = np.any(img2 > thresh, axis=0)
    if not rows.any() or not cols.any():
        return np.zeros(target_size * target_size, dtype=np.float32)

    ymin, ymax = np.where(rows)[0][[0, -1]]
    xmin, xmax = np.where(cols)[0][[0, -1]]

    cropped = img2[ymin:ymax+1, xmin:xmax+1]

    # 2. Resize keeping aspect ratio to occupy `occupy_frac` of target_size
    h, w = cropped.shape
    scale_target = max(1, int(target_size * occupy_frac))
    scale = scale_target / max(h, w)
    new_h = max(1, int(round(h * scale)))
    new_w = max(1, int(round(w * scale)))

    pil = Image.fromarray((cropped * 255).astype(np.uint8))
    pil_resized = pil.resize((new_w, new_h), Image.Resampling.LANCZOS)
    arr_resized = np.array(pil_resized, dtype=np.float32) / 255.0

    # 3. Paste into center of target image
    final = np.zeros((target_size, target_size), dtype=np.float32)
    start_y = (target_size - new_h) // 2
    start_x = (target_size - new_w) // 2
    final[start_y:start_y+new_h, start_x:start_x+new_w] = arr_resized

    # 4. Center by center-of-mass shift (MNIST-like centering)
    # If the image is nearly empty, skip shifting
    if final.sum() > 1e-6:
        com_y, com_x = center_of_mass(final)
        if not (np.isnan(com_y) or np.isnan(com_x)):
            desired_center = ((target_size - 1) / 2.0, (target_size - 1) / 2.0)
            shift_y = desired_center[0] - com_y
            shift_x = desired_center[1] - com_x
            final = shift(final, shift=(shift_y, shift_x), order=1, mode='constant', cval=0.0)

    # Clip & return flattened
    final = np.clip(final, 0.0, 1.0)
    return final.flatten().astype(np.float32)


def intensity_to_color(val):
    # val in 0..255 where 0 => white, 255 => black
    g = 255 - int(val)
    return f"#{g:02x}{g:02x}{g:02x}"

def draw_grid():
    for i in range(WORK_GRID_SIZE):
        for j in range(WORK_GRID_SIZE):
            x0 = PADDING + j * CELL_SIZE
            y0 = PADDING + i * CELL_SIZE
            rects[i][j] = canvas.create_rectangle(x0, y0, x0 + CELL_SIZE, y0 + CELL_SIZE,
                                                  fill=intensity_to_color(0), outline="gray")


def paint_cell(r, c, intensity=255):
    # intensity: 0..255; we always use strong strokes
    global needs_send
    if 0 <= r < WORK_GRID_SIZE and 0 <= c < WORK_GRID_SIZE:
        with grid_lock:
            new_val = min(255, max(0, work_grid[r][c] + intensity))
            if new_val != work_grid[r][c]:
                work_grid[r][c] = new_val
                canvas.itemconfig(rects[r][c], fill=intensity_to_color(work_grid[r][c]))
                needs_send = True

def brush_paint(event):
    c = (event.x - PADDING) // CELL_SIZE
    r = (event.y - PADDING) // CELL_SIZE
    radius = int(BRUSH_RADIUS)
    for di in range(-radius, radius + 1):
        for dj in range(-radius, radius + 1):
            if 0 <= r + di < WORK_GRID_SIZE and 0 <= c + dj < WORK_GRID_SIZE:    
                dist = math.sqrt(di*di + dj*dj)
                if dist <= BRUSH_RADIUS:
                    intens = int(255 * (1 - dist / (BRUSH_RADIUS+0.1)))
                    paint_cell(r+di, c+dj, intens) 

def clear_grid():
    global needs_send
    with grid_lock:
        for i in range(WORK_GRID_SIZE):
            for j in range(WORK_GRID_SIZE):
                work_grid[i][j] = 0
                canvas.itemconfig(rects[i][j], fill=intensity_to_color(0))
        needs_send = True

def downsample_grid_copy():
    """Return float array (0..1) of the downsampled FINAL_GRID_SIZE x FINAL_GRID_SIZE image."""
    with grid_lock:
        flat = [work_grid[i][j] for i in range(WORK_GRID_SIZE) for j in range(WORK_GRID_SIZE)]
    img = Image.new("L", (WORK_GRID_SIZE, WORK_GRID_SIZE))
    img.putdata(flat)
    img = img.resize((FINAL_GRID_SIZE, FINAL_GRID_SIZE), Image.Resampling.LANCZOS)
    arr = np.array(img.getdata(), dtype=np.float32) / 255.0

    return arr  # flattened 0..1

def sender_thread_fn():
    global needs_send
    while True:
        if needs_send:
            needs_send = False 
            
            # 1. Prepare data (Floats 0.0 to 1.0)
            raw_input = downsample_grid_copy()
            x_f = preprocess_input_image(raw_input, target_size=FINAL_GRID_SIZE)
            
            # 2. QUANTIZE (Fix: Convert Floats to Ints 0..255)
            # Scale by 256, round, and clip to 255 so it fits in a UART byte
            x_q = np.clip(np.rint(x_f * 256), 0, 255).astype(np.uint8)

            # Convert numpy array to standard Python bytes for serial transmission
            payload = x_q.tobytes()
            
            # 3. Send
            # -- PRINT CHECKSUM ---
            # This logic matches your VHDL sum_temp logic
            local_checksum = sum(x_q) & 0xFF  # Keep lowest 8 bits
            print(f"Python Checksum: {local_checksum: >3} (Binary: {local_checksum:08b})", end=' ')
            
            # Use root.after to safely update GUI from thread
            root.after(0, lambda: lbl_chk.config(text=f"Checksum: {local_checksum:08b} ({local_checksum})"))
            root.after(0, lambda: lbl_pred.config(text="Prediction: ...", fg="gray"))
            root.after(0, lambda: lbl_time.config(text="Latency: ..."))

            # 3. Send & Measure Time
            if ser:
                checksum = sum(payload) & 0xFF
                pkt = PREAMBLE + bytes(payload) + bytes([checksum])
                
                try:
                    ser.reset_input_buffer()

                    # START TIMER
                    start_time = time.time()

                    ser.write(pkt)
                    ser.flush()
                    
                    # 4. Wait for ACK
                    ack = ser.read(1)
                    
                    if ack == ACK_BYTE:
                        # 5. Wait for Prediction (It follows the ACK)
                        # Give it a small timeout in case SNN takes time
                        pred_byte = ser.read(1)

                        # STOP TIMER
                        end_time = time.time()
                        latency_ms = (end_time - start_time) * 1000
                        
                        if len(pred_byte) > 0:
                            pred_val = int(pred_byte[0])
                            # SUCCESS: Update Prediction Label
                            root.after(0, lambda: lbl_pred.config(text=f"Prediction: {pred_val}", fg="green"))
                            root.after(0, lambda: lbl_time.config(text=f"Latency: {latency_ms:.1f} ms"))
                            print(f"Success. Pred: {pred_val}")
                        else:
                            root.after(0, lambda: lbl_pred.config(text="Prediction: Timeout", fg="orange"))
                            
                    elif ack == NAK_BYTE:
                        root.after(0, lambda: lbl_pred.config(text="Error: Checksum NAK", fg="red"))
                    else:
                        root.after(0, lambda: lbl_pred.config(text="Error: No Response", fg="red"))

                except Exception as e:
                    print("Serial error:", e)
            
            time.sleep(MIN_SEND_INTERVAL)
            
        else:
            time.sleep(0.05)

# start sender background thread
sender_thread = threading.Thread(target=sender_thread_fn, daemon=True)
sender_thread.start()

# Bindings and GUI buttons
canvas.bind("<B1-Motion>", brush_paint)
canvas.bind("<Button-1>", brush_paint)
# Optional: Trigger a final send immediately on mouse release to catch the final pixel
canvas.bind("<ButtonRelease-1>", lambda e: None) 

tk.Button(btn_frame, text="Clear Grid", command=clear_grid, font=("Arial", 12)).pack(side=tk.LEFT, padx=10)

# -------- Start --------
draw_grid()
root.mainloop()