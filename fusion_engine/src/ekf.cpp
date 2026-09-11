#include "fusion/ekf.h"
#include <cmath>
#include <algorithm>

namespace fusion {

EKF::EKF() {
    x_.setZero();
    P_.setIdentity();
    initialized_ = false;
}

void EKF::initialize(const StateVector& initial_state, const FusionConfig& config) {
    x_ = initial_state;
    x_(YAW) = wrapAngle(x_(YAW));
    
    config_ = config;
    
    // Initialize covariance from config sigma values (variance = sigma^2)
    P_.setZero();
    P_(PX, PX) = config_.init_position_sigma * config_.init_position_sigma;
    P_(PY, PY) = config_.init_position_sigma * config_.init_position_sigma;
    P_(VX, VX) = config_.init_velocity_sigma * config_.init_velocity_sigma;
    P_(VY, VY) = config_.init_velocity_sigma * config_.init_velocity_sigma;
    P_(YAW, YAW) = config_.init_yaw_sigma * config_.init_yaw_sigma;
    P_(BAX, BAX) = config_.init_accel_bias_sigma * config_.init_accel_bias_sigma;
    P_(BAY, BAY) = config_.init_accel_bias_sigma * config_.init_accel_bias_sigma;
    P_(BG, BG) = config_.init_gyro_bias_sigma * config_.init_gyro_bias_sigma;
    
    last_timestamp_ = 0.0;
    initialized_ = true;
}

bool EKF::predict(const IMUSample& imu, double noise_scale) {
    if (!initialized_) return false;
    
    // First IMU sample: just store timestamp, no prediction
    if (last_timestamp_ == 0.0) {
        last_timestamp_ = imu.timestamp;
        return true;
    }
    
    double dt = imu.timestamp - last_timestamp_;
    
    // Reject invalid dt
    if (dt <= 0.0 || dt > config_.max_imu_dt) {
        last_timestamp_ = imu.timestamp;
        return false;
    }
    
    // Validate IMU inputs
    if (!std::isfinite(imu.accel.x()) || !std::isfinite(imu.accel.y()) || !std::isfinite(imu.gyro_z)) {
        return false;
    }
    
    // ============================================================
    // 1. Bias-corrected measurements
    //    a_x = ax - bax,  a_y = ay - bay
    //    omega = gyro_z - bg
    // ============================================================
    double a_x = imu.accel.x() - x_(BAX);
    double a_y = imu.accel.y() - x_(BAY);
    double omega = imu.gyro_z - x_(BG);
    
    // ============================================================
    // 2. Transform acceleration from vehicle frame to ENU frame
    //    aE = cos(yaw)*a_x - sin(yaw)*a_y
    //    aN = sin(yaw)*a_x + cos(yaw)*a_y
    // ============================================================
    double cy = std::cos(x_(YAW));
    double sy = std::sin(x_(YAW));
    
    double aE = cy * a_x - sy * a_y;
    double aN = sy * a_x + cy * a_y;
    
    // ============================================================
    // 3. State propagation (first-order kinematic model)
    //    px(k+1) = px + vx*dt + 0.5*aE*dt^2
    //    py(k+1) = py + vy*dt + 0.5*aN*dt^2
    //    vx(k+1) = vx + aE*dt
    //    vy(k+1) = vy + aN*dt
    //    yaw(k+1) = yaw + omega*dt
    //    biases unchanged (random walk)
    // ============================================================
    x_(PX) += x_(VX) * dt + 0.5 * aE * dt * dt;
    x_(PY) += x_(VY) * dt + 0.5 * aN * dt * dt;
    x_(VX) += aE * dt;
    x_(VY) += aN * dt;
    x_(YAW) += omega * dt;
    x_(YAW) = wrapAngle(x_(YAW));
    // BAX, BAY, BG: unchanged in prediction (random walk model)
    
    // ============================================================
    // 4. Compute State Transition Jacobian F = ∂f/∂x
    // ============================================================
    StateMatrix F = computeF(dt, imu);
    
    // ============================================================
    // 5. Compute Process Noise Matrix Q
    // ============================================================
    StateMatrix Q = computeProcessNoise(dt, imu, noise_scale);
    
    // ============================================================
    // 6. Propagate covariance: P = F*P*F^T + Q
    // ============================================================
    P_ = F * P_ * F.transpose() + Q;
    
    // Symmetrize
    P_ = 0.5 * (P_ + P_.transpose());
    
    validateCovariance();
    
    last_timestamp_ = imu.timestamp;
    return true;
}

// ============================================================================
// State Transition Jacobian F = I + (∂f_continuous/∂x)*dt
//
// Key non-trivial derivatives:
//   aE = cos(yaw)*(ax-bax) - sin(yaw)*(ay-bay)
//   aN = sin(yaw)*(ax-bax) + cos(yaw)*(ay-bay)
//
//   ∂aE/∂yaw = -sin(yaw)*a_x - cos(yaw)*a_y
//   ∂aN/∂yaw =  cos(yaw)*a_x - sin(yaw)*a_y
//
//   ∂aE/∂bax = -cos(yaw)
//   ∂aE/∂bay =  sin(yaw)
//   ∂aN/∂bax = -sin(yaw)
//   ∂aN/∂bay = -cos(yaw)
//
//   ∂yaw_next/∂bg = -dt
// ============================================================================
StateMatrix EKF::computeF(double dt, const IMUSample& imu) const {
    StateMatrix F = StateMatrix::Identity();
    
    double a_x = imu.accel.x() - x_(BAX);
    double a_y = imu.accel.y() - x_(BAY);
    double yaw = x_(YAW);
    double cy = std::cos(yaw);
    double sy = std::sin(yaw);
    
    // Position depends on velocity
    F(PX, VX) = dt;
    F(PY, VY) = dt;
    
    // Position and velocity depend on yaw (through rotation of acceleration)
    // ∂px/∂yaw = ∂aE/∂yaw * 0.5*dt^2
    // ∂py/∂yaw = ∂aN/∂yaw * 0.5*dt^2
    double daE_dyaw = -sy * a_x - cy * a_y;
    double daN_dyaw =  cy * a_x - sy * a_y;
    
    F(PX, YAW) = daE_dyaw * 0.5 * dt * dt;
    F(PY, YAW) = daN_dyaw * 0.5 * dt * dt;
    F(VX, YAW) = daE_dyaw * dt;
    F(VY, YAW) = daN_dyaw * dt;
    
    // Position and velocity depend on accelerometer biases
    // ∂aE/∂bax = -cos(yaw),  ∂aE/∂bay = sin(yaw)
    // ∂aN/∂bax = -sin(yaw),  ∂aN/∂bay = -cos(yaw)
    F(PX, BAX) = -cy * 0.5 * dt * dt;
    F(PX, BAY) =  sy * 0.5 * dt * dt;
    F(PY, BAX) = -sy * 0.5 * dt * dt;
    F(PY, BAY) = -cy * 0.5 * dt * dt;
    
    F(VX, BAX) = -cy * dt;
    F(VX, BAY) =  sy * dt;
    F(VY, BAX) = -sy * dt;
    F(VY, BAY) = -cy * dt;
    
    // Yaw depends on gyro bias
    // ∂yaw_next/∂bg = -dt
    F(YAW, BG) = -dt;
    
    return F;
}

// ============================================================================
// Process Noise Q using G*Qc*G^T*dt discretization
//
// Noise input vector u_noise = [na_x, na_y, ng, nba_x, nba_y, nbg]  (6 sources)
//
// G matrix (8x6) maps noise through the dynamics:
//   G(PX,0) = 0.5*dt*cos(yaw)    G(PX,1) = -0.5*dt*sin(yaw)
//   G(PY,0) = 0.5*dt*sin(yaw)    G(PY,1) =  0.5*dt*cos(yaw)
//   G(VX,0) = cos(yaw)           G(VX,1) = -sin(yaw)
//   G(VY,0) = sin(yaw)           G(VY,1) =  cos(yaw)
//   G(YAW,2) = 1.0
//   G(BAX,3) = 1.0
//   G(BAY,4) = 1.0
//   G(BG,5)  = 1.0
//
// Qc = diag(σ²_ax, σ²_ay, σ²_g, σ²_bax, σ²_bay, σ²_bg)
//
// Q_discrete = G * Qc * G^T * dt  (first-order approximation)
// ============================================================================
StateMatrix EKF::computeProcessNoise(double dt, const IMUSample& /*imu*/, double noise_scale) const {
    double scale = std::clamp(noise_scale, config_.min_noise_scale, config_.max_noise_scale);
    
    // Continuous-time noise PSD values (scaled)
    double n_ax = config_.process_noise.accel_noise * scale;
    double n_ay = config_.process_noise.accel_noise * scale;
    double n_gz = config_.process_noise.gyro_noise * scale;
    double n_bax = config_.process_noise.accel_bias_random_walk * scale;
    double n_bay = config_.process_noise.accel_bias_random_walk * scale;
    double n_bgz = config_.process_noise.gyro_bias_random_walk * scale;
    
    // Qc = diag of PSD squared values
    Eigen::Matrix<double, 6, 6> Qc = Eigen::Matrix<double, 6, 6>::Zero();
    Qc(0, 0) = n_ax * n_ax;
    Qc(1, 1) = n_ay * n_ay;
    Qc(2, 2) = n_gz * n_gz;
    Qc(3, 3) = n_bax * n_bax;
    Qc(4, 4) = n_bay * n_bay;
    Qc(5, 5) = n_bgz * n_bgz;
    
    // G matrix: maps noise sources to state derivatives
    Eigen::Matrix<double, 8, 6> G = Eigen::Matrix<double, 8, 6>::Zero();
    
    double yaw = x_(YAW);
    double cy = std::cos(yaw);
    double sy = std::sin(yaw);
    
    // Accel noise -> position (0.5*dt integration)
    G(PX, 0) =  0.5 * dt * cy;
    G(PX, 1) = -0.5 * dt * sy;
    G(PY, 0) =  0.5 * dt * sy;
    G(PY, 1) =  0.5 * dt * cy;
    
    // Accel noise -> velocity
    G(VX, 0) =  cy;
    G(VX, 1) = -sy;
    G(VY, 0) =  sy;
    G(VY, 1) =  cy;
    
    // Gyro noise -> yaw
    G(YAW, 2) = 1.0;
    
    // Bias random walk -> bias states
    G(BAX, 3) = 1.0;
    G(BAY, 4) = 1.0;
    G(BG,  5) = 1.0;
    
    // First-order discrete approximation: Q = G * Qc * G^T * dt
    StateMatrix Q = G * Qc * G.transpose() * dt;
    return Q;
}

// ============================================================================
// GNSS Position Update
//
// Measurement:  z = [px_gnss, py_gnss]  (in local ENU)
// Model:        h(x) = [px, py]
// Jacobian:     H = [1 0 0 0 0 0 0 0]
//                   [0 1 0 0 0 0 0 0]
// Covariance:   R = sigma^2 * I2,  sigma = max(accuracy, min_accuracy)
// ============================================================================
bool EKF::updateGNSSPosition(const Eigen::Vector2d& pos_enu, double accuracy_m) {
    if (!initialized_) return false;
    
    if (!std::isfinite(pos_enu.x()) || !std::isfinite(pos_enu.y()) || !std::isfinite(accuracy_m)) {
        return false;
    }
    
    Eigen::Matrix<double, 2, 1> innovation;
    innovation << pos_enu.x() - x_(PX), pos_enu.y() - x_(PY);
    
    Eigen::Matrix<double, 2, STATE_DIM> H = Eigen::Matrix<double, 2, STATE_DIM>::Zero();
    H(0, PX) = 1.0;
    H(1, PY) = 1.0;
    
    double sigma = std::max(accuracy_m, config_.gnss_min_accuracy_m);
    Eigen::Matrix<double, 2, 2> R = Eigen::Matrix<double, 2, 2>::Identity() * (sigma * sigma);
    
    return applyUpdate<2>(innovation, H, R, config_.gating.gnss_position);
}

// ============================================================================
// GNSS Velocity Update
//
// Measurement:  z = [vx_gnss, vy_gnss]  (ENU velocity)
// Model:        h(x) = [vx, vy]
// Jacobian:     H = [0 0 1 0 0 0 0 0]
//                   [0 0 0 1 0 0 0 0]
// ============================================================================
bool EKF::updateGNSSVelocity(const Eigen::Vector2d& vel_enu, double accuracy_mps) {
    if (!initialized_) return false;
    
    if (!std::isfinite(vel_enu.x()) || !std::isfinite(vel_enu.y()) || !std::isfinite(accuracy_mps)) {
        return false;
    }
    
    Eigen::Matrix<double, 2, 1> innovation;
    innovation << vel_enu.x() - x_(VX), vel_enu.y() - x_(VY);
    
    Eigen::Matrix<double, 2, STATE_DIM> H = Eigen::Matrix<double, 2, STATE_DIM>::Zero();
    H(0, VX) = 1.0;
    H(1, VY) = 1.0;
    
    double sigma = std::max(accuracy_mps, config_.gnss_min_velocity_accuracy);
    Eigen::Matrix<double, 2, 2> R = Eigen::Matrix<double, 2, 2>::Identity() * (sigma * sigma);
    
    return applyUpdate<2>(innovation, H, R, config_.gating.gnss_velocity);
}

// ============================================================================
// GNSS Course / Heading Update
//
// Measurement:  z = course_rad
// Model:        h(x) = yaw
// Innovation:   wrapAngle(z - yaw)  (angle wrapping critical!)
// Jacobian:     H = [0 0 0 0 1 0 0 0]
// ============================================================================
bool EKF::updateGNSSCourse(double course_rad, double accuracy_rad) {
    if (!initialized_) return false;
    
    if (!std::isfinite(course_rad) || !std::isfinite(accuracy_rad)) {
        return false;
    }
    
    Eigen::Matrix<double, 1, 1> innovation;
    innovation(0) = wrapAngle(course_rad - x_(YAW));
    
    Eigen::Matrix<double, 1, STATE_DIM> H = Eigen::Matrix<double, 1, STATE_DIM>::Zero();
    H(0, YAW) = 1.0;
    
    Eigen::Matrix<double, 1, 1> R;
    R(0, 0) = accuracy_rad * accuracy_rad;
    
    return applyUpdate<1>(innovation, H, R, config_.gating.gnss_course);
}

// ============================================================================
// ML Forward Velocity Update
//
// The ML model predicts forward vehicle velocity (scalar).
//
// Forward velocity from EKF state:
//   v_forward = cos(yaw)*vx + sin(yaw)*vy
//
// Measurement:  z = v_forward_ml
// Model:        h(x) = cos(yaw)*vx + sin(yaw)*vy
//
// Jacobian:
//   ∂h/∂vx  = cos(yaw)
//   ∂h/∂vy  = sin(yaw)
//   ∂h/∂yaw = -sin(yaw)*vx + cos(yaw)*vy
//
// Covariance:
//   sigma_effective = ml.sigma_mps / clamp(confidence, 0.01, 1.0)
//   R = sigma_effective^2
// ============================================================================
bool EKF::updateMLVelocity(const MLVelocityMeasurement& ml) {
    if (!initialized_) return false;
    
    // Validate input
    if (!ml.valid || !std::isfinite(ml.forward_velocity_mps) || ml.confidence <= 0.0) {
        return false;
    }
    if (ml.forward_velocity_mps < 0.0 || ml.forward_velocity_mps > config_.ml_max_velocity) {
        return false;
    }
    
    double yaw = x_(YAW);
    double cy = std::cos(yaw);
    double sy = std::sin(yaw);
    
    // Predicted forward velocity from EKF state
    double v_forward_pred = cy * x_(VX) + sy * x_(VY);
    
    Eigen::Matrix<double, 1, 1> innovation;
    innovation(0) = ml.forward_velocity_mps - v_forward_pred;
    
    // Jacobian H (1x8)
    Eigen::Matrix<double, 1, STATE_DIM> H = Eigen::Matrix<double, 1, STATE_DIM>::Zero();
    H(0, VX) = cy;
    H(0, VY) = sy;
    H(0, YAW) = -sy * x_(VX) + cy * x_(VY);
    
    // Confidence -> covariance mapping
    double confidence = std::clamp(ml.confidence, 0.01, 1.0);
    double sigma_effective = ml.sigma_mps / confidence;
    sigma_effective = std::clamp(sigma_effective, config_.ml_min_sigma, config_.ml_max_sigma);
    
    Eigen::Matrix<double, 1, 1> R;
    R(0, 0) = sigma_effective * sigma_effective;
    
    return applyUpdate<1>(innovation, H, R, config_.gating.ml_velocity);
}

// ============================================================================
// Non-Holonomic Constraint (NHC)
//
// Vehicle lateral velocity ≈ 0 for road vehicles.
//
// Lateral velocity in vehicle frame:
//   v_lateral = -sin(yaw)*vx + cos(yaw)*vy
//
// Measurement:  z = 0
// Model:        h(x) = -sin(yaw)*vx + cos(yaw)*vy
// Innovation:   0 - h(x) = -(-sin(yaw)*vx + cos(yaw)*vy)
//
// Jacobian:
//   ∂h/∂vx  = -sin(yaw)
//   ∂h/∂vy  =  cos(yaw)
//   ∂h/∂yaw = -cos(yaw)*vx - sin(yaw)*vy
// ============================================================================
bool EKF::updateNHC(double sigma) {
    if (!initialized_) return false;
    if (!std::isfinite(sigma) || sigma <= 0.0) return false;
    
    double yaw = x_(YAW);
    double cy = std::cos(yaw);
    double sy = std::sin(yaw);
    
    // Lateral velocity
    double v_lateral = -sy * x_(VX) + cy * x_(VY);
    
    Eigen::Matrix<double, 1, 1> innovation;
    innovation(0) = 0.0 - v_lateral;
    
    Eigen::Matrix<double, 1, STATE_DIM> H = Eigen::Matrix<double, 1, STATE_DIM>::Zero();
    H(0, VX) = -sy;
    H(0, VY) = cy;
    H(0, YAW) = -cy * x_(VX) - sy * x_(VY);
    
    Eigen::Matrix<double, 1, 1> R;
    R(0, 0) = sigma * sigma;
    
    return applyUpdate<1>(innovation, H, R, config_.gating.nhc);
}

// ============================================================================
// Zero Velocity Update (ZUPT)
//
// When vehicle is stationary: vx ≈ 0, vy ≈ 0
//
// Measurement:  z = [0, 0]
// Model:        h(x) = [vx, vy]
// Jacobian:     H = [0 0 1 0 0 0 0 0]
//                   [0 0 0 1 0 0 0 0]
// ============================================================================
bool EKF::updateZUPT(double sigma) {
    if (!initialized_) return false;
    if (!std::isfinite(sigma) || sigma <= 0.0) return false;
    
    Eigen::Matrix<double, 2, 1> innovation;
    innovation << -x_(VX), -x_(VY);
    
    Eigen::Matrix<double, 2, STATE_DIM> H = Eigen::Matrix<double, 2, STATE_DIM>::Zero();
    H(0, VX) = 1.0;
    H(1, VY) = 1.0;
    
    Eigen::Matrix<double, 2, 2> R = Eigen::Matrix<double, 2, 2>::Identity() * (sigma * sigma);
    
    return applyUpdate<2>(innovation, H, R, config_.gating.zupt);
}

// ============================================================================
// Map Cross-Track Constraint
//
// Simple nearest-road constraint: cross-track error should be zero.
//
// Measurement:  z = 0 (want to drive cross-track error to zero)
// Model:        h(x) = cross_track_error (provided externally)
// Innovation:   0 - cross_track_error
//
// Jacobian (w.r.t. position, given road heading):
//   ∂h/∂px = -sin(road_heading)
//   ∂h/∂py =  cos(road_heading)
// ============================================================================
bool EKF::updateMapCrossTrack(double cross_track_error, double road_heading, double sigma) {
    if (!initialized_) return false;
    
    if (!std::isfinite(cross_track_error) || !std::isfinite(road_heading) || !std::isfinite(sigma)) {
        return false;
    }
    
    Eigen::Matrix<double, 1, 1> innovation;
    innovation(0) = -cross_track_error;
    
    Eigen::Matrix<double, 1, STATE_DIM> H = Eigen::Matrix<double, 1, STATE_DIM>::Zero();
    H(0, PX) = -std::sin(road_heading);
    H(0, PY) =  std::cos(road_heading);
    
    Eigen::Matrix<double, 1, 1> R;
    R(0, 0) = sigma * sigma;
    
    return applyUpdate<1>(innovation, H, R, config_.gating.map_constraint);
}

// ============================================================================
// Covariance validation
// - Ensure all diagonal elements are finite, positive, and bounded
// - Reset NaN/Inf off-diagonal elements
// ============================================================================
void EKF::validateCovariance() {
    for (int i = 0; i < STATE_DIM; ++i) {
        // Fix diagonal
        if (!std::isfinite(P_(i, i))) {
            P_(i, i) = 1.0;
        } else if (P_(i, i) < 1e-15) {
            P_(i, i) = 1e-15;
        } else if (P_(i, i) > 1e10) {
            P_(i, i) = 1e10;
        }
        
        // Fix off-diagonal
        for (int j = 0; j < STATE_DIM; ++j) {
            if (!std::isfinite(P_(i, j))) {
                P_(i, j) = 0.0;
                if (i == j) P_(i, j) = 1.0;
            }
        }
    }
    // Final symmetrization after possible NaN patching
    P_ = 0.5 * (P_ + P_.transpose());
}

double EKF::positionSigma() const {
    // Combined horizontal position uncertainty
    return std::sqrt(P_(PX, PX) + P_(PY, PY));
}

double EKF::velocitySigma() const {
    return std::sqrt(P_(VX, VX) + P_(VY, VY));
}

double EKF::headingSigma() const {
    return std::sqrt(P_(YAW, YAW));
}

} // namespace fusion
