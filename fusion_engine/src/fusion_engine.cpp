#include "fusion/fusion_engine.h"

#include <cmath>
#include <iostream>
#include <iomanip>

namespace fusion {

FusionEngine::FusionEngine() {
    status_.mode = FusionMode::UNINITIALIZED;
    status_.gnss_quality = GNSSQuality::LOST;
}

FusionEngine::~FusionEngine() {
    if (log_file_open_) {
        log_file_.close();
    }
}

bool FusionEngine::initialize(const FusionConfig& config) {
    config_ = config;
    noise_model_.configure(config_.min_noise_scale, config_.max_noise_scale);
    mode_ = FusionMode::INITIALIZING;
    status_.mode = mode_;
    
    if (config_.enable_csv_logging) {
        openLogFile();
    }
    
    return true;
}

bool FusionEngine::processIMU(const IMUSample& sample) {
    // Validate inputs
    if (!isFinite(sample.timestamp) || !isFinite(sample.accel) || !isFinite(sample.gyro_z)) {
        return false;
    }
    
    if (mode_ == FusionMode::UNINITIALIZED || mode_ == FusionMode::INITIALIZING) {
        current_time_ = sample.timestamp;
        return false;
    }
    
    double noise_scale = noise_model_.getNoiseScale();
    if (!ekf_.predict(sample, noise_scale)) {
        return false;
    }
    
    current_time_ = sample.timestamp;
    status_.imu_samples_processed++;
    
    // Check GNSS timeout
    updateGNSSQuality(current_time_, false);
    
    return true;
}

bool FusionEngine::processGNSS(const GNSSMeasurement& measurement) {
    // Validate
    if (!measurement.valid ||
        !isFinite(measurement.latitude_deg) || !isFinite(measurement.longitude_deg) ||
        measurement.horizontal_accuracy_m <= 0.0) {
        return false;
    }
    
    // If not yet initialized, try to initialize from this GNSS fix
    if (mode_ == FusionMode::UNINITIALIZED || mode_ == FusionMode::INITIALIZING) {
        return tryInitialize(measurement);
    }
    
    // Convert lat/lon to local ENU
    Eigen::Vector2d pos_enu = local_frame_.geoToLocal(measurement.latitude_deg, measurement.longitude_deg);
    
    bool update_applied = false;
    
    // Position update
    if (ekf_.updateGNSSPosition(pos_enu, measurement.horizontal_accuracy_m)) {
        update_applied = true;
    }
    
    // Velocity update
    if (measurement.has_velocity) {
        if (ekf_.updateGNSSVelocity(measurement.velocity_enu, measurement.velocity_accuracy_mps)) {
            update_applied = true;
        }
    }
    
    // Course update (only at sufficient speed)
    if (measurement.has_course && ekf_.speed() > config_.gnss_min_course_speed_mps) {
        if (ekf_.updateGNSSCourse(measurement.course_rad, 0.1)) {
            update_applied = true;
        }
    }
    
    // Update counters
    if (update_applied) {
        status_.gnss_updates_applied++;
        consecutive_gnss_rejections_ = 0;
    } else {
        status_.gnss_updates_rejected++;
        consecutive_gnss_rejections_++;
    }
    
    updateGNSSQuality(measurement.timestamp, update_applied);
    
    return update_applied;
}

bool FusionEngine::tryInitialize(const GNSSMeasurement& gnss) {
    // Set local frame origin from first GNSS fix
    if (!local_frame_.isInitialized()) {
        local_frame_.setOrigin(gnss.latitude_deg, gnss.longitude_deg);
    }
    
    // Build initial state
    StateVector initial_state = StateVector::Zero();
    // Position = (0,0) since this is the origin
    
    // Initialize velocity from GNSS if available
    if (gnss.has_velocity) {
        initial_state(VX) = gnss.velocity_enu.x();
        initial_state(VY) = gnss.velocity_enu.y();
    }
    
    // Initialize yaw from course if speed is sufficient
    if (gnss.has_course && gnss.has_velocity) {
        double gnss_speed = gnss.velocity_enu.norm();
        if (gnss_speed > config_.init_min_course_speed) {
            initial_state(YAW) = gnss.course_rad;
        }
    }
    
    // Biases initialized to zero
    
    // Initialize EKF
    ekf_.initialize(initial_state, config_);
    
    mode_ = FusionMode::GNSS_AIDED;
    status_.mode = mode_;
    last_gnss_time_ = gnss.timestamp;
    current_time_ = gnss.timestamp;
    gnss_quality_ = GNSSQuality::AVAILABLE;
    status_.gnss_quality = gnss_quality_;
    
    return true;
}

bool FusionEngine::processMLVelocity(const MLVelocityMeasurement& measurement) {
    if (!measurement.valid || !isFinite(measurement.forward_velocity_mps) ||
        !isFinite(measurement.confidence) || measurement.confidence <= 0.0) {
        return false;
    }
    
    if (!isInitialized()) {
        return false;
    }
    
    if (ekf_.updateMLVelocity(measurement)) {
        status_.ml_updates_applied++;
        return true;
    }
    
    status_.ml_updates_rejected++;
    return false;
}

bool FusionEngine::processVibration(const VibrationInfo& vibration) {
    noise_model_.updateVibration(vibration);
    return true;
}

bool FusionEngine::processNHC() {
    if (!isInitialized()) {
        return false;
    }
    
    double nhc_sigma = noise_model_.getNHCSigma(config_.nhc_sigma, config_.nhc_sigma_degraded);
    if (ekf_.updateNHC(nhc_sigma)) {
        status_.nhc_updates_applied++;
        return true;
    }
    
    return false;
}

bool FusionEngine::processZUPT() {
    if (!isInitialized() || !isStationary()) {
        return false;
    }
    
    if (ekf_.updateZUPT(config_.zupt_sigma)) {
        status_.zupt_updates_applied++;
        return true;
    }
    
    return false;
}

bool FusionEngine::processMapConstraint(const MapConstraint& constraint) {
    if (!constraint.valid || !isFinite(constraint.cross_track_error_m) ||
        !isFinite(constraint.road_heading_rad)) {
        return false;
    }
    
    if (!isInitialized()) {
        return false;
    }
    
    double sigma = config_.map_cross_track_sigma;
    if (constraint.confidence > 0.0 && constraint.confidence < 1.0) {
        // Increase sigma for low confidence
        sigma /= std::max(constraint.confidence, 0.1);
    }
    
    return ekf_.updateMapCrossTrack(constraint.cross_track_error_m, constraint.road_heading_rad, sigma);
}

NavigationState FusionEngine::getState() const {
    NavigationState state;
    
    if (!isInitialized()) {
        return state;  // Returns default (zeroed) state
    }
    
    state.timestamp = ekf_.lastTimestamp();
    state.east_m = ekf_.px();
    state.north_m = ekf_.py();
    state.velocity_east_mps = ekf_.vx();
    state.velocity_north_mps = ekf_.vy();
    state.speed_mps = ekf_.speed();
    state.heading_rad = ekf_.yaw();
    
    state.position_sigma_m = ekf_.positionSigma();
    state.velocity_sigma_mps = ekf_.velocitySigma();
    state.heading_sigma_rad = ekf_.headingSigma();
    
    // Convert local ENU back to geographic coordinates
    if (local_frame_.isInitialized()) {
        auto [lat, lon] = local_frame_.localToGeo(state.east_m, state.north_m);
        state.latitude_deg = lat;
        state.longitude_deg = lon;
    }
    
    state.gnss_available = (gnss_quality_ == GNSSQuality::AVAILABLE ||
                            gnss_quality_ == GNSSQuality::DEGRADED);
    state.dead_reckoning = (mode_ == FusionMode::DEAD_RECKONING);
    
    // Log if enabled
    if (config_.enable_csv_logging) {
        const_cast<FusionEngine*>(this)->logState(state);
    }
    
    return state;
}

FusionStatus FusionEngine::getStatus() const {
    FusionStatus current_status = status_;
    current_status.mode = mode_;
    current_status.gnss_quality = gnss_quality_;
    current_status.last_gnss_timestamp = last_gnss_time_;
    current_status.gnss_outage_duration = current_time_ - last_gnss_time_;
    return current_status;
}

void FusionEngine::reset() {
    noise_model_.reset();
    mode_ = FusionMode::UNINITIALIZED;
    gnss_quality_ = GNSSQuality::LOST;
    last_gnss_time_ = 0.0;
    consecutive_gnss_rejections_ = 0;
    current_time_ = 0.0;
    
    status_ = FusionStatus();
    status_.mode = mode_;
    status_.gnss_quality = gnss_quality_;
    
    if (log_file_open_) {
        log_file_.close();
        log_file_open_ = false;
    }
}

bool FusionEngine::isInitialized() const {
    return mode_ != FusionMode::UNINITIALIZED &&
           mode_ != FusionMode::INITIALIZING &&
           ekf_.isInitialized();
}

void FusionEngine::setMLProvider(std::unique_ptr<MLProvider> provider) {
    ml_provider_ = std::move(provider);
}

void FusionEngine::updateGNSSQuality(double current_time, bool gnss_update_applied) {
    if (gnss_update_applied) {
        last_gnss_time_ = current_time;
        consecutive_gnss_rejections_ = 0;
        
        if (mode_ == FusionMode::DEAD_RECKONING) {
            mode_ = FusionMode::GNSS_REACQUIRING;
        }
        if (mode_ == FusionMode::GNSS_REACQUIRING || mode_ == FusionMode::GNSS_DEGRADED) {
            mode_ = FusionMode::GNSS_AIDED;
        }
        mode_ = FusionMode::GNSS_AIDED;
        gnss_quality_ = GNSSQuality::AVAILABLE;
    } else {
        if (last_gnss_time_ > 0.0) {
            double outage_duration = current_time - last_gnss_time_;
            if (outage_duration > config_.gnss_outage_timeout_s) {
                mode_ = FusionMode::DEAD_RECKONING;
                gnss_quality_ = GNSSQuality::LOST;
            } else if (outage_duration > config_.gnss_outage_timeout_s / 2.0) {
                mode_ = FusionMode::GNSS_DEGRADED;
                gnss_quality_ = GNSSQuality::DEGRADED;
            }
        }
    }
    
    status_.mode = mode_;
    status_.gnss_quality = gnss_quality_;
}

bool FusionEngine::isStationary() const {
    return ekf_.speed() < config_.zupt_speed_threshold;
}

void FusionEngine::openLogFile() {
    log_file_.open(config_.log_file_path);
    if (log_file_.is_open()) {
        log_file_open_ = true;
        log_file_ << "timestamp,east,north,lat,lon,vx,vy,speed,yaw,"
                  << "pos_sigma,vel_sigma,hdg_sigma,gnss_status,mode\n";
    }
}

void FusionEngine::logState(const NavigationState& state) {
    if (!log_file_open_) return;
    
    log_file_ << std::fixed << std::setprecision(6)
              << state.timestamp << ","
              << state.east_m << ","
              << state.north_m << ","
              << std::setprecision(9)
              << state.latitude_deg << ","
              << state.longitude_deg << ","
              << std::setprecision(6)
              << state.velocity_east_mps << ","
              << state.velocity_north_mps << ","
              << state.speed_mps << ","
              << state.heading_rad << ","
              << state.position_sigma_m << ","
              << state.velocity_sigma_mps << ","
              << state.heading_sigma_rad << ","
              << static_cast<int>(gnss_quality_) << ","
              << static_cast<int>(mode_) << "\n";
}

} // namespace fusion
