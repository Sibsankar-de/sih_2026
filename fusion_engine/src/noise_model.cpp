#include "fusion/noise_model.h"
#include <algorithm>
#include <cmath>

namespace fusion {

NoiseModel::NoiseModel() = default;

void NoiseModel::configure(double min_scale, double max_scale) {
    if (std::isfinite(min_scale) && std::isfinite(max_scale) && min_scale <= max_scale) {
        min_scale_ = min_scale;
        max_scale_ = max_scale;
    }
}

void NoiseModel::updateVibration(const VibrationInfo& info) {
    if (std::isfinite(info.noise_score)) {
        smoothed_noise_score_ = kSmoothingAlpha * info.noise_score + 
                                (1.0 - kSmoothingAlpha) * smoothed_noise_score_;
    }
    
    pothole_active_ = info.pothole_detected;
    severe_vibration_ = info.severe_vibration;
    phone_motion_ = info.phone_motion_detected;
    
    if (std::isfinite(info.timestamp)) {
        last_update_time_ = info.timestamp;
    }

    double scale = 1.0 + smoothed_noise_score_ * (max_scale_ - 1.0);
    
    if (pothole_active_) scale = std::max(scale, 3.0);
    if (severe_vibration_) scale = std::max(scale, 5.0);
    if (phone_motion_) scale = std::max(scale, 3.0);

    current_scale_ = std::clamp(scale, min_scale_, max_scale_);
}

double NoiseModel::getNoiseScale() const {
    return current_scale_;
}

double NoiseModel::getNHCSigma(double nominal_sigma, double degraded_sigma) const {
    if (phone_motion_ || severe_vibration_) {
        return degraded_sigma;
    }
    return nominal_sigma + smoothed_noise_score_ * (degraded_sigma - nominal_sigma);
}

void NoiseModel::reset() {
    current_scale_ = 1.0;
    smoothed_noise_score_ = 0.0;
    pothole_active_ = false;
    severe_vibration_ = false;
    phone_motion_ = false;
    last_update_time_ = 0.0;
}

} // namespace fusion
