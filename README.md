# PreSense

Flutter meltdown-prediction app (Xiaomi Band 9 BLE + on-device ONNX ML).

## On-device ML

Inference runs on the phone via ONNX Runtime. No server required.

### Rebuild model (run once on a PC with the CatBoost source model)

```bash
pip install catboost onnx skl2onnx scikit-learn onnxruntime numpy
python scripts/export_mobile_onnx.py
```

Output: `assets/models/presense.onnx` (commit this file so clones build without retraining).

### Run the app

```bash
flutter pub get
flutter run
```

Logs should show `ML on-device: ONNX loaded`.

## Setup

- Flutter SDK 3.11+
- Android: Bluetooth and location permissions (for BLE scan)
- Set your band MAC in `lib/services/band_service.dart` before pairing

## License

Hackathon / research prototype — not a medical device.
