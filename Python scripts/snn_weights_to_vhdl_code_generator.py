# snn_weights_to_vhdl_code_generator.py
# Reads model_weights_conversion.npz (or falls back to model_weights.npz),
# quantizes weights to integers (auto scale unless overridden),
# and writes weights_pkg.vhd into the same folder.
import numpy as np
import math
import os
import sys

# ----------------- User-tweakable defaults -----------------
# Prefer the conversion file produced by the updated train_model.py
MODEL_FILENAME_PREFERRED = "model_weights_conversion.npz"
MODEL_FILENAME_FALLBACK  = "model_weights.npz"
OUT_FILENAME   = "weights_pkg.vhd"     # written to same dir as this script
MEM_BITS       = 16                    # bits used to store weights/biases (signed)
SAFETY_MARGIN  = 0.95                  # avoid saturating full range
# If you want to force a scale, set SCALE_OVERRIDE to a float, otherwise None
SCALE_OVERRIDE = None                  # e.g. 128.0 or None to auto-compute
# -----------------------------------------------------------

def script_dir():
    try:
        return os.path.dirname(os.path.realpath(__file__)) or "."
    except NameError:
        return "."

def compute_scale_auto(W_list, b_list, bits=16, safety_margin=0.95, signed=True):
    max_abs = 0.0
    for W in W_list:
        if W.size:
            max_abs = max(max_abs, float(np.max(np.abs(W))))
    for b in b_list:
        if b.size:
            max_abs = max(max_abs, float(np.max(np.abs(b))))
    if max_abs == 0.0:
        return 1.0
    max_int = (2**(bits-1) - 1) if signed else (2**bits - 1)
    scale = (max_int * safety_margin) / max_abs
    scale_rounded = float(int(max(1, round(scale))))
    return scale_rounded

def bits_needed_for_signed_int(x):
    if x <= 0:
        return 1
    return math.ceil(math.log2(x + 1)) + 1

def write_vhdl_package(
    outpath,
    W_in_q,
    B_in_q,
    W_out_q,
    B_out_q,
    scale,
    mem_bits=16
):
    N_HIDDEN, N_INPUTS = W_in_q.shape
    N_OUTPUT, N_HIDDEN2 = W_out_q.shape
    assert N_HIDDEN == N_HIDDEN2, "Hidden layer size mismatch"

    max_w = int(max(np.max(np.abs(W_in_q)), np.max(np.abs(W_out_q)), 1))
    weight_bits = bits_needed_for_signed_int(max_w)
    acc_bits = weight_bits + math.ceil(math.log2(max(N_INPUTS, N_HIDDEN))) + 2

    max_hidden_input = int(np.max(np.sum(np.abs(W_in_q), axis=1) + np.abs(B_in_q)))
    max_output_input = int(np.max(np.sum(np.abs(W_out_q), axis=1) + np.abs(B_out_q)))
    V_TH_hidden = int(max_hidden_input // 2) if max_hidden_input > 0 else 1
    V_TH_output = int(max_output_input // 2) if max_output_input > 0 else 1

    lines = []
    lines.append("-- Auto-generated weights package (from snn_weights_to_vhdl_code_generator.py)")
    lines.append("library IEEE;")
    lines.append("use IEEE.STD_LOGIC_1164.ALL;")
    lines.append("use IEEE.NUMERIC_STD.ALL;")
    lines.append("use work.types_pkg.all;")
    lines.append("")
    lines.append("package weights_pkg is")
    lines.append("")
    lines.append("  -- Network geometry (auto-generated)")
    lines.append(f"  constant N_INPUTS : integer := {N_INPUTS};")
    lines.append(f"  constant N_HIDDEN : integer := {N_HIDDEN};")
    lines.append(f"  constant N_OUTPUT : integer := {N_OUTPUT};")
    lines.append("")
    lines.append("  -- Quantization metadata")
    lines.append(f"  -- SCALE: multiply float weights by this value to obtain integer representation")
    lines.append(f"  constant SCALE : real := {float(scale):.6f};")
    lines.append(f"  constant MEM_BITS : integer := {mem_bits};")
    lines.append(f"  -- Recommended accumulator bitwidth (host-calculated)")
    lines.append(f"  constant ACC_BITS : integer := {acc_bits};")
    lines.append("")
    lines.append("  -- Recommended thresholds (integer scale)")
    lines.append(f"  constant V_TH_HIDDEN : integer := {V_TH_hidden};")
    lines.append(f"  constant V_TH_OUTPUT : integer := {V_TH_output};")
    lines.append("")

    # W_INPUT_HIDDEN
    lines.append(f"  constant W_INPUT_HIDDEN : integer_matrix(0 to {N_HIDDEN-1}, 0 to {N_INPUTS-1}) := (")
    for n in range(N_HIDDEN):
        row = ", ".join(str(int(x)) for x in W_in_q[n])
        comma = "," if n < N_HIDDEN - 1 else ""
        lines.append(f"    {n} => ({row}){comma}")
    lines.append("  );")
    lines.append("")

    # B_INPUT_HIDDEN
    b_hidden_str = ", ".join(str(int(x)) for x in B_in_q)
    lines.append(f"  constant B_INPUT_HIDDEN : integer_vector(0 to {N_HIDDEN-1}) := ({b_hidden_str});")
    lines.append("")

    # W_HIDDEN_OUTPUT
    lines.append(f"  constant W_HIDDEN_OUTPUT : integer_matrix(0 to {N_OUTPUT-1}, 0 to {N_HIDDEN-1}) := (")
    for n in range(N_OUTPUT):
        row = ", ".join(str(int(x)) for x in W_out_q[n])
        comma = "," if n < N_OUTPUT - 1 else ""
        lines.append(f"    {n} => ({row}){comma}")
    lines.append("  );")
    lines.append("")

    # B_HIDDEN_OUTPUT
    b_output_str = ", ".join(str(int(x)) for x in B_out_q)
    lines.append(f"  constant B_HIDDEN_OUTPUT : integer_vector(0 to {N_OUTPUT-1}) := ({b_output_str});")
    lines.append("")
    lines.append("end package weights_pkg;")
    lines.append("")

    with open(outpath, "w", newline="\n") as f:
        f.write("\n".join(lines))

    print(f"[OK] wrote VHDL package: {outpath}")
    print(f"[INFO] MEM_BITS={mem_bits}, SCALE={scale}, ACC_BITS={acc_bits}")
    print(f"[INFO] max_hidden_row_sum={max_hidden_input}, V_TH_HIDDEN={V_TH_hidden}")
    print(f"[INFO] max_output_row_sum={max_output_input}, V_TH_OUTPUT={V_TH_output}")


def main():
    base_dir = script_dir()
    # try the new conversion filename first, then fallback
    possible_models = [
        os.path.join(base_dir, MODEL_FILENAME_PREFERRED),
        os.path.join(base_dir, MODEL_FILENAME_FALLBACK)
    ]
    model_path = None
    for p in possible_models:
        if os.path.exists(p):
            model_path = p
            break

    if model_path is None:
        print("[ERROR] no model file found. Place 'model_weights_conversion.npz' or 'model_weights.npz' next to this script.")
        sys.exit(1)

    out_path   = os.path.join(base_dir, OUT_FILENAME)

    print(f"[INFO] loading model: {model_path}")
    data = np.load(model_path)

    # Load arrays - flexible with shapes
    try:
        hidden_layer_size = int(data["hidden_layer_size"])
    except Exception:
        hidden_layer_size = None

    W_input_hidden = data["W_input_hidden"]
    B_input_hidden = data["B_input_hidden"]
    W_hidden_output = data["W_hidden_output"]
    B_hidden_output = data["B_hidden_output"]

    # Ensure W_input_hidden is (N_HIDDEN, N_INPUTS)
    if hidden_layer_size is not None:
        if W_input_hidden.shape[0] != hidden_layer_size and W_input_hidden.shape[1] == hidden_layer_size:
            print("[INFO] transposing W_input_hidden to shape (N_HIDDEN, N_INPUTS)")
            W_input_hidden = W_input_hidden.T

    if W_input_hidden.ndim != 2:
        print("[ERROR] unexpected W_input_hidden shape:", W_input_hidden.shape)
        sys.exit(1)
    N_HIDDEN, N_INPUTS = W_input_hidden.shape

    # Ensure W_hidden_output is (N_OUTPUT, N_HIDDEN)
    if W_hidden_output.ndim == 2 and W_hidden_output.shape[1] != N_HIDDEN and W_hidden_output.shape[0] == N_HIDDEN:
        print("[INFO] transposing W_hidden_output to shape (N_OUTPUT, N_HIDDEN)")
        W_hidden_output = W_hidden_output.T

    if W_hidden_output.ndim != 2 or W_hidden_output.shape[1] != N_HIDDEN:
        print("[ERROR] unexpected W_hidden_output shape:", W_hidden_output.shape, "expected second dim", N_HIDDEN)
        sys.exit(1)

    N_OUTPUT = W_hidden_output.shape[0]
    print(f"[INFO] shapes: N_INPUTS={N_INPUTS}, N_HIDDEN={N_HIDDEN}, N_OUTPUT={N_OUTPUT}")

    # Choose scale
    if SCALE_OVERRIDE is not None:
        scale = float(SCALE_OVERRIDE)
        print(f"[INFO] Using SCALE override = {scale}")
    else:
        scale = compute_scale_auto(
            [W_input_hidden, W_hidden_output],
            [B_input_hidden, B_hidden_output],
            bits=MEM_BITS,
            safety_margin=SAFETY_MARGIN
        )
        print(f"[INFO] Auto-computed SCALE = {scale}")

    # Quantize
    W_in_q  = np.round(W_input_hidden * scale).astype(int)
    B_in_q  = np.round(B_input_hidden * scale).astype(int)
    W_out_q = np.round(W_hidden_output * scale).astype(int)
    B_out_q = np.round(B_hidden_output * scale).astype(int)

    # Simple safety checks for overflow
    max_val = max(
        int(np.max(np.abs(W_in_q))) if W_in_q.size else 0,
        int(np.max(np.abs(W_out_q))) if W_out_q.size else 0,
        int(np.max(np.abs(B_in_q))) if B_in_q.size else 0,
        int(np.max(np.abs(B_out_q))) if B_out_q.size else 0,
    )
    max_int_allowed = 2**(MEM_BITS-1) - 1
    if max_val > max_int_allowed:
        print(f"[WARN] quantized values exceed MEM_BITS capacity: max={max_val} > {max_int_allowed}")
        print("You may want to reduce SCALE or increase MEM_BITS.")
    else:
        print(f"[INFO] quantized max abs value = {max_val} fits in {MEM_BITS}-bit signed")

    # Write VHDL package
    write_vhdl_package(out_path, W_in_q, B_in_q, W_out_q, B_out_q, scale, mem_bits=MEM_BITS)


if __name__ == "__main__":
    main()
