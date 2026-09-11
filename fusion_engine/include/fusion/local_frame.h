#pragma once
#include <Eigen/Core>
#include <utility>

namespace fusion {

/// Local tangent plane frame for converting between geographic and ENU coordinates.
/// Uses a flat-earth approximation centered at an origin point.
/// 
/// Conversion equations:
///   East  ≈ R * cos(lat0) * (lon - lon0)
///   North ≈ R * (lat - lat0)
/// where R = 6378137.0 m (WGS84 semi-major axis)
class LocalFrame {
public:
    LocalFrame() = default;
    
    /// Initialize the local frame with an origin point
    /// @param latitude_deg  Origin latitude in degrees
    /// @param longitude_deg Origin longitude in degrees
    /// @param altitude      Origin altitude in meters (stored but not used in 2D)
    void setOrigin(double latitude_deg, double longitude_deg, double altitude = 0.0);
    
    /// Check if the origin has been set
    bool isInitialized() const;
    
    /// Convert geographic coordinates to local ENU
    /// @param latitude_deg  Latitude in degrees
    /// @param longitude_deg Longitude in degrees
    /// @return (East, North) in meters
    Eigen::Vector2d geoToLocal(double latitude_deg, double longitude_deg) const;
    
    /// Convert local ENU coordinates to geographic
    /// @param east  East coordinate in meters
    /// @param north North coordinate in meters
    /// @return (latitude_deg, longitude_deg)
    std::pair<double, double> localToGeo(double east, double north) const;
    
    double originLatDeg() const;
    double originLonDeg() const;
    double originAlt() const;
    
private:
    double origin_lat_rad_ = 0.0;
    double origin_lon_rad_ = 0.0;
    double origin_alt_ = 0.0;
    double cos_lat0_ = 1.0;  // precomputed cos(lat0) for efficiency
    bool initialized_ = false;
};

} // namespace fusion
