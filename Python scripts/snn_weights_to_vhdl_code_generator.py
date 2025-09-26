import numpy as np

def write_vhdl_package(hidden_layer_size, W_input_hidden, B_input_hidden, W_hidden_output, B_hidden_output, filename="weights_pkg.vhd"):
    """
    Generate a VHDL package file with weight/bias constants for snn_top.vhd.

    Definitions:
        W_input_hidden : Weight matrix from input to hidden layer
        B_input_hidden : Bias vector for hidden layer
        W_hidden_output: Weight matrix from hidden to output layer
        B_hidden_output: Bias vector for output layer

    Parameters:
        W_input_hidden : np.ndarray shape (N_HIDDEN, N_INPUTS)
        B_input_hidden : np.ndarray shape (N_HIDDEN,)
        W_hidden_output: np.ndarray shape (N_OUTPUT, N_HIDDEN)
        B_hidden_output: np.ndarray shape (N_OUTPUT,)
    """
    N_HIDDEN, N_INPUTS = W_input_hidden.shape
    N_OUTPUT, N_HIDDEN2 = W_hidden_output.shape
    assert N_HIDDEN == N_HIDDEN2, "Hidden layer size mismatch!"

    # Compute some suggested values based on quantized weights
    max_hidden_input = np.max(np.sum(np.abs(W_input_hidden_q), axis=1) + np.abs(B_input_hidden_q))
    max_output_input = np.max(np.sum(np.abs(W_hidden_output_q), axis=1) + np.abs(B_hidden_output_q))

    V_TH_hidden = int(max_hidden_input // 2)  # example: spike when half-max input reached
    V_TH_output = int(max_output_input // 2)
    LEAK = 0
    MEM_BITS = 16  # or calculate ceil(log2(max(max_hidden_input, max_output_input))) for dynamic sizing


    with open(filename, "w") as f:
        f.write("library IEEE;\n")
        f.write("use IEEE.STD_LOGIC_1164.ALL;\n")
        f.write("use IEEE.NUMERIC_STD.ALL;\n")
        f.write("use work.types_pkg.all;\n\n")
        f.write("package weights_pkg is\n\n")

        f.write(f"  -- Tunable neuron parameters\n")
        f.write(f"  constant N_HIDDEN   : integer := {hidden_layer_size};\n")
        f.write(f"  constant V_TH       : integer := {V_TH_hidden};\n")
        f.write(f"  constant LEAK       : integer := {LEAK};\n")
        f.write(f"  constant MEM_BITS   : integer := {MEM_BITS};\n\n")

        # W_INPUT_HIDDEN
        f.write(f"  constant W_INPUT_HIDDEN : integer_matrix(0 to {N_HIDDEN-1}, 0 to {N_INPUTS-1}) := (\n")
        for n in range(N_HIDDEN):
            row = ", ".join(str(int(x)) for x in W_input_hidden[n])
            if n < N_HIDDEN - 1:
                f.write(f"    {n} => ({row}),\n")
            else:
                f.write(f"    {n} => ({row})\n")
        f.write("  );\n\n")

        # B_INPUT_HIDDEN
        b_hidden_str = ", ".join(str(int(x)) for x in B_input_hidden)
        f.write(f"  constant B_INPUT_HIDDEN : integer_vector(0 to {N_HIDDEN-1}) := ({b_hidden_str});\n\n")

        # W_HIDDEN_OUTPUT
        f.write(f"  constant W_HIDDEN_OUTPUT : integer_matrix(0 to {N_OUTPUT-1}, 0 to {N_HIDDEN-1}) := (\n")
        for n in range(N_OUTPUT):
            row = ", ".join(str(int(x)) for x in W_hidden_output[n])
            if n < N_OUTPUT - 1:
                f.write(f"    {n} => ({row}),\n")
            else:
                f.write(f"    {n} => ({row})\n")
        f.write("  );\n\n")

        # B_HIDDEN_OUTPUT
        b_output_str = ", ".join(str(int(x)) for x in B_hidden_output)
        f.write(f"  constant B_HIDDEN_OUTPUT : integer_vector(0 to {N_OUTPUT-1}) := ({b_output_str});\n\n")

        f.write("end package weights_pkg;\n")

    print(f"[OK] Wrote VHDL weights package to {filename}")


# ---------------- Example Usage ----------------
if __name__ == "__main__":
    # N_INPUTS = 256  # input layer  : 256 pixel values for 16x16 image
    # N_HIDDEN = 32   # hidden layer : 32 neurons
    # N_OUTPUT = 10   # output layer : 10 classes for digits 0..9

    # # Example: random weights (replace with trained ones)
    # W_input_hidden  = np.random.randint(-2, 3, size=(N_HIDDEN, N_INPUTS))   # -2..2
    # B_input_hidden  = np.random.randint(-1, 2, size=(N_HIDDEN,))
    # W_hidden_output = np.random.randint(-2, 3, size=(N_OUTPUT, N_HIDDEN))
    # B_hidden_output = np.random.randint(-1, 2, size=(N_OUTPUT,))

    # Load trained model weights
    data = np.load("E:\Programmes\SNN-FPGA\model_weights.npz")

    hidden_layer_size = data["hidden_layer_size"]
    W_input_hidden    = data["W_input_hidden"]
    B_input_hidden    = data["B_input_hidden"]
    W_hidden_output   = data["W_hidden_output"]
    B_hidden_output   = data["B_hidden_output"]

    print("Loaded trained weights:")
    print(f"Hidden layer size: {hidden_layer_size}")
    print(f"W_input_hidden:  {W_input_hidden.shape}")
    print(f"B_input_hidden:  {B_input_hidden.shape}")
    print(f"W_hidden_output: {W_hidden_output.shape}")
    print(f"B_hidden_output: {B_hidden_output.shape}")

    # Optional: scale/quantize to integers (VHDL uses integer)
    SCALE = 128  # tune this factor
    W_input_hidden_q  = np.round(W_input_hidden * SCALE).astype(int)
    B_input_hidden_q  = np.round(B_input_hidden * SCALE).astype(int)
    W_hidden_output_q = np.round(W_hidden_output * SCALE).astype(int)
    B_hidden_output_q = np.round(B_hidden_output * SCALE).astype(int)

    # Write VHDL package
    write_vhdl_package(
        hidden_layer_size=hidden_layer_size, 
        W_input_hidden=W_input_hidden_q, 
        B_input_hidden=B_input_hidden_q, 
        W_hidden_output=W_hidden_output_q, 
        B_hidden_output=B_hidden_output_q
        )