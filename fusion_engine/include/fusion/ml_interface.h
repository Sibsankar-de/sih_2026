#pragma once
#include "fusion/types.h"
#include <memory>

namespace fusion {

/// Abstract interface for ML velocity prediction.
/// Decouples the EKF from any specific ML inference backend (ONNX, TFLite, etc.).
class MLProvider {
public:
    virtual ~MLProvider() = default;
    
    /// Predict forward vehicle velocity from sensor data.
    virtual MLVelocityMeasurement predictVelocity(
        const IMUSample& imu,
        double current_speed_estimate
    ) = 0;
    
    /// Check if the model is loaded and ready
    virtual bool isReady() const = 0;
};

/// Mock ML provider for testing.
/// Returns configurable constant velocity predictions.
class MockMLProvider : public MLProvider {
public:
    MockMLProvider(double default_velocity = 0.0, double default_confidence = 0.8, double default_sigma = 0.5)
        : velocity_(default_velocity), confidence_(default_confidence), sigma_(default_sigma) {}
    
    MLVelocityMeasurement predictVelocity(
        const IMUSample& imu,
        double current_speed_estimate
    ) override {
        (void)current_speed_estimate;  // May be used by real implementations
        MLVelocityMeasurement m;
        m.timestamp = imu.timestamp;
        m.forward_velocity_mps = velocity_;
        m.confidence = confidence_;
        m.sigma_mps = sigma_;
        m.valid = true;
        return m;
    }
    
    bool isReady() const override { return true; }
    
    void setVelocity(double v) { velocity_ = v; }
    void setConfidence(double c) { confidence_ = c; }
    void setSigma(double s) { sigma_ = s; }
    
private:
    double velocity_;
    double confidence_;
    double sigma_;
};

} // namespace fusion
