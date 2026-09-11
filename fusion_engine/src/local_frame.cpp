#include "fusion/local_frame.h"
#include "fusion/types.h"

namespace fusion {

void LocalFrame::setOrigin(double latitude_deg, double longitude_deg, double altitude) {
    origin_lat_rad_ = latitude_deg * DEG_TO_RAD;
    origin_lon_rad_ = longitude_deg * DEG_TO_RAD;
    origin_alt_ = altitude;
    cos_lat0_ = std::cos(origin_lat_rad_);
    initialized_ = true;
}

bool LocalFrame::isInitialized() const {
    return initialized_;
}

Eigen::Vector2d LocalFrame::geoToLocal(double latitude_deg, double longitude_deg) const {
    if (!initialized_) {
        return Eigen::Vector2d::Zero();
    }
    
    double lat_rad = latitude_deg * DEG_TO_RAD;
    double lon_rad = longitude_deg * DEG_TO_RAD;
    
    double dlat = lat_rad - origin_lat_rad_;
    double dlon = lon_rad - origin_lon_rad_;
    
    double east = EARTH_RADIUS * cos_lat0_ * dlon;
    double north = EARTH_RADIUS * dlat;
    
    return Eigen::Vector2d(east, north);
}

std::pair<double, double> LocalFrame::localToGeo(double east, double north) const {
    if (!initialized_) {
        return {0.0, 0.0};
    }
    
    double dlat = north / EARTH_RADIUS;
    double dlon = east / (EARTH_RADIUS * cos_lat0_);
    
    double lat_rad = origin_lat_rad_ + dlat;
    double lon_rad = origin_lon_rad_ + dlon;
    
    return {lat_rad * RAD_TO_DEG, lon_rad * RAD_TO_DEG};
}

double LocalFrame::originLatDeg() const {
    return origin_lat_rad_ * RAD_TO_DEG;
}

double LocalFrame::originLonDeg() const {
    return origin_lon_rad_ * RAD_TO_DEG;
}

double LocalFrame::originAlt() const {
    return origin_alt_;
}

} // namespace fusion
