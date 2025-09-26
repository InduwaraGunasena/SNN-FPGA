import tkinter as tk
import serial
import time
import math
from PIL import Image

# ------------------- Configuration -------------------
SERIAL_PORT = "COM3"    # Replace with your Basys3 UART port
BAUD_RATE = 115200

WORK_GRID_SIZE = 32     # internal high-res grid
FINAL_GRID_SIZE = 16    # FPGA input grid
CELL_SIZE = 10          # size of each work-grid cell in GUI
PADDING = 20            # padding around grid in window

UPDATE_INTERVAL = 200   # ms - auto-send interval
BRUSH_RADIUS = 2.0      # brush size in work-grid units

# ------------------- Initialize UART -------------------
ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
time.sleep(2)  # Give time for Basys3 to reset

# ------------------- GUI -------------------
root = tk.Tk()
root.title("16x16 Digit Input Interface")

work_grid = [[0 for _ in range(WORK_GRID_SIZE)] for _ in range(WORK_GRID_SIZE)]
rects = [[None for _ in range(WORK_GRID_SIZE)] for _ in range(WORK_GRID_SIZE)]

canvas_size = WORK_GRID_SIZE * CELL_SIZE + 2 * PADDING
canvas = tk.Canvas(root, width=canvas_size, height=canvas_size, bg="white")
canvas.pack()


# -------- Utility functions ----------
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
    for i in range(WORK_GRID_SIZE):
        for j in range(WORK_GRID_SIZE):
            work_grid[i][j] = 0
            canvas.itemconfig(rects[i][j], fill=intensity_to_color(0))


def downsample_grid():
    """Downsample work_grid (WORK_GRID_SIZE×WORK_GRID_SIZE) to FINAL_GRID_SIZE×FINAL_GRID_SIZE"""
    img = Image.new("L", (WORK_GRID_SIZE, WORK_GRID_SIZE))
    # putdata expects a flat list
    img.putdata([work_grid[i][j] for i in range(WORK_GRID_SIZE) for j in range(WORK_GRID_SIZE)])
    img = img.resize((FINAL_GRID_SIZE, FINAL_GRID_SIZE), Image.ANTIALIAS)
    return list(img.getdata())


def send_to_fpga():
    final_flat = downsample_grid()  # length 256
    byte_data = bytes(final_flat)   # each pixel is 0–255
    
    ser.write(byte_data)
    print("Sent 16x16 downsampled grid to FPGA")
    
    root.after(UPDATE_INTERVAL, send_to_fpga)


# -------- Bindings ----------
canvas.bind("<B1-Motion>", brush_paint)
canvas.bind("<Button-1>", brush_paint)

btn_frame = tk.Frame(root)
btn_frame.pack(pady=10)
tk.Button(btn_frame, text="Clear", command=clear_grid).pack(side=tk.LEFT, padx=10)

# -------- Start --------
draw_grid()
root.after(UPDATE_INTERVAL, send_to_fpga)
root.mainloop()
