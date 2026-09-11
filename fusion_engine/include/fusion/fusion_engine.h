#pragma once

#include "fusion/types.h"
#include "fusion/ekf.h"
#include "fusion/local_frame.h"
#include "fusion/noise_model.h"
#include "fusion/ml_interface.h"

#include <memory>
#include <fstream>
#include <string>

namespace fusion {

/// Top-level fusion engine orchestrating EKF, coordinate conversion, GNSS management,
/// adaptive noise, and sensor processing.
///
/// Processing model:
///   IMU  → EKF prediction
///   GNSS → EKF correction (position, velocity, course)
///   ML   → EKF correction (forward velocity pseudo-measurement)
///   NHC  → EKF correction (lateral velocity ≈ 0)
///   ZUPT → EKF correction (velocity ≈ 0 when stationary)
///   Map  → EKF correction (cross-track constraint)
///   Vibration → adaptive noise scaling
///
/// The engine manages initialization, GNSS quality tracking, and state output.
class FusionEngine {
public:
    FusionEngine();
    ~FusionEngine();
    
    /// Initialize the fusion engine with configuration
    /// @return true if configuration is valid
    bool initialize(const FusionConfig& config);
    
    /// Process an IMU sample (prediction step)
    bool processIMU(const IMUSample& sample);
    
    /// Process a GNSS measurement (correction step)
    bool processGNSS(const GNSSMeasurement& measurement);
    
    /// Process an ML velocity measurement (correction step)
    bool processMLVelocity(const MLVelocityMeasurement& measurement);
    
    /// Process vibration information (adaptive noise)
    bool processVibration(const VibrationInfo& vibration);
    
    /// Apply non-holonomic constraint
    bool processNHC();
    
    /// Apply zero velocity update (if stationary conditions met)
    bool processZUPT();
    
    /// Process a map constraint
    bool processMapConstraint(const MapConstraint& constraint);
    
    /// Get the current navigation state (converts ENU to lat/lon)
    NavigationState getState() const;
    
    /// Get the current fusion status
    FusionStatus getStatus() const;
    
    /// Reset the engine to uninitialized state
    void reset();
    
    /// Check if the engine is initialized and running
    bool isInitialized() const;
    
    /// Set the ML provider (takes ownership)
    void setMLProvider(std::unique_ptr<MLProvider> provider);
    
    /// Get read-only access to the EKF for testing
    const EKF& ekf() const { return ekf_; }
    
    /// Get the local frame for testing
    const LocalFrame& localFrame() const { return local_frame_; }
    
private:
    /// Try to initialize from a GNSS measurement
    bool tryInitialize(const GNSSMeasurement& gnss);
    
    /// Update GNSS quality state machine
    void updateGNSSQuality(double current_time, bool gnss_update_applied);
    
    /// Check if vehicle is stationary
    bool isStationary() const;
    
    /// Log current state to CSV
    void logState(const NavigationState& state);
    
    /// Open the CSV log file and write header
    void openLogFile();
    
    // Core components
    EKF ekf_;
    LocalFrame local_frame_;
    NoiseModel noise_model_;
    std::unique_ptr<MLProvider> ml_provider_;
    FusionConfig config_;
    
    // State tracking
    FusionMode mode_ = FusionMode::UNINITIALIZED;
    GNSSQuality gnss_quality_ = GNSSQuality::LOST;
    FusionStatus status_;
    
    // GNSS quality tracking
    double last_gnss_time_ = 0.0;
    int consecutive_gnss_rejections_ = 0;
    
    // Timing
    double current_time_ = 0.0;
    
    // Logging
    std::ofstream log_file_;
    bool log_file_open_ = false;
};

} // namespace fusion
