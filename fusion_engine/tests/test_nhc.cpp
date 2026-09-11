#include <gtest/gtest.h>
#include "fusion.h"
#include <cmath>

using namespace fusion;

// Test 7: NHC reduces lateral velocity
TEST(NHCTest, ReducesLateralVelocity) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    x(VX) = 10.0;  // Forward velocity (East)
    x(VY) = 2.0;   // Lateral velocity (North) — should be suppressed
    x(YAW) = 0.0;  // heading East
    ekf.initialize(x, FusionConfig());
    
    // With yaw=0, lateral velocity = -sin(0)*vx + cos(0)*vy = vy
    double initial_lateral = ekf.vy();
    
    // Apply NHC multiple times
    for (int i = 0; i < 10; ++i) {
        ekf.updateNHC(0.1);
    }
    
    // Lateral velocity should decrease
    double final_lateral = std::abs(-std::sin(ekf.yaw()) * ekf.vx() + std::cos(ekf.yaw()) * ekf.vy());
    EXPECT_LT(final_lateral, std::abs(initial_lateral));
    EXPECT_NEAR(final_lateral, 0.0, 0.5);
}

// Test: NHC doesn't significantly affect forward velocity
TEST(NHCTest, PreservesForwardVelocity) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    x(VX) = 10.0;
    x(VY) = 0.5;   // small lateral component
    x(YAW) = 0.0;
    ekf.initialize(x, FusionConfig());
    
    double initial_forward = std::cos(ekf.yaw()) * ekf.vx() + std::sin(ekf.yaw()) * ekf.vy();
    
    for (int i = 0; i < 10; ++i) {
        ekf.updateNHC(0.1);
    }
    
    double final_forward = std::cos(ekf.yaw()) * ekf.vx() + std::sin(ekf.yaw()) * ekf.vy();
    
    // Forward velocity should be largely preserved
    EXPECT_NEAR(final_forward, initial_forward, 1.0);
}
