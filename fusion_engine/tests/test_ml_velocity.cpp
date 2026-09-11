#include <gtest/gtest.h>
#include "fusion.h"
#include <cmath>

using namespace fusion;

static MLVelocityMeasurement makeML(double t, double vel, double conf, double sigma) {
    MLVelocityMeasurement ml;
    ml.timestamp = t;
    ml.forward_velocity_mps = vel;
    ml.confidence = conf;
    ml.sigma_mps = sigma;
    ml.valid = true;
    return ml;
}

// Test 6: ML velocity constrains EKF velocity
TEST(MLVelocityTest, UpdateMovesVelocity) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    x(VX) = 5.0;   // EKF thinks 5 m/s East
    x(YAW) = 0.0;  // heading East → forward = East
    ekf.initialize(x, FusionConfig());
    
    // ML says forward velocity is 10 m/s
    EXPECT_TRUE(ekf.updateMLVelocity(makeML(1.0, 10.0, 0.9, 0.5)));
    
    // vx should increase toward 10
    EXPECT_GT(ekf.vx(), 5.0);
}

// Test: High confidence has stronger effect
TEST(MLVelocityTest, HighConfidenceStrongerEffect) {
    // Test with high confidence
    EKF ekf_high;
    StateVector x1 = StateVector::Zero();
    x1(VX) = 5.0;
    ekf_high.initialize(x1, FusionConfig());
    ekf_high.updateMLVelocity(makeML(1.0, 10.0, 0.95, 0.5));
    double vx_high = ekf_high.vx();
    
    // Test with low confidence
    EKF ekf_low;
    StateVector x2 = StateVector::Zero();
    x2(VX) = 5.0;
    ekf_low.initialize(x2, FusionConfig());
    ekf_low.updateMLVelocity(makeML(1.0, 10.0, 0.2, 0.5));
    double vx_low = ekf_low.vx();
    
    // High confidence should cause a bigger correction
    EXPECT_GT(vx_high, vx_low);
}

// Test: Invalid ML measurements are rejected
TEST(MLVelocityTest, InvalidMeasurementsRejected) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    ekf.initialize(x, FusionConfig());
    
    // NaN velocity
    MLVelocityMeasurement ml_nan = makeML(1.0, std::nan(""), 0.9, 0.5);
    EXPECT_FALSE(ekf.updateMLVelocity(ml_nan));
    
    // Negative velocity
    MLVelocityMeasurement ml_neg = makeML(1.0, -5.0, 0.9, 0.5);
    EXPECT_FALSE(ekf.updateMLVelocity(ml_neg));
    
    // Too high velocity
    MLVelocityMeasurement ml_high = makeML(1.0, 200.0, 0.9, 0.5);
    EXPECT_FALSE(ekf.updateMLVelocity(ml_high));
    
    // Zero confidence
    MLVelocityMeasurement ml_zero_conf = makeML(1.0, 10.0, 0.0, 0.5);
    EXPECT_FALSE(ekf.updateMLVelocity(ml_zero_conf));
    
    // Invalid flag
    MLVelocityMeasurement ml_invalid = makeML(1.0, 10.0, 0.9, 0.5);
    ml_invalid.valid = false;
    EXPECT_FALSE(ekf.updateMLVelocity(ml_invalid));
}
