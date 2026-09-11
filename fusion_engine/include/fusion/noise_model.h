#pragma once
#include "fusion/types.h"

namespace fusion {

/// Manages adaptive process noise scaling based on vibration and motion information.
///
/// The vibration/motion ML model does not directly modify the EKF state.
/// Instead, it influences the process noise covariance Q through a noise scale factor.
///
/// Noise scaling levels:
///   Normal road:        scale = 1.0 (nominal Q)
///   Moderate vibration: scale = 2.0-3.0
///   Pothole:            scale = 3.0-5.0 (temporary)
///   Severe vibration:   scale = 5.0-10.0
///   Phone motion:       scale = 3.0-5.0
///
/// The scale factor is clamped to [min_noise_scale, max_noise_scale].
class NoiseModel {
public:
    NoiseModel();
    
    /// Configure noise scaling bounds
    void configure(double min_scale, double max_scale);
    
    /// Update the noise model with new vibration information
    void updateVibration(const VibrationInfo& info);
    
    /// Get the current process noise scale factor (>= 1.0)
    double getNoiseScale() const;
    
    /// Get the current recommended NHC sigma
    /// Returns a larger sigma when vibration is high or phone is moving
    double getNHCSigma(double nominal_sigma, double degraded_sigma) const;
    
    /// Reset to nominal noise levels
    void reset();
    
private:
    double current_scale_ = 1.0;
    double smoothed_noise_score_ = 0.0;
    double min_scale_ = 1.0;
    double max_scale_ = 10.0;
    bool pothole_active_ = false;
    bool severe_vibration_ = false;
    bool phone_motion_ = false;
    double last_update_time_ = 0.0;
    
    /// Exponential smoothing factor for noise score
    static constexpr double kSmoothingAlpha = 0.3;
};

} // namespace fusion
