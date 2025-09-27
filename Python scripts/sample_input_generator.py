import numpy as np
from PIL import Image

# Load MNIST image (28x28)

# Change this to generate more samples
no_of_sample_digits = 3

# Select random digits
digits = np.random.choice(range(10), size=no_of_sample_digits, replace=False)

# Get corresponding images path from MNIST dataset directory
img_paths = [f"Python scripts/sample MNIST data/{d}.png" for d in digits]

for i, img_path in enumerate(img_paths):
    print(f"True Label: {digits[i]}")
    print(f"Image Path: {img_path}")

    img28 = Image.open(img_path).convert("L")  # grayscale
    img28 = np.array(img28)

    # Downsample to 16x16
    img16 = np.array(Image.fromarray(img28).resize((16,16), Image.BILINEAR))

    # Flatten to 1D array
    flat = img16.flatten()

    # Convert to VHDL std_logic_vector hex format
    vhdl_str = ""
    for i, pix in enumerate(flat):
        vhdl_str += f"{i} => x\"{pix:02X}\""
        if i != len(flat)-1:
            vhdl_str += ", "

    print(vhdl_str)
    print()
