import 'fusion_types.dart';

/// Adaptive process noise and NHC constraint scaling based on vehicle vibration.
class NoiseModel {
  double _minNoiseScale = 1.0;
  double _maxNoiseScale = 10.0;
  double _currentNoiseScale = 1.0;
  double _vibrationScore = 0.0;
  bool _severeVibration = false;

  double get noiseScale => _currentNoiseScale;
  double get vibrationScore => _vibrationScore;
  bool get severeVibration => _severeVibration;

  void configure(double minScale, double maxScale) {
    _minNoiseScale = minScale;
    _maxNoiseScale = maxScale;
    _currentNoiseScale = minScale;
  }

  void updateVibration(VibrationInfo vibration) {
    _vibrationScore = vibration.noiseScore.clamp(0.0, 1.0);
    _severeVibration = vibration.severeVibration;

    // Linear mapping from vibration [0, 1] to scale [minScale, maxScale]
    double targetScale = _minNoiseScale + _vibrationScore * (_maxNoiseScale - _minNoiseScale);

    if (_severeVibration) {
      targetScale = _maxNoiseScale;
    }

    // Exponential smoothing for noise scale updates
    _currentNoiseScale = 0.7 * _currentNoiseScale + 0.3 * targetScale;
    _currentNoiseScale = _currentNoiseScale.clamp(_minNoiseScale, _maxNoiseScale);
  }

  /// Get NHC lateral constraint sigma (relaxed during high vibration)
  double getNHCSigma(double nominalSigma, double degradedSigma) {
    if (_severeVibration || _vibrationScore > 0.7) {
      return degradedSigma;
    }
    return nominalSigma + _vibrationScore * (degradedSigma - nominalSigma);
  }

  void reset() {
    _currentNoiseScale = _minNoiseScale;
    _vibrationScore = 0.0;
    _severeVibration = false;
  }
}
