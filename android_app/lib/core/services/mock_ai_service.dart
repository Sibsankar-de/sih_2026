import 'dart:math' as math;
import '../../models/sensor_data.dart';
import '../../models/speed_estimate.dart';
import '../ai/ai_inference_engine.dart';
import 'service_interfaces.dart';

/// Real Edge AI Service executing CNN-GRU Velocity Estimator,
/// 1D-CNN Vibration Classifier, and Motion State Classifier.
class MockAIService implements IMockAIService {
  final AIInferenceEngine _inferenceEngine = AIInferenceEngine();

  @override
  AIInferenceEngine get inferenceEngine => _inferenceEngine;

  MockAIService() {
    _inferenceEngine.loadModels();
  }

  @override
  SpeedEstimate estimateSpeed(SensorSnapshot sensorSnapshot, double previousSpeed) {
    // Forward IMU sample into the 10-step neural inference window
    final result = _inferenceEngine.processSample(
      accX: sensorSnapshot.accelerometer.x,
      accY: sensorSnapshot.accelerometer.y,
      accZ: sensorSnapshot.accelerometer.z,
      gyroYaw: sensorSnapshot.gyroscope.z,
      gyroPitch: sensorSnapshot.gyroscope.y,
      gyroRoll: sensorSnapshot.gyroscope.x,
      previousSpeedMs: previousSpeed,
    );

    return SpeedEstimate(
      timestamp: result.timestamp,
      rawAcceleration: result.rawForwardAccel,
      filteredAcceleration: result.filteredForwardAccel,
      predictedSpeedMs: result.predictedSpeedMs,
      predictedSpeedKmh: result.predictedSpeedKmh,
      confidenceScore: result.speedConfidence,
      isZuptActive: result.isZuptDetected,
      modelName: 'FineLine CNN-GRU + 1D-CNN (Edge TFLite)',
      vibrationClass: result.vibrationClass,
      vibrationNoiseScore: result.vibrationNoiseScore,
      vibrationProbabilities: result.vibrationProbabilities,
      motionState: result.motionState,
      motionStateIndex: result.motionStateIndex,
      motionProbabilities: result.motionProbabilities,
    );
  }

  @override
  double estimateHeadingCorrection(Vector3D gyro, double currentHeading, double dt) {
    // Gyro yaw rate integration: yaw in rad/s -> degrees
    final double deltaDeg = (gyro.z * 180.0 / math.pi) * dt;
    final double newHeading = (currentHeading + deltaDeg) % 360.0;
    return newHeading < 0 ? newHeading + 360.0 : newHeading;
  }

  @override
  bool detectZeroVelocity(Vector3D accel, Vector3D gyro) {
    return _inferenceEngine.latestResult.isZuptDetected;
  }
}
