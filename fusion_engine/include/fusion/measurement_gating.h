#pragma once
#include <Eigen/Core>
#include <Eigen/Dense>
#include <limits>
#include <cmath>

namespace fusion {

/// Utility functions for measurement gating (Mahalanobis distance).
/// Used to reject outlier measurements before they corrupt the EKF state.
///
/// For a measurement with innovation r and innovation covariance S:
///   d² = r^T * S^{-1} * r
///
/// The measurement is accepted if d² < threshold (chi-squared).
///
/// Typical chi-squared thresholds (95% confidence):
///   1-DOF: 3.84 (but we use larger values for robustness)
///   2-DOF: 5.99
///   3-DOF: 7.81
namespace gating {

/// Compute Mahalanobis distance squared for a measurement.
/// Uses LDLT decomposition for numerical stability.
/// @tparam Dim Measurement dimension
/// @param innovation The measurement residual (z - h(x))
/// @param S Innovation covariance (H*P*H^T + R)
/// @return Mahalanobis distance squared, or infinity if S is not positive definite
template<int Dim>
double mahalanobisDistance(
    const Eigen::Matrix<double, Dim, 1>& innovation,
    const Eigen::Matrix<double, Dim, Dim>& S
) {
    // Input validation
    if (!innovation.allFinite() || !S.allFinite()) {
        return std::numeric_limits<double>::infinity();
    }

    // Use LDLT decomposition for numerical stability (never use inverse!)
    Eigen::LDLT<Eigen::Matrix<double, Dim, Dim>> ldlt(S);
    
    if (ldlt.info() != Eigen::Success || !ldlt.isPositive()) {
        return std::numeric_limits<double>::infinity();
    }
    
    // d² = innovation^T * S^{-1} * innovation
    // Computed as innovation^T * (S \ innovation) where S \ innovation = S.ldlt().solve(innovation)
    Eigen::Matrix<double, Dim, 1> S_inv_innovation = ldlt.solve(innovation);
    double d2 = innovation.dot(S_inv_innovation);
    
    // Sanity check
    if (!std::isfinite(d2) || d2 < 0.0) {
        return std::numeric_limits<double>::infinity();
    }
    
    return d2;
}

/// Check if a measurement passes the Mahalanobis gate
/// @tparam Dim Measurement dimension
/// @param innovation The measurement residual
/// @param S Innovation covariance
/// @param threshold Chi-squared threshold
/// @return true if the measurement passes (d² < threshold)
template<int Dim>
bool passesGate(
    const Eigen::Matrix<double, Dim, 1>& innovation,
    const Eigen::Matrix<double, Dim, Dim>& S,
    double threshold
) {
    if (!std::isfinite(threshold)) {
        return false;
    }
    return mahalanobisDistance<Dim>(innovation, S) < threshold;
}

} // namespace gating
} // namespace fusion
