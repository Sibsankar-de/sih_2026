class SpeedEstimate {
  final DateTime timestamp;
  final double rawAcceleration;      // m/s^2 forward axis
  final double filteredAcceleration; // filtered forward acceleration
  final double predictedSpeedMs;     // estimated instantaneous speed (m/s)
  final double predictedSpeedKmh;    // estimated instantaneous speed (km/h)
  final double confidenceScore;      // 0.0 to 1.0
  final bool isZuptActive;           // Zero Velocity Update trigger
  final String modelName;

  // Multi-model outputs
  final String vibrationClass;        // 'smooth', 'moderate', 'high_vibration'
  final double vibrationNoiseScore;   // 0.0 to 1.0
  final List<double> vibrationProbabilities;
  final String motionState;           // 'stationary', 'moving_straight', 'turning_left', 'turning_right', 'accelerating', 'braking'
  final int motionStateIndex;
  final List<double> motionProbabilities;

  const SpeedEstimate({
    required this.timestamp,
    required this.rawAcceleration,
    required this.filteredAcceleration,
    required this.predictedSpeedMs,
    double? predictedSpeedKmh,
    required this.confidenceScore,
    required this.isZuptActive,
    this.modelName = 'FineLine CNN-GRU + 1D-CNN (Edge TFLite)',
    this.vibrationClass = 'smooth',
    this.vibrationNoiseScore = 0.05,
    this.vibrationProbabilities = const [0.92, 0.07, 0.01],
    this.motionState = 'moving_straight',
    this.motionStateIndex = 1,
    this.motionProbabilities = const [0.02, 0.85, 0.04, 0.04, 0.03, 0.02],
  }) : predictedSpeedKmh = predictedSpeedKmh ?? (predictedSpeedMs * 3.6);

  factory SpeedEstimate.initial() {
    return SpeedEstimate(
      timestamp: DateTime.now(),
      rawAcceleration: 0.12,
      filteredAcceleration: 0.10,
      predictedSpeedMs: 11.2,
      predictedSpeedKmh: 40.32,
      confidenceScore: 0.94,
      isZuptActive: false,
      modelName: 'FineLine CNN-GRU + 1D-CNN (Edge TFLite)',
      vibrationClass: 'smooth',
      vibrationNoiseScore: 0.05,
      vibrationProbabilities: const [0.92, 0.07, 0.01],
      motionState: 'moving_straight',
      motionStateIndex: 1,
      motionProbabilities: const [0.02, 0.85, 0.04, 0.04, 0.03, 0.02],
    );
  }
}
