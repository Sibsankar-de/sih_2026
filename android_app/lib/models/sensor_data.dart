class Vector3D {
  final double x;
  final double y;
  final double z;

  const Vector3D(this.x, this.y, this.z);

  double get magnitude => (x * x + y * y + z * z);

  factory Vector3D.zero() => const Vector3D(0.0, 0.0, 0.0);

  Vector3D copyWith({double? x, double? y, double? z}) {
    return Vector3D(
      x ?? this.x,
      y ?? this.y,
      z ?? this.z,
    );
  }
}

class SensorSnapshot {
  final DateTime timestamp;
  final Vector3D accelerometer; // m/s^2
  final Vector3D gyroscope;     // rad/s
  final Vector3D magnetometer;  // microTesla (uT)
  final bool isHardwareAvailable;
  final double updateFrequencyHz;

  const SensorSnapshot({
    required this.timestamp,
    required this.accelerometer,
    required this.gyroscope,
    required this.magnetometer,
    required this.isHardwareAvailable,
    required this.updateFrequencyHz,
  });

  factory SensorSnapshot.initial() {
    return SensorSnapshot(
      timestamp: DateTime.now(),
      accelerometer: const Vector3D(0.02, 0.15, 9.81),
      gyroscope: const Vector3D(0.001, -0.002, 0.004),
      magnetometer: const Vector3D(22.4, -5.1, 41.2),
      isHardwareAvailable: true,
      updateFrequencyHz: 50.0,
    );
  }
}
