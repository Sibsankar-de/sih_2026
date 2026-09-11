#include <gtest/gtest.h>
#include "fusion.h"
#include <cmath>

using namespace fusion;

// Test Mahalanobis distance computation
TEST(GatingTest, MahalanobisDistance) {
    // 2D measurement
    Eigen::Matrix<double, 2, 1> innovation;
    innovation << 3.0, 4.0;
    
    Eigen::Matrix<double, 2, 2> S = Eigen::Matrix<double, 2, 2>::Identity();
    
    // d² = 3² + 4² = 25
    double d2 = gating::mahalanobisDistance<2>(innovation, S);
    EXPECT_NEAR(d2, 25.0, 1e-6);
}

// Test 1D Mahalanobis
TEST(GatingTest, MahalanobisDistance1D) {
    Eigen::Matrix<double, 1, 1> innovation;
    innovation << 3.0;
    
    Eigen::Matrix<double, 1, 1> S;
    S << 9.0;  // sigma² = 9
    
    // d² = 3² / 9 = 1.0
    double d2 = gating::mahalanobisDistance<1>(innovation, S);
    EXPECT_NEAR(d2, 1.0, 1e-6);
}

// Test gate passing
TEST(GatingTest, GatePassesNormal) {
    Eigen::Matrix<double, 2, 1> innovation;
    innovation << 1.0, 1.0;
    
    Eigen::Matrix<double, 2, 2> S = Eigen::Matrix<double, 2, 2>::Identity() * 10.0;
    
    // d² = (1+1)/10 = 0.2, should pass threshold of 25
    EXPECT_TRUE(gating::passesGate<2>(innovation, S, 25.0));
}

// Test 8: Outlier GNSS (1000m away) is rejected by gating
TEST(GatingTest, OutlierGNSSRejected) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    FusionConfig config;
    config.gating.gnss_position = 25.0;  // chi-squared threshold
    ekf.initialize(x, config);
    
    // GNSS at 1000m away — should be rejected
    Eigen::Vector2d gnss_pos(1000.0, 1000.0);
    EXPECT_FALSE(ekf.updateGNSSPosition(gnss_pos, 1.0));
    
    // Position should stay near origin
    EXPECT_NEAR(ekf.px(), 0.0, 0.1);
    EXPECT_NEAR(ekf.py(), 0.0, 0.1);
}

// Test: Normal GNSS within gate is accepted
TEST(GatingTest, NormalGNSSAccepted) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    ekf.initialize(x, FusionConfig());
    
    // GNSS at 5m away with 10m accuracy — should be accepted
    Eigen::Vector2d gnss_pos(5.0, 5.0);
    EXPECT_TRUE(ekf.updateGNSSPosition(gnss_pos, 10.0));
    
    // Position should have moved
    EXPECT_GT(ekf.px(), 0.0);
}
