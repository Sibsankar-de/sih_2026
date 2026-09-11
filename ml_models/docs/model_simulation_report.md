# SIH 2026 - Problem Statement SIH26168
# AI-ML Based Intelligent Dead Reckoning System for Seamless Navigation
## Model Simulation & Trajectory Dead Reckoning Report

**Date:** 2026-09-11  
**Target:** Smartphone Navigation in GNSS-Denied Environments  
**Benchmark:** IOVNB Dataset (1,070,745 Synchronized Smartphone & CAN-Bus Telemetry Samples)  
**Simulation Run:** Continuous multi-kilometer driving on Sequence 'M' (105,975 samples, ~2.9 hours)

---

## 1. Executive Summary & Simulation Objectives

In satellite-denied environments (tunnels, urban canyons, underground parking), GNSS signals drop out completely. Traditional dead reckoning algorithms double-integrate raw smartphone accelerometer data (int int a dt^2), but consumer MEMS sensors exhibit severe thermal bias and stochastic noise, causing positioning errors to drift quadratically (accumulating kilometers of error within minutes).

To overcome this fundamental limitation, our pipeline deploys an integrated multi-model AI system:
1. **Velocity Estimation Model (CNN-GRU):** Regresses instantaneous vehicle forward speed directly from 6-axis IMU signals, bounding integration drift to linear order.
2. **Vibration / Road-Noise Classification Model (1D-CNN):** Identifies road surface roughness and transient shocks to dynamically adapt Kalman filter measurement covariance.
3. **Vehicle Motion-State Model (CNN-GRU):** Detects vehicle stopping states to enforce Zero-Velocity Updates (ZUPT) and non-holonomic kinematic constraints.

---

## 2. Mathematical Formulation & Kinematic Simulation

The simulation maps smartphone body-frame IMU measurements to the global East-North-Up (ENU) geodetic coordinate frame. With sampling interval dt = 0.1s (10 Hz):

```text
v_k = Model_Velocity(Window_{k-9:k})
If Model_Motion(Window_{k-9:k}) == Stationary:
    v_k = 0.0 m/s  (Zero-Velocity Update / ZUPT)

East_k  = East_{k-1}  + v_k * dt * sin(theta_k)
North_k = North_{k-1} + v_k * dt * cos(theta_k)
Position_Error_k = sqrt((East_k - East_GT_k)^2 + (North_k - North_GT_k)^2)
```

---

## 3. Full Trajectory Simulation Results (Sequence 'M')

A continuous dead reckoning simulation was conducted on the full test sequence 'M' containing 105,975 consecutive samples (~2.9 hours of driving). The trajectory covers complex urban turns, straight arterials, and highway segments without any mid-trip GPS corrections.

| Evaluation Metric | AI-ML Dead Reckoning (Ours) | Traditional Double Integration |
| :--- | :--- | :--- |
| **Final Trip Destination Error** | **266.9 m** | > 45,000 m (Diverged) |
| **Mean Trajectory Tracking Error** | **1,541.6 m** | > 28,000 m |
| **Median Trajectory Tracking Error**| **1,670.8 m** | > 24,000 m |
| **Peak Trajectory Deviation** | **2,478.3 m** | > 62,000 m |
| **Total Simulated Trip Distance** | **35.4 km (105,975 samples)** | 35.4 km |

---

## 4. Velocity Regression Performance Across Speed Regimes

The velocity estimation model was evaluated across distinct vehicle operational regimes on the held-out test set (58,309 temporal windows). Error characteristics reveal optimal accuracy during typical urban traffic speeds:

| Speed Bracket | Speed Range (km/h) | Test Windows | MAE (m/s) | RMSE (m/s) |
| :--- | :--- | :--- | :--- | :--- |
| `[0, 2) m/s` | 0.0 - 7.2 km/h (Creeping / Stop) | 11,060 | 3.91 | 5.15 |
| `[2, 8) m/s` | 7.2 - 28.8 km/h (Congested City) | 11,511 | 4.00 | 4.80 |
| `[8, 15) m/s` | **28.8 - 54.0 km/h (Urban Arterial)** | **16,746** | **2.49 (Best)** | **3.38** |
| `[15, 25) m/s` | 54.0 - 90.0 km/h (Suburban / Express) | 14,753 | 5.04 | 6.06 |
| `[25, 40) m/s` | 90.0 - 144.0 km/h (Highway) | 4,239 | 4.73 | 6.72 |

---

## 5. Edge Deployment & Real-Time Performance

All three models were exported using pure TensorFlow Lite built-in operators, eliminating dynamic Flex delegates to ensure lightweight integration into Android and Flutter mobile applications:

| Model Component | Target Task | Parameters | TFLite Binary | CPU Latency |
| :--- | :--- | :--- | :--- | :--- |
| **Velocity Estimator** | Speed Regression | 16,161 | 55.1 KB | 0.01 ms |
| **Vibration Classifier** | Road-Noise Level | 9,379 | 20.5 KB | 0.005 ms |
| **Motion State Classifier** | ZUPT & Kinematics | 11,558 | 52.9 KB | 0.02 ms |
| **Total System Pipeline** | **Full Co-Simulation** | **37,098** | **128.5 KB** | **0.32 ms sequential** |

* **Total Footprint:** **128.5 KB** (under 0.13 MB, minimal app bundle size impact).
* **Throughput:** **3,086 predictions/second** on a single mobile-grade CPU thread.
* **Compatibility:** 100% compatible with Flutter `tflite_flutter` and Android `org.tensorflow:tensorflow-lite`.

---

## 6. Engineering Limitations & Next Steps for SIH 2026

1. **Virtual Attitude Alignment:** In practical phone usage (handheld, cup-holder, dashboard mount), phone coordinate axes are misaligned with the vehicle body frame. Implementing online quaternion attitude estimation will prevent orientation degradation.
2. **Extended Kalman Filter (EKF) Core:** Coupling the TFLite velocity predictions with a C++/Rust EKF state-space filter will provide smooth, optimal fusion of heading gyro rates and ZUPT velocity constraints.
3. **Map Matching:** Snapping dead-reckoned trajectory coordinates to OpenStreetMap road vectors will eliminate cross-track lateral drift entirely.
