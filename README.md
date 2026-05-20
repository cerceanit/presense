# PreSense

Flutter meltdown-prediction app (Xiaomi Band 9 BLE + on-device ONNX ML).

Predictive early warning for neurodiverse users: personal calibration, rolling 40-point physiological window, on-device inference, alert and intervention flow.

## Reproduce (Android)

**Requirements:** Flutter SDK 3.11+, Android device with Bluetooth, Xiaomi Band 9 (optional — app simulates HR if band unavailable).

```bash
git clone https://github.com/cerceanit/presense.git
cd presense
flutter pub get
flutter run
```

Set your band MAC in `lib/services/band_service.dart` before pairing.

Logs should show `ML on-device: ONNX loaded` then inference lines after calibration fills the buffer.

The committed `assets/models/presense.onnx` is required — clones build without retraining.

### Rebuild model (optional, PC only)

Needs `presense_catboost.cbm` placed in the repo root (not committed — large training artifact).

```bash
pip install catboost onnx skl2onnx scikit-learn onnxruntime numpy
python scripts/export_mobile_onnx.py
```

Output: `assets/models/presense.onnx`

## Repo contents

This repository includes only what is needed to clone and run the app on Android: `lib/`, `android/`, `assets/models/`, `scripts/export_mobile_onnx.py`, and Flutter project metadata.

## AI usage disclosure

Development used **Vibe Coding** for approximately **20%** of the workflow. **Cursor** was used as an adviser for Git repository setup and pushing, architectural logistics, and main technical decision-making. Application logic, UX, calibration flow, BLE integration, and on-device ML pipeline were implemented and iterated in the project codebase.

## License

Hackathon / research prototype — not a medical device.
