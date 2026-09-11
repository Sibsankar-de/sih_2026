import 'dart:math' as math;
import '../../models/sensor_data.dart';
import '../../models/speed_estimate.dart';
import 'service_interfaces.dart';

class MockAIService implements IMockAIService {
  double _filteredAccel = 0.0;
  final double _filterAlpha = 0.25;
  final math.Random _random = math.Random();

  @override
  SpeedEstimate estimateSpeed(SensorSnapshot sensorSnapshot, double previousSpeed) {
    final double rawForwardAccel = sensorSnapshot.accelerometer.y;

    // Apply low-pass exponential moving average filter
    _filteredAccel = _filterAlpha * rawForwardAccel + (1 - _filterAlpha) * _filteredAccel;

    final bool isZupt = detectZeroVelocity(
      sensorSnapshot.accelerometer,
      sensorSnapshot.gyroscope,
    );

    double speedPrediction;
    double confidence;

    if (isZupt) {
      speedPrediction = 0.0;
      confidence = 0.99;
    } else {
      // Mock Deep Learning Inference (LSTM/TCN model estimating instantaneous velocity)
      // Base forward motion modulated with filtered acceleration and micro-variations
      final double accelDelta = _filteredAccel * 0.1; // dt = 0.1s
      final double rawCandidate = (previousSpeed + accelDelta).clamp(0.0, 35.0);

      // Model regularizes drift that standard double integration suffers from
      final double modelCorrection = (_random.nextDouble() - 0.5) * 0.04;
      speedPrediction = (rawCandidate + modelCorrection).clamp(0.0, 35.0);

      // Confidence depends on sensor vibration magnitude
      final double vibration = (sensorSnapshot.accelerometer.x.abs() + sensorSnapshot.gyroscope.z.abs());
      confidence = (0.96 - (vibration * 0.08)).clamp(0.70, 0.99);
    }

    return SpeedEstimate(
      timestamp: DateTime.now(),
      rawAcceleration: rawForwardAccel,
      filteredAcceleration: _filteredAccel,
      predictedSpeedMs: speedPrediction,
      confidenceScore: confidence,
      isZuptActive: isZupt,
      modelName: 'FineLine-TCN-v2 (Quantized TFLite)',
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
    // Zero Velocity Update (ZUPT) trigger
    final double accelDev = (accel.x.abs() + (accel.z - 9.806).abs());
    final double gyroMagnitude = (gyro.x * gyro.x + gyro.y * gyro.y + gyro.z * gyro.z);

    return accelDev < 0.02 && gyroMagnitude < 0.0001;
  }
}
