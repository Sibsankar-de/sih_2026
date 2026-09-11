class SpeedEstimate {
  final DateTime timestamp;
  final double rawAcceleration;      // m/s^2 forward axis
  final double filteredAcceleration; // filtered forward acceleration
  final double predictedSpeedMs;     // estimated instantaneous speed
  final double confidenceScore;      // 0.0 to 1.0 (LSTM model certainty)
  final bool isZuptActive;           // Zero Velocity Update trigger
  final String modelName;

  const SpeedEstimate({
    required this.timestamp,
    required this.rawAcceleration,
    required this.filteredAcceleration,
    required this.predictedSpeedMs,
    required this.confidenceScore,
    required this.isZuptActive,
    this.modelName = 'FineLine-TCN-v2 (Quantized TFLite)',
  });

  factory SpeedEstimate.initial() {
    return SpeedEstimate(
      timestamp: DateTime.now(),
      rawAcceleration: 0.12,
      filteredAcceleration: 0.10,
      predictedSpeedMs: 12.5,
      confidenceScore: 0.94,
      isZuptActive: false,
    );
  }
}
