#include "fusion/measurement_gating.h"

// Template functions are header-only.
// This file provides explicit instantiations for common dimensions
// to catch compilation errors early.

namespace fusion {
namespace gating {

// Explicit instantiations for common measurement dimensions
template double mahalanobisDistance<1>(
    const Eigen::Matrix<double, 1, 1>&,
    const Eigen::Matrix<double, 1, 1>&);

template double mahalanobisDistance<2>(
    const Eigen::Matrix<double, 2, 1>&,
    const Eigen::Matrix<double, 2, 2>&);

template double mahalanobisDistance<3>(
    const Eigen::Matrix<double, 3, 1>&,
    const Eigen::Matrix<double, 3, 3>&);

template bool passesGate<1>(
    const Eigen::Matrix<double, 1, 1>&,
    const Eigen::Matrix<double, 1, 1>&,
    double);

template bool passesGate<2>(
    const Eigen::Matrix<double, 2, 1>&,
    const Eigen::Matrix<double, 2, 2>&,
    double);

template bool passesGate<3>(
    const Eigen::Matrix<double, 3, 1>&,
    const Eigen::Matrix<double, 3, 3>&,
    double);

} // namespace gating
} // namespace fusion
