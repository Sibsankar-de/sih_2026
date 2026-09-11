#include <gtest/gtest.h>
#include "fusion.h"

using namespace fusion;

TEST(LocalFrameTest, InitializationAndOrigin) {
    LocalFrame frame;
    EXPECT_FALSE(frame.isInitialized());
    
    frame.setOrigin(37.7749, -122.4194);  // San Francisco
    EXPECT_TRUE(frame.isInitialized());
    EXPECT_NEAR(frame.originLatDeg(), 37.7749, 1e-6);
    EXPECT_NEAR(frame.originLonDeg(), -122.4194, 1e-6);
}

TEST(LocalFrameTest, OriginMapsToZero) {
    LocalFrame frame;
    frame.setOrigin(37.7749, -122.4194);
    
    Eigen::Vector2d local = frame.geoToLocal(37.7749, -122.4194);
    EXPECT_NEAR(local.x(), 0.0, 1e-6);  // east
    EXPECT_NEAR(local.y(), 0.0, 1e-6);  // north
}

TEST(LocalFrameTest, KnownOffset) {
    LocalFrame frame;
    frame.setOrigin(0.0, 0.0);
    
    // 0.001 degrees latitude ≈ 111.19 m north
    Eigen::Vector2d local = frame.geoToLocal(0.001, 0.0);
    EXPECT_NEAR(local.x(), 0.0, 0.1);         // east should be ~0
    EXPECT_NEAR(local.y(), 111.19, 1.0);       // north should be ~111m
    
    // 0.001 degrees longitude at equator ≈ 111.19 m east
    Eigen::Vector2d local2 = frame.geoToLocal(0.0, 0.001);
    EXPECT_NEAR(local2.x(), 111.19, 1.0);      // east
    EXPECT_NEAR(local2.y(), 0.0, 0.1);         // north should be ~0
}

TEST(LocalFrameTest, Roundtrip) {
    LocalFrame frame;
    frame.setOrigin(48.8566, 2.3522);  // Paris
    
    double test_lat = 48.8600;
    double test_lon = 2.3550;
    
    Eigen::Vector2d local = frame.geoToLocal(test_lat, test_lon);
    auto [lat_back, lon_back] = frame.localToGeo(local.x(), local.y());
    
    EXPECT_NEAR(lat_back, test_lat, 1e-6);
    EXPECT_NEAR(lon_back, test_lon, 1e-6);
}

TEST(LocalFrameTest, MultiplePoints) {
    LocalFrame frame;
    frame.setOrigin(0.0, 0.0);
    
    // Points at various offsets
    Eigen::Vector2d p1 = frame.geoToLocal(0.01, 0.0);   // north
    Eigen::Vector2d p2 = frame.geoToLocal(0.0, 0.01);   // east
    Eigen::Vector2d p3 = frame.geoToLocal(-0.01, 0.0);  // south
    
    EXPECT_GT(p1.y(), 0.0);   // north is positive
    EXPECT_GT(p2.x(), 0.0);   // east is positive
    EXPECT_LT(p3.y(), 0.0);   // south is negative
    EXPECT_NEAR(p1.y(), -p3.y(), 1.0);  // symmetric
}
