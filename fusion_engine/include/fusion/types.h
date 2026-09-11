#pragma once
#include <Eigen/Core>
#include <cmath>
#include <string>

namespace fusion {

// State dimensions
constexpr int STATE_DIM = 8;

// State indices
constexpr int PX = 0;
constexpr int PY = 1;
constexpr int VX = 2;
constexpr int VY = 3;
constexpr int YAW = 4;
constexpr int BAX = 5;
constexpr int BAY = 6;
constexpr int BG = 7;

// Fixed-size types
using StateVector = Eigen::Matrix<double, STATE_DIM, 1>;
using StateMatrix = Eigen::Matrix<double, STATE_DIM, STATE_DIM>;

// Constants
constexpr double EARTH_RADIUS = 6378137.0; // WGS84 semi-major axis [m]
constexpr double DEG_TO_RAD = M_PI / 180.0;
constexpr double RAD_TO_DEG = 180.0 / M_PI;

/// Wrap angle to [-pi, pi]
inline double wrapAngle(double angle) {
    while (angle > M_PI) angle -= 2.0 * M_PI;
    while (angle < -M_PI) angle += 2.0 * M_PI;
    return angle;
}

/// Check if value is finite (not NaN, not Inf)
inline bool isFinite(double v) { return std::isfinite(v); }

/// Check if an Eigen vector has all finite elements
template<typename Derived>
bool isFinite(const Eigen::MatrixBase<Derived>& m) {
    return m.allFinite();
}

// --- Sensor Data Types ---

struct IMUSample {
    double timestamp;           // seconds
    Eigen::Vector2d accel;      // vehicle-frame horizontal acceleration [m/s^2]
    double gyro_z;              // vehicle-frame yaw rate [rad/s]
};

struct GNSSMeasurement {
    double timestamp;
    double latitude_deg;
    double longitude_deg;
    double horizontal_accuracy_m;
    bool has_velocity;
    Eigen::Vector2d velocity_enu;  // [vE, vN] [m/s]
    double velocity_accuracy_mps;
    bool has_course;
    double course_rad;            // heading from GNSS [rad]
    bool valid;
};

struct MLVelocityMeasurement {
    double timestamp;
    double forward_velocity_mps;  // vehicle forward speed [m/s]
    double confidence;            // [0, 1]
    double sigma_mps;             // measurement std dev
    bool valid;
};

struct VibrationInfo {
    double timestamp;
    double noise_score;           // [0, 1]
    bool pothole_detected;
    bool severe_vibration;
    bool phone_motion_detected;
    double confidence;
};

struct AlignmentResult {
    double yaw_offset;
    double pitch;
    double roll;
    bool valid;
    double confidence;
};

struct MapConstraint {
    double timestamp;
    double cross_track_error_m;
    double road_heading_rad;
    double confidence;
    bool valid;
};

// --- Output Types ---

struct NavigationState {
    double timestamp = 0.0;
    double latitude_deg = 0.0;
    double longitude_deg = 0.0;
    double east_m = 0.0;
    double north_m = 0.0;
    double velocity_east_mps = 0.0;
    double velocity_north_mps = 0.0;
    double speed_mps = 0.0;
    double heading_rad = 0.0;
    double position_sigma_m = 0.0;
    double velocity_sigma_mps = 0.0;
    double heading_sigma_rad = 0.0;
    bool gnss_available = false;
    bool dead_reckoning = false;
};

enum class FusionMode {
    UNINITIALIZED,
    INITIALIZING,
    GNSS_AIDED,
    GNSS_DEGRADED,
    DEAD_RECKONING,
    GNSS_REACQUIRING,
    ERROR
};

enum class GNSSQuality {
    AVAILABLE,
    DEGRADED,
    LOST
};

struct FusionStatus {
    FusionMode mode = FusionMode::UNINITIALIZED;
    GNSSQuality gnss_quality = GNSSQuality::LOST;
    double last_gnss_timestamp = 0.0;
    double gnss_outage_duration = 0.0;
    int imu_samples_processed = 0;
    int gnss_updates_applied = 0;
    int gnss_updates_rejected = 0;
    int ml_updates_applied = 0;
    int ml_updates_rejected = 0;
    int nhc_updates_applied = 0;
    int zupt_updates_applied = 0;
};

// --- Configuration ---

struct ProcessNoiseParameters {
    double accel_noise = 0.5;              // m/s^2/sqrt(Hz)
    double gyro_noise = 0.01;              // rad/s/sqrt(Hz)
    double accel_bias_random_walk = 0.001; // m/s^2*sqrt(Hz) (or m/s^3/sqrt(Hz))
    double gyro_bias_random_walk = 0.0001; // rad/s*sqrt(Hz) (or rad/s^2/sqrt(Hz))
};

struct GatingThresholds {
    double gnss_position = 25.0;    // chi-squared threshold for 2-DOF
    double gnss_velocity = 16.0;    // chi-squared threshold for 2-DOF
    double gnss_course = 9.0;       // chi-squared threshold for 1-DOF
    double ml_velocity = 9.0;       // chi-squared threshold for 1-DOF
    double nhc = 9.0;               // chi-squared threshold for 1-DOF
    double zupt = 16.0;             // chi-squared threshold for 2-DOF
    double map_constraint = 9.0;    // chi-squared threshold for 1-DOF
    double magnetometer = 9.0;      // chi-squared threshold for 1-DOF
};

struct FusionConfig {
    ProcessNoiseParameters process_noise;
    GatingThresholds gating;
    
    // GNSS
    double gnss_min_accuracy_m = 1.0;        // minimum GNSS position sigma
    double gnss_min_velocity_accuracy = 0.1; // minimum GNSS velocity sigma
    double gnss_outage_timeout_s = 5.0;      // seconds before GNSS is considered lost
    double gnss_max_innovation_m = 100.0;    // max position innovation before rejection
    double gnss_min_course_speed_mps = 3.0;  // minimum speed for course update
    
    // ML
    double ml_min_sigma = 0.1;           // minimum ML velocity sigma
    double ml_max_sigma = 10.0;          // maximum ML velocity sigma
    double ml_max_velocity = 80.0;       // maximum plausible velocity [m/s]
    
    // NHC
    double nhc_sigma = 0.1;              // NHC lateral velocity sigma [m/s]
    double nhc_sigma_degraded = 1.0;     // NHC sigma when degraded
    
    // ZUPT
    double zupt_sigma = 0.01;            // ZUPT velocity sigma [m/s]
    double zupt_accel_threshold = 0.3;   // acceleration variation threshold for stationary detection
    double zupt_gyro_threshold = 0.05;   // gyro magnitude threshold for stationary detection
    double zupt_speed_threshold = 0.5;   // EKF speed threshold for stationary detection
    
    // Vibration / Adaptive noise
    double min_noise_scale = 1.0;
    double max_noise_scale = 10.0;
    
    // IMU
    double max_imu_dt = 0.5;             // maximum allowed IMU dt [s]
    
    // Map constraint
    double map_cross_track_sigma = 2.0;  // cross-track error sigma [m]
    double map_heading_sigma = 0.1;      // road heading sigma [rad]
    
    // Initialization
    double init_position_sigma = 10.0;   // initial position sigma [m]
    double init_velocity_sigma = 1.0;    // initial velocity sigma [m/s]
    double init_yaw_sigma = M_PI;        // initial yaw sigma [rad] (large if unknown)
    double init_accel_bias_sigma = 0.5;  // initial accel bias sigma [m/s^2]
    double init_gyro_bias_sigma = 0.05;  // initial gyro bias sigma [rad/s]
    double init_min_course_speed = 2.0;  // min speed for course-based yaw init
    
    // Logging
    bool enable_csv_logging = false;
    std::string log_file_path = "fusion_log.csv";
};

// Convert FusionMode to string for display
inline const char* fusionModeToString(FusionMode mode) {
    switch (mode) {
        case FusionMode::UNINITIALIZED:   return "UNINITIALIZED";
        case FusionMode::INITIALIZING:    return "INITIALIZING";
        case FusionMode::GNSS_AIDED:      return "GNSS_AIDED";
        case FusionMode::GNSS_DEGRADED:   return "GNSS_DEGRADED";
        case FusionMode::DEAD_RECKONING:  return "DEAD_RECKONING";
        case FusionMode::GNSS_REACQUIRING:return "GNSS_REACQUIRING";
        case FusionMode::ERROR:           return "ERROR";
        default:                          return "UNKNOWN";
    }
}

} // namespace fusion
