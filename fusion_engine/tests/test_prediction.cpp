#include <gtest/gtest.h>
#include "fusion.h"
#include <cmath>

using namespace fusion;

static IMUSample makeIMU(double t, double ax, double ay, double gz) {
    IMUSample s;
    s.timestamp = t;
    s.accel = Eigen::Vector2d(ax, ay);
    s.gyro_z = gz;
    return s;
}

static FusionConfig defaultConfig() {
    return FusionConfig();
}

// Test 1: Straight-line motion at 10 m/s East
TEST(PredictionTest, StraightLineConstantVelocity) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    x(VX) = 10.0;  // 10 m/s East
    // yaw = 0 → East
    ekf.initialize(x, defaultConfig());
    
    // 101 samples: first stores timestamp, next 100 do prediction over 1 second
    for (int i = 0; i <= 100; ++i) {
        ekf.predict(makeIMU(i * 0.01, 0.0, 0.0, 0.0));
    }
    
    EXPECT_NEAR(ekf.px(), 10.0, 0.5);  // ~10m East
    EXPECT_NEAR(ekf.py(), 0.0, 0.5);   // ~0m North
    EXPECT_NEAR(ekf.vx(), 10.0, 0.1);
    EXPECT_NEAR(ekf.vy(), 0.0, 0.1);
}

// Test 2: Constant acceleration 1 m/s² East
TEST(PredictionTest, ConstantAcceleration) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    // yaw = 0 → acceleration in vehicle X maps to East
    ekf.initialize(x, defaultConfig());
    
    // 201 samples over 2 seconds
    for (int i = 0; i <= 200; ++i) {
        ekf.predict(makeIMU(i * 0.01, 1.0, 0.0, 0.0));
    }
    
    // x = 0.5 * a * t² = 0.5 * 1 * 4 = 2m
    EXPECT_NEAR(ekf.px(), 2.0, 0.2);
    // v = a * t = 1 * 2 = 2 m/s
    EXPECT_NEAR(ekf.vx(), 2.0, 0.1);
}

// Test 3: Constant turn rate
TEST(PredictionTest, ConstantTurn) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    x(VX) = 10.0;
    ekf.initialize(x, defaultConfig());
    
    double gyro_rate = M_PI / 4.0;  // 45 deg/s
    // 101 samples over 1 second
    for (int i = 0; i <= 100; ++i) {
        ekf.predict(makeIMU(i * 0.01, 0.0, 0.0, gyro_rate));
    }
    
    EXPECT_NEAR(ekf.yaw(), M_PI / 4.0, 0.05);  // ~45 degrees
}

// Test variable timestep
TEST(PredictionTest, VariableTimestep) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    x(VX) = 5.0;
    ekf.initialize(x, defaultConfig());
    
    ekf.predict(makeIMU(0.0,  0.0, 0.0, 0.0));  // sets timestamp
    ekf.predict(makeIMU(0.1,  0.0, 0.0, 0.0));  // dt = 0.1
    ekf.predict(makeIMU(0.3,  0.0, 0.0, 0.0));  // dt = 0.2
    ekf.predict(makeIMU(0.35, 0.0, 0.0, 0.0));  // dt = 0.05
    
    // Total time = 0.35, px = 5.0 * 0.35 = 1.75
    EXPECT_NEAR(ekf.px(), 1.75, 0.1);
}

// Test dt rejection
TEST(PredictionTest, DtRejection) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    ekf.initialize(x, defaultConfig());
    
    EXPECT_TRUE(ekf.predict(makeIMU(1.0, 0.0, 0.0, 0.0)));   // sets timestamp
    EXPECT_FALSE(ekf.predict(makeIMU(0.5, 0.0, 0.0, 0.0)));   // negative dt → rejected
    EXPECT_FALSE(ekf.predict(makeIMU(100.0, 0.0, 0.0, 0.0)));  // dt=99s > max → rejected
}
