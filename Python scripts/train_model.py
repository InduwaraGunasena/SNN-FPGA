"""
train_model.py

Train a 16x16 MLP on MNIST downsampled to 16x16 and save conversion-friendly data:
 - MinMax scaler (0..1)
 - weights in shapes (N_HIDDEN, N_INPUTS) and (N_OUTPUT, N_HIDDEN)
 - pre-activation stats to help choose thresholds and quantization
"""

import numpy as np
from sklearn.datasets import fetch_openml
from sklearn.model_selection import train_test_split
from sklearn.neural_network import MLPClassifier
from sklearn.metrics import accuracy_score
from skimage.transform import resize
from sklearn.preprocessing import MinMaxScaler
import os

def load_digits_16x16():
    """Load MNIST and downsample to 16x16."""
    mnist = fetch_openml("mnist_784", version=1, as_frame=False)
    X, y = mnist["data"], mnist["target"].astype(int)

    # Remove rows with NaNs
    mask = ~np.isnan(X).any(axis=1)
    X, y = X[mask], y[mask]

    # Reshape and resize to 16x16
    X = X.reshape(-1, 28, 28)
    X_resized = np.array([resize(img, (16, 16), anti_aliasing=True) for img in X])
    X = X_resized.reshape(-1, 16*16).astype(np.float32)

    # Scale to [0,1] (we will also apply MinMaxScaler later)
    X /= X.max()

    return train_test_split(X, y, test_size=0.2, random_state=42)

def train_and_save(hidden_layer_size=32, max_iter=100):
    """Train the model and save weights, scaler, and conversion stats."""
    X_train, X_test, y_train, y_test = load_digits_16x16()

    print(f"Training samples: {X_train.shape[0]}, Test samples: {X_test.shape[0]}")

    # -------------------------
    # Use MinMax scaling to [0,1]
    # -------------------------
    scaler = MinMaxScaler(feature_range=(0.0, 1.0))
    X_train = scaler.fit_transform(X_train)
    X_test  = scaler.transform(X_test)

    # Train MLP
    clf = MLPClassifier(
        hidden_layer_sizes=(hidden_layer_size,),
        activation="relu",
        solver="adam",
        max_iter=max_iter,
        verbose=True,
        random_state=42
    )

    print(f"Starting training with {hidden_layer_size} hidden neurons and {max_iter} max iterations.")
    clf.fit(X_train, y_train)

    # Evaluate
    y_pred = clf.predict(X_test)
    acc = accuracy_score(y_test, y_pred)
    print(f"Validation accuracy: {acc:.4f}")

    # Extract weights. sklearn MLP stores coefs_ as [in->hidden, hidden->out] with shapes:
    # coefs_[0] shape = (n_input, n_hidden), coefs_[1] shape = (n_hidden, n_output)
    W0 = clf.coefs_[0]   # (n_input, n_hidden)
    b0 = clf.intercepts_[0]  # (n_hidden,)
    W1 = clf.coefs_[1]   # (n_hidden, n_output)
    b1 = clf.intercepts_[1]  # (n_output,)

    # Convert to shapes convenient for VHDL generator:
    # W_input_hidden: (N_HIDDEN, N_INPUTS)
    # W_hidden_output: (N_OUTPUT, N_HIDDEN)
    W_input_hidden = W0.T.copy()
    B_input_hidden = b0.copy()
    W_hidden_output = W1.T.copy()
    B_hidden_output = b1.copy()

    # -------------------------
    # Pre-activation statistics (useful for thresholding & scaling)
    # -------------------------
    # Hidden pre-activation (raw): X_test @ W0 + b0  (using X_test scaled to [0,1])
    preact_hidden = X_test.dot(W0) + b0  # shape (n_samples, n_hidden)
    hidden_max = float(np.max(preact_hidden))
    hidden_pct99 = float(np.percentile(preact_hidden, 99.9))

    # Hidden activations after ReLU
    hidden_relu = np.maximum(preact_hidden, 0.0)
    preact_output = hidden_relu.dot(W1) + b1
    output_max = float(np.max(preact_output))
    output_pct99 = float(np.percentile(preact_output, 99.9))

    print("Pre-activation stats:")
    print(f"  hidden_max = {hidden_max:.6f}, hidden_99.9pct = {hidden_pct99:.6f}")
    print(f"  output_max = {output_max:.6f}, output_99.9pct = {output_pct99:.6f}")

    # -------------------------
    # Save weights + metadata for conversion
    # -------------------------
    out_dir = os.path.dirname(os.path.realpath(__file__)) or "."
    npz_path = os.path.join(out_dir, "model_weights_conversion.npz")
    joblib_path = os.path.join(out_dir, "minmax_scaler.joblib")

    np.savez(npz_path,
             hidden_layer_size=hidden_layer_size,
             W_input_hidden=W_input_hidden.astype(np.float32),
             B_input_hidden=B_input_hidden.astype(np.float32),
             W_hidden_output=W_hidden_output.astype(np.float32),
             B_hidden_output=B_hidden_output.astype(np.float32),
             scaler_min=scaler.data_min_.astype(np.float32),
             scaler_max=scaler.data_max_.astype(np.float32),
             hidden_max=np.float32(hidden_max),
             hidden_pct99=np.float32(hidden_pct99),
             output_max=np.float32(output_max),
             output_pct99=np.float32(output_pct99)
             )

    print(f"Model & conversion metadata saved to '{npz_path}' and scaler saved to '{joblib_path}'.")

if __name__ == "__main__":
    # tweak these if you want
    train_and_save(hidden_layer_size=32, max_iter=300)
