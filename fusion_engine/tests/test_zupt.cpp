#include <gtest/gtest.h>
#include "fusion.h"
#include <cmath>

using namespace fusion;

// Test: ZUPT drives velocity toward zero
TEST(ZUPTTest, ReducesVelocity) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    x(VX) = 0.3;  // Small velocity
    x(VY) = 0.2;
    ekf.initialize(x, FusionConfig());
    
    double initial_speed = ekf.speed();
    
    // Apply ZUPT multiple times
    for (int i = 0; i < 10; ++i) {
        ekf.updateZUPT(0.01);
    }
    
    EXPECT_LT(ekf.speed(), initial_speed);
    EXPECT_NEAR(ekf.speed(), 0.0, 0.1);
}

// Test: ZUPT with very small sigma strongly constrains velocity
TEST(ZUPTTest, StrongConstraint) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    x(VX) = 0.5;
    x(VY) = 0.5;
    ekf.initialize(x, FusionConfig());
    
    ekf.updateZUPT(0.001);  // Very strong constraint
    
    EXPECT_NEAR(ekf.vx(), 0.0, 0.1);
    EXPECT_NEAR(ekf.vy(), 0.0, 0.1);
}
