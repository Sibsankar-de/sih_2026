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

static GNSSMeasurement makeGNSS(double t, double lat_deg, double lon_deg,
                                 double acc, double vx = 0, double vy = 0) {
    GNSSMeasurement g;
    g.timestamp = t;
    g.latitude_deg = lat_deg;
    g.longitude_deg = lon_deg;
    g.horizontal_accuracy_m = acc;
    g.has_velocity = true;
    g.velocity_enu = Eigen::Vector2d(vx, vy);
    g.velocity_accuracy_mps = 0.5;
    g.has_course = false;
    g.course_rad = 0.0;
    g.valid = true;
    return g;
}

// Test 5: Full GNSS outage and recovery scenario
TEST(OutageRecoveryTest, FullScenario) {
    FusionConfig config;
    config.gnss_outage_timeout_s = 2.0;  // 2s timeout for faster testing
    config.init_yaw_sigma = 0.1;
    
    FusionEngine engine;
    engine.initialize(config);
    
    // Initialize with GNSS at origin
    engine.processGNSS(makeGNSS(0.0, 0.0, 0.0, 1.0, 10.0, 0.0));
    EXPECT_TRUE(engine.isInitialized());
    
    // Phase 1: IMU + GNSS for 5 seconds (50 IMU steps + 5 GNSS)
    for (int i = 1; i <= 500; ++i) {
        double t = i * 0.01;
        engine.processIMU(makeIMU(t, 0.0, 0.0, 0.0));
        
        if (i % 100 == 0) {
            // GNSS at approximately correct position (10 m/s East)
            double east = 10.0 * t;
            double lat = east / EARTH_RADIUS * RAD_TO_DEG;  // approx
            engine.processGNSS(makeGNSS(t, lat, 0.0, 2.0, 10.0, 0.0));
        }
    }
    
    auto status_gnss = engine.getStatus();
    EXPECT_EQ(status_gnss.mode, FusionMode::GNSS_AIDED);
    
    auto state_before_outage = engine.getState();
    
    // Phase 2: GNSS outage for 5 seconds (IMU only)
    for (int i = 501; i <= 1000; ++i) {
        double t = i * 0.01;
        engine.processIMU(makeIMU(t, 0.0, 0.0, 0.0));
        engine.processNHC();  // Apply NHC to help during outage
    }
    
    // Should be in dead reckoning mode
    auto status_outage = engine.getStatus();
    EXPECT_EQ(status_outage.mode, FusionMode::DEAD_RECKONING);
    
    auto state_during_outage = engine.getState();
    // State should still be propagating (not frozen)
    EXPECT_GT(state_during_outage.east_m, state_before_outage.east_m);
    EXPECT_TRUE(state_during_outage.dead_reckoning);
    
    // Phase 3: GNSS returns
    double t_recovery = 10.01;
    double expected_east = 10.0 * t_recovery;
    double recovery_lat = expected_east / EARTH_RADIUS * RAD_TO_DEG;
    
    engine.processIMU(makeIMU(t_recovery, 0.0, 0.0, 0.0));
    engine.processGNSS(makeGNSS(t_recovery, recovery_lat, 0.0, 2.0, 10.0, 0.0));
    
    auto status_recovery = engine.getStatus();
    EXPECT_EQ(status_recovery.mode, FusionMode::GNSS_AIDED);
    
    auto state_after_recovery = engine.getState();
    EXPECT_FALSE(state_after_recovery.dead_reckoning);
    EXPECT_TRUE(state_after_recovery.gnss_available);
}

// Test: Mode transitions through the state machine
TEST(OutageRecoveryTest, ModeTransitions) {
    FusionConfig config;
    config.gnss_outage_timeout_s = 1.0;
    
    FusionEngine engine;
    engine.initialize(config);
    
    // Should start as INITIALIZING
    EXPECT_EQ(engine.getStatus().mode, FusionMode::INITIALIZING);
    
    // After GNSS init → GNSS_AIDED
    engine.processGNSS(makeGNSS(0.0, 0.0, 0.0, 1.0, 0.0, 0.0));
    EXPECT_EQ(engine.getStatus().mode, FusionMode::GNSS_AIDED);
    
    // Run IMU without GNSS until timeout → DEAD_RECKONING
    for (int i = 1; i <= 200; ++i) {
        engine.processIMU(makeIMU(i * 0.01, 0.0, 0.0, 0.0));
    }
    EXPECT_EQ(engine.getStatus().mode, FusionMode::DEAD_RECKONING);
    
    // Provide GNSS again → back to GNSS_AIDED
    engine.processIMU(makeIMU(2.01, 0.0, 0.0, 0.0));
    engine.processGNSS(makeGNSS(2.01, 0.0, 0.0, 1.0, 0.0, 0.0));
    EXPECT_EQ(engine.getStatus().mode, FusionMode::GNSS_AIDED);
}

// Test: State continuity during outage (no jumps or resets)
TEST(OutageRecoveryTest, StateContinuity) {
    FusionEngine engine;
    FusionConfig config;
    config.gnss_outage_timeout_s = 1.0;
    engine.initialize(config);
    
    engine.processGNSS(makeGNSS(0.0, 0.0, 0.0, 1.0, 5.0, 0.0));
    
    double prev_east = 0.0;
    for (int i = 1; i <= 300; ++i) {
        double t = i * 0.01;
        engine.processIMU(makeIMU(t, 0.0, 0.0, 0.0));
        
        auto state = engine.getState();
        // Position should always increase (moving East)
        EXPECT_GE(state.east_m, prev_east - 0.1);  // allow tiny numerical noise
        prev_east = state.east_m;
    }
}
