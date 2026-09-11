# 2D GNSS + IMU + ML Fusion Engine

2D GNSS + IMU + ML Fusion Engine is an 8-state Extended Kalman Filter for intelligent dead reckoning in GNSS-denied environments.

## System Architecture

```text
Smartphone IMU -> Preprocessing -> Alignment -> ML -> EKF -> Navigation State
                                    |                ^
                                    v                |
                                  GNSS --------------|
```

## EKF State Vector

The EKF estimates an 8-state vector:
- `px`: Position East (m)
- `py`: Position North (m)
- `vx`: Velocity East (m/s)
- `vy`: Velocity North (m/s)
- `yaw`: Heading (rad), angle counter-clockwise from East
- `bax`: Accelerometer bias in x (m/s²)
- `bay`: Accelerometer bias in y (m/s²)
- `bg`: Gyroscope bias in z (rad/s)

## Coordinate System

The system uses a Local Tangent Plane approximation with an ENU (East-North-Up) coordinate system. Only 2D operations are performed, assuming zero altitude, pitch, and roll, which simplifies computation for standard automotive surface navigation.

## Mathematical Foundation

### 1. Motion Model (Prediction)

Bias correction:
$$ a_x = a_x^{raw} - b_{ax} $$
$$ a_y = a_y^{raw} - b_{ay} $$
$$ \omega = \omega_z^{raw} - b_g $$

ENU transformation:
$$ a_E = a_x \cos(\psi) - a_y \sin(\psi) $$
$$ a_N = a_x \sin(\psi) + a_y \cos(\psi) $$

State propagation equations:
$$ p_x^{k} = p_x^{k-1} + v_x^{k-1} \Delta t + \frac{1}{2} a_E \Delta t^2 $$
$$ p_y^{k} = p_y^{k-1} + v_y^{k-1} \Delta t + \frac{1}{2} a_N \Delta t^2 $$
$$ v_x^{k} = v_x^{k-1} + a_E \Delta t $$
$$ v_y^{k} = v_y^{k-1} + a_N \Delta t $$
$$ \psi^{k} = \psi^{k-1} + \omega \Delta t $$
Biases remain constant:
$$ b_{ax}^{k} = b_{ax}^{k-1} $$
$$ b_{ay}^{k} = b_{ay}^{k-1} $$
$$ b_g^{k} = b_g^{k-1} $$

### 2. State Transition Jacobian F

The Jacobian matrix $F = \frac{\partial f}{\partial x}$ is an 8x8 matrix:
$$
\begin{bmatrix}
1 & 0 & \Delta t & 0 & \frac{\partial p_x}{\partial \psi} & \frac{\partial p_x}{\partial b_{ax}} & \frac{\partial p_x}{\partial b_{ay}} & \frac{\partial p_x}{\partial b_g} \\
0 & 1 & 0 & \Delta t & \frac{\partial p_y}{\partial \psi} & \frac{\partial p_y}{\partial b_{ax}} & \frac{\partial p_y}{\partial b_{ay}} & \frac{\partial p_y}{\partial b_g} \\
0 & 0 & 1 & 0 & \frac{\partial v_x}{\partial \psi} & \frac{\partial v_x}{\partial b_{ax}} & \frac{\partial v_x}{\partial b_{ay}} & \frac{\partial v_x}{\partial b_g} \\
0 & 0 & 0 & 1 & \frac{\partial v_y}{\partial \psi} & \frac{\partial v_y}{\partial b_{ax}} & \frac{\partial v_y}{\partial b_{ay}} & \frac{\partial v_y}{\partial b_g} \\
0 & 0 & 0 & 0 & 1 & 0 & 0 & -\Delta t \\
0 & 0 & 0 & 0 & 0 & 1 & 0 & 0 \\
0 & 0 & 0 & 0 & 0 & 0 & 1 & 0 \\
0 & 0 & 0 & 0 & 0 & 0 & 0 & 1 
\end{bmatrix}
$$

### 3. Process Noise

The process noise covariance $Q_k$ is computed by continuous-time noise density integration: $Q_k = G Q_c G^T \Delta t$. Noise sources include acceleration random walk, rate random walk, and bias instability.

### 4. GNSS Position Update

Measurement matrix $H$:
$$
H = \begin{bmatrix}
1 & 0 & 0 & 0 & 0 & 0 & 0 & 0 \\
0 & 1 & 0 & 0 & 0 & 0 & 0 & 0 
\end{bmatrix}
$$
$R$ is a 2x2 diagonal matrix scaled by positional accuracy.

### 5. GNSS Velocity Update

Measurement matrix $H$:
$$
H = \begin{bmatrix}
0 & 0 & 1 & 0 & 0 & 0 & 0 & 0 \\
0 & 0 & 0 & 1 & 0 & 0 & 0 & 0 
\end{bmatrix}
$$
$R$ is scaled by velocity accuracy.

### 6. ML Forward Velocity Update

$$ h(x) = v_x \cos(\psi) + v_y \sin(\psi) $$
Jacobian $H$:
$$
H = \begin{bmatrix}
0 & 0 & \cos(\psi) & \sin(\psi) & (-v_x \sin(\psi) + v_y \cos(\psi)) & 0 & 0 & 0
\end{bmatrix}
$$
ML confidence inversely scales the variance in $R$.

### 7. Non-Holonomic Constraint (NHC)

Assuming no lateral slip, lateral velocity is zero:
$$ h(x) = -v_x \sin(\psi) + v_y \cos(\psi) = 0 $$
Jacobian $H$:
$$
H = \begin{bmatrix}
0 & 0 & -\sin(\psi) & \cos(\psi) & (-v_x \cos(\psi) - v_y \sin(\psi)) & 0 & 0 & 0
\end{bmatrix}
$$

### 8. ZUPT (Zero Velocity Update)

When stationary, velocity is zero.
$$
H = \begin{bmatrix}
0 & 0 & 1 & 0 & 0 & 0 & 0 & 0 \\
0 & 0 & 0 & 1 & 0 & 0 & 0 & 0 
\end{bmatrix}
$$

### 9. Joseph Covariance Update

The Joseph form guarantees positive semi-definiteness:
$$ P = (I - KH) P (I - KH)^T + K R K^T $$

### 10. Innovation Gating

Mahalanobis distance squared:
$$ d^2 = r^T S^{-1} r $$
where $r$ is the innovation and $S = H P H^T + R$.

## Configurable Parameters

| Parameter | Description | Units | Default |
|-----------|-------------|-------|---------|
| `process_noise_acc` | Accelerometer noise density | (m/s²)/√Hz | 0.01 |
| `process_noise_gyro` | Gyroscope noise density | (rad/s)/√Hz | 0.001 |
| `process_noise_acc_bias`| Accelerometer bias instability | (m/s³)/√Hz | 0.0001 |
| `process_noise_gyro_bias`| Gyroscope bias instability | (rad/s²)/√Hz | 0.00001 |
| `gate_threshold_gnss` | Chi-square gate for GNSS | std deviations | 3.0 |

## GNSS Quality Management

State Machine:
`AVAILABLE` -> `DEGRADED` (poor DOP) -> `LOST` (outage) -> `REACQUIRING` -> `AVAILABLE`

## Adaptive Noise

High vibration scores dynamically scale up the `process_noise_acc` and `process_noise_gyro` to prevent over-confidence in noisy IMU integrations.

## Project Structure

```
fusion-engine/
├── CMakeLists.txt        # Build definitions
├── README.md             # Project documentation
├── include/              # Public headers
├── src/                  # Source files
├── tests/                # Unit tests
└── examples/             # Example usage
```

## Building

```bash
mkdir build && cd build
cmake ..
make -j$(nproc)
```

## Running Tests

```bash
cd build
ctest --output-on-failure
```

## Running Example

```bash
./fusion_example
```

## Dependencies

- C++17 compiler
- Eigen3
- CMake 3.14+
- GoogleTest (fetched automatically)

## What's Mocked / Not Yet Connected

- ML provider uses MockMLProvider (real ONNX inference not connected)
- Map matching is interface-only (no real road network)
- Phone-to-vehicle alignment is assumed done upstream
- IO-VNBD dataset adapter not yet implemented
- Android JNI not implemented

## Future Work

- ONNX Runtime ML inference
- HMM/Viterbi map matching
- IO-VNBD dataset adapter
- Android JNI integration
- 3D extension (altitude, roll, pitch)

## Performance Targets

- <10% positional drift during GNSS outage
- Real-time capable at 200Hz IMU rate
