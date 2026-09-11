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

// Test 4: GNSS position update reduces error
TEST(GNSSTest, PositionUpdate) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    ekf.initialize(x, FusionConfig());
    
    // GNSS says we're at (10, 10) but EKF thinks (0, 0)
    Eigen::Vector2d gnss_pos(10.0, 10.0);
    EXPECT_TRUE(ekf.updateGNSSPosition(gnss_pos, 1.0));
    
    // Position should move toward GNSS measurement
    EXPECT_GT(ekf.px(), 0.0);
    EXPECT_GT(ekf.py(), 0.0);
}

// Test: Noisy GNSS converges to true position
TEST(GNSSTest, NoisyGNSSConverges) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    ekf.initialize(x, FusionConfig());
    
    // True position is (5, 5). Apply noisy measurements.
    for (int i = 0; i < 50; ++i) {
        double noise = (i % 2 == 0) ? 1.0 : -1.0;
        Eigen::Vector2d meas(5.0 + noise, 5.0 - noise);
        
        // Run a prediction step to advance time
        ekf.predict(makeIMU(i * 0.1, 0.0, 0.0, 0.0));
        ekf.updateGNSSPosition(meas, 2.0);
    }
    
    EXPECT_NEAR(ekf.px(), 5.0, 1.0);
    EXPECT_NEAR(ekf.py(), 5.0, 1.0);
}

// Test: GNSS velocity update
TEST(GNSSTest, VelocityUpdate) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    ekf.initialize(x, FusionConfig());
    
    Eigen::Vector2d vel_meas(5.0, 0.0);
    EXPECT_TRUE(ekf.updateGNSSVelocity(vel_meas, 0.5));
    
    EXPECT_GT(ekf.vx(), 0.0);
    EXPECT_NEAR(ekf.vy(), 0.0, 0.1);
}

// Test: GNSS course update
TEST(GNSSTest, CourseUpdate) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    ekf.initialize(x, FusionConfig());
    
    EXPECT_TRUE(ekf.updateGNSSCourse(M_PI / 4.0, 0.1));
    EXPECT_GT(ekf.yaw(), 0.0);
    EXPECT_LT(ekf.yaw(), M_PI / 2.0);
}

// Test 9: Filter doesn't blindly follow noisy GNSS
TEST(GNSSTest, FilterSmooths) {
    EKF ekf;
    StateVector x = StateVector::Zero();
    x(VX) = 10.0;  // moving East
    ekf.initialize(x, FusionConfig());
    
    double max_deviation = 0.0;
    for (int i = 0; i <= 100; ++i) {
        ekf.predict(makeIMU(i * 0.01, 0.0, 0.0, 0.0));
        
        if (i > 0 && i % 10 == 0) {
            // GNSS with large noise
            double noise = (i % 20 == 0) ? 5.0 : -5.0;
            Eigen::Vector2d meas(ekf.px() + noise, ekf.py() + noise);
            ekf.updateGNSSPosition(meas, 3.0);
            
            // EKF should not jump to the noisy measurement
            max_deviation = std::max(max_deviation, std::abs(noise));
        }
    }
    
    // The EKF position should be smoother than the raw GNSS noise
    EXPECT_LT(std::abs(ekf.py()), max_deviation);
}
