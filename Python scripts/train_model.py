import numpy as np
from sklearn.datasets import fetch_openml
from sklearn.model_selection import train_test_split
from sklearn.neural_network import MLPClassifier
from sklearn.metrics import accuracy_score
from skimage.transform import resize
from sklearn.preprocessing import StandardScaler

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

    # Scale to [0,1]
    X /= X.max()

    return train_test_split(X, y, test_size=0.2, random_state=42)

def train_and_save(hidden_layer_size=32, max_iter=100):
    """Train the model and save weights and biases."""
    X_train, X_test, y_train, y_test = load_digits_16x16()

    print(f"Training samples: {X_train.shape[0]}, Test samples: {X_test.shape[0]}")

    # Standardize inputs (important for MLP convergence)
    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_test = scaler.transform(X_test)

    # MLP with more hidden units and iterations
    clf = MLPClassifier(
        hidden_layer_sizes=(hidden_layer_size,),
        activation="relu",
        solver="adam",
        max_iter=max_iter,
        verbose=True
    )

    print(f"Starting training with {hidden_layer_size} hidden neurons and {max_iter} max iterations.")
    clf.fit(X_train, y_train)

    # Evaluate
    y_pred = clf.predict(X_test)
    acc = accuracy_score(y_test, y_pred)
    print(f"Validation accuracy: {acc:.3f}")

    # Save weights
    np.savez("model_weights.npz",
             hidden_layer_size=hidden_layer_size,
             W_input_hidden=clf.coefs_[0].T,
             B_input_hidden=clf.intercepts_[0],
             W_hidden_output=clf.coefs_[1].T,
             B_hidden_output=clf.intercepts_[1])

    print("Model weights and biases saved to 'model_weights.npz'.")

if __name__ == "__main__":
    train_and_save(hidden_layer_size=32, max_iter=100)
