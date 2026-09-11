#pragma once

#include "fusion/types.h"
#include <Eigen/Core>
#include <Eigen/Dense>
#include <cmath>
#include <algorithm>

namespace fusion {

/// 2D Extended Kalman Filter for vehicle navigation.
///
/// State vector x = [px, py, vx, vy, yaw, bax, bay, bg]^T
///   px, py  = local ENU position [m]
///   vx, vy  = local ENU velocity [m/s]
///   yaw     = vehicle heading [rad]
///   bax, bay = accelerometer biases [m/s^2]
///   bg      = gyroscope Z bias [rad/s]
///
/// The EKF uses:
///   - IMU for prediction (state propagation)
///   - GNSS position/velocity/course for correction
///   - ML forward velocity for correction
///   - Non-holonomic constraint (NHC) for correction
///   - Zero velocity update (ZUPT) for correction
///   - Map constraints for correction
class EKF {
public:
    EKF();
    
    /// Initialize the EKF state and covariance
    void initialize(const StateVector& initial_state, const FusionConfig& config);
    
    /// IMU prediction step
    /// @param imu Vehicle-frame IMU sample (already aligned from phone frame)
    /// @param noise_scale Adaptive noise multiplier (>=1.0)
    /// @return true if prediction was successful
    bool predict(const IMUSample& imu, double noise_scale = 1.0);
    
    // --- Measurement updates ---
    
    /// GNSS position update
    bool updateGNSSPosition(const Eigen::Vector2d& pos_enu, double accuracy_m);
    
    /// GNSS velocity update  
    bool updateGNSSVelocity(const Eigen::Vector2d& vel_enu, double accuracy_mps);
    
    /// GNSS course/heading update
    bool updateGNSSCourse(double course_rad, double accuracy_rad);
    
    /// ML forward velocity update
    bool updateMLVelocity(const MLVelocityMeasurement& ml);
    
    /// Non-holonomic constraint (lateral velocity ≈ 0)
    bool updateNHC(double sigma);
    
    /// Zero velocity update (vehicle stationary)
    bool updateZUPT(double sigma);
    
    /// Map cross-track constraint
    bool updateMapCrossTrack(double cross_track_error, double road_heading, double sigma);
    
    // --- Accessors ---
    
    const StateVector& state() const { return x_; }
    const StateMatrix& covariance() const { return P_; }
    
    double px() const { return x_(PX); }
    double py() const { return x_(PY); }
    double vx() const { return x_(VX); }
    double vy() const { return x_(VY); }
    double yaw() const { return x_(YAW); }
    double bax() const { return x_(BAX); }
    double bay() const { return x_(BAY); }
    double bg() const { return x_(BG); }
    
    double speed() const { return std::sqrt(x_(VX)*x_(VX) + x_(VY)*x_(VY)); }
    
    double positionSigma() const;
    double velocitySigma() const;
    double headingSigma() const;
    
    double lastTimestamp() const { return last_timestamp_; }
    bool isInitialized() const { return initialized_; }
    
    void setConfig(const FusionConfig& config) { config_ = config; }
    
private:
    /// Generic EKF measurement update using Joseph form.
    /// @tparam MeasDim Dimension of the measurement
    /// @param innovation z - h(x)
    /// @param H Measurement Jacobian
    /// @param R Measurement covariance
    /// @param gate_threshold Chi-squared gating threshold
    /// @return true if update was applied (not rejected by gate)
    template<int MeasDim>
    bool applyUpdate(
        const Eigen::Matrix<double, MeasDim, 1>& innovation,
        const Eigen::Matrix<double, MeasDim, STATE_DIM>& H,
        const Eigen::Matrix<double, MeasDim, MeasDim>& R,
        double gate_threshold
    );
    
    /// Compute process noise matrix Q for a given dt and noise scale
    StateMatrix computeProcessNoise(double dt, const IMUSample& imu, double noise_scale) const;
    
    /// Compute state transition Jacobian F
    StateMatrix computeF(double dt, const IMUSample& imu) const;
    
    /// Validate and fix covariance matrix
    void validateCovariance();
    
    StateVector x_;        // state vector
    StateMatrix P_;        // state covariance
    FusionConfig config_;
    double last_timestamp_ = 0.0;
    bool initialized_ = false;
};

// ============================================================================
// Template implementations
// ============================================================================

template<int MeasDim>
bool EKF::applyUpdate(
    const Eigen::Matrix<double, MeasDim, 1>& innovation,
    const Eigen::Matrix<double, MeasDim, STATE_DIM>& H,
    const Eigen::Matrix<double, MeasDim, MeasDim>& R,
    double gate_threshold
) {
    if (!initialized_) return false;
    
    // Innovation covariance S = H*P*H^T + R
    Eigen::Matrix<double, MeasDim, MeasDim> S = H * P_ * H.transpose() + R;
    
    // Use LDLT decomposition for numerical stability and inversion-free solving
    auto ldlt_S = S.ldlt();
    if (ldlt_S.info() != Eigen::Success) {
        return false;
    }
    
    // Mahalanobis distance d2 = innovation^T * S^(-1) * innovation
    Eigen::Matrix<double, MeasDim, 1> S_inv_inn = ldlt_S.solve(innovation);
    double d2 = innovation.dot(S_inv_inn);
    
    // Gate rejection
    if (std::isfinite(gate_threshold) && gate_threshold > 0.0 && d2 > gate_threshold) {
        return false;
    }
    
    // Kalman Gain K = P * H^T * S^(-1)
    // Compute PHt = P * H^T
    Eigen::Matrix<double, STATE_DIM, MeasDim> PHt = P_ * H.transpose();
    
    // Solve S * K^T = H * P  => K = PHt * S^(-1)
    Eigen::Matrix<double, MeasDim, MeasDim> I = Eigen::Matrix<double, MeasDim, MeasDim>::Identity();
    Eigen::Matrix<double, MeasDim, MeasDim> S_inv = ldlt_S.solve(I);
    Eigen::Matrix<double, STATE_DIM, MeasDim> K = PHt * S_inv;
    
    // Update state vector: x = x + K * innovation
    x_ += K * innovation;
    
    // Wrap yaw to [-pi, pi]
    x_(YAW) = wrapAngle(x_(YAW));
    
    // Update covariance using Joseph form: P = (I - K*H) * P * (I - K*H)^T + K * R * K^T
    Eigen::Matrix<double, STATE_DIM, STATE_DIM> I_state = Eigen::Matrix<double, STATE_DIM, STATE_DIM>::Identity();
    Eigen::Matrix<double, STATE_DIM, STATE_DIM> IKH = I_state - K * H;
    
    P_ = IKH * P_ * IKH.transpose() + K * R * K.transpose();
    
    // Symmetrize covariance: P = 0.5 * (P + P^T)
    P_ = 0.5 * (P_ + P_.transpose());
    
    // Validate bounds
    validateCovariance();
    
    return true;
}

} // namespace fusion
