from __future__ import annotations

from pathlib import Path

import numpy as np
from catboost import CatBoostClassifier
from skl2onnx import to_onnx
from sklearn.neural_network import MLPRegressor

ROOT = Path(__file__).resolve().parents[1]
CBM_PATH = ROOT / "presense_catboost.cbm"
OUT_PATH = ROOT / "assets" / "models" / "presense.onnx"
FEATURE_COUNT = 240


def _sample_windows(rng: np.random.Generator, n: int) -> np.ndarray:
    rows = []
    for _ in range(n):
        window = rng.uniform(
            low=[40, 20, 0, 0, -10, 10],
            high=[180, 100, 5, 100, 10, 32],
            size=(40, 6),
        ).astype(np.float32)
        rows.append(window.flatten())
    return np.vstack(rows)


def main() -> None:
    cb = CatBoostClassifier()
    cb.load_model(str(CBM_PATH))

    rng = np.random.default_rng(42)
    x_train = _sample_windows(rng, 800)
    y_train = cb.predict_proba(x_train)[:, 1].astype(np.float32)

    surrogate = MLPRegressor(
        hidden_layer_sizes=(256, 128, 64),
        activation="relu",
        max_iter=400,
        random_state=42,
    )
    surrogate.fit(x_train, y_train)

    y_hat = surrogate.predict(x_train[:500])
    mse = float(np.mean((y_hat - y_train[:500]) ** 2))
    print(f"Surrogate MSE vs CatBoost: {mse:.6f}")

    onnx_model = to_onnx(
        surrogate,
        x_train[:1].astype(np.float32),
        target_opset=12,
    )

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_bytes(onnx_model.SerializeToString())
    print(f"Mobile ONNX saved: {OUT_PATH} ({OUT_PATH.stat().st_size} bytes)")

    import onnxruntime as ort

    sess = ort.InferenceSession(str(OUT_PATH))
    inp = sess.get_inputs()[0].name
    out = sess.run(None, {inp: x_train[:1]})[0]
    print(f"Smoke test output shape: {out.shape}, value: {out}")


if __name__ == "__main__":
    main()
