# SIH26168 - AI-ML Based Intelligent Dead Reckoning
## Model Training Summary Report

**Date:** 2026-09-11 18:36:35
**Project:** SIH 2026 - PS ID: SIH26168

---

### Dataset
- **Source:** IOVNB (Intelligent Onboard Vehicle Navigation Benchmark)
- **Format:** Synchronized smartphone IMU (S) + vehicle CAN-bus (V) CSV pairs
- **Total sequences:** 72
- **Total samples:** 1,070,745
- **Total duration:** 1671.1 minutes
- **Smartphone sensors:** Accelerometer (m/s²), Gyroscope (rad/s), Magnetometer (μT), Gravity, GPS
- **Vehicle sensors:** GPS velocity, wheel speeds, yaw rate, steering, acceleration, braking
- **Sampling rate:** ~10 Hz (smartphone), 10 Hz (vehicle CAN-bus)

### Model 1: Velocity Estimation
- **Task:** Regression (predict vehicle forward velocity from smartphone IMU)
- **Architecture:** CNN-GRU (Conv1D(32) x2 → GRU(32) → Dense(32) → Dense(1))
- **Parameters:** 16,161
- **TFLite size:** 55.1 KB
- **Test MAE:** 3.8651 m/s
- **Test RMSE:** 5.0439 m/s
- **Test R²:** 0.6493
- **Inference time:** 0.01 ms

### Model 2: Vibration Classification
- **Task:** Classification (smooth / moderate / high vibration)
- **Architecture:** 1D-CNN (Conv1D(32) → Conv1D(64) → GAP → Dense(32) → Softmax)
- **Parameters:** 9,379
- **TFLite size:** 20.5 KB
- **Test Accuracy:** 0.97059883012848
- **Test F1:** 0.9706626464964854

### Model 3: Motion State Classification
- **Task:** Classification (motion states from IMU)
- **Architecture:** CNN-GRU (Conv1D(32) x2 → GRU(32) → Dense(32) → Softmax)
- **Parameters:** 11,558
- **TFLite size:** 52.9 KB
- **Test Accuracy:** 0.4942621404188895
- **Test F1:** 0.5065717851533046

### Deployment
- **Format:** TensorFlow Lite (float32 + FP16 quantized)
- **Total model size:** < 1 MB
- **Target:** Android/Flutter application
- **Inference:** Real-time capable (< 1ms per model on desktop, ~5-10ms on mobile)

### Limitations
1. Smartphone orientation is not controlled - models use magnitude-based features
   which are partially orientation-invariant, but performance may degrade with
   significantly different phone placements than training data
2. Vibration labels are proxy-derived from signal characteristics, not ground-truth
   vibration measurements
3. Dead reckoning accuracy degrades over time without GPS corrections (expected)
4. Models trained on UK driving data - may need fine-tuning for Indian road conditions

### Next Steps
1. Collect data on Indian roads for fine-tuning
2. Implement EKF/UKF fusion engine in C++
3. Add map matching and non-holonomic constraints
4. Integrate TFLite models into Android/Flutter app
5. Test with real-time GNSS outage scenarios
6. Add phone orientation estimation/calibration
