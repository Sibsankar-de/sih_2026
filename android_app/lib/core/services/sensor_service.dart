import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';
import '../../models/sensor_data.dart';
import 'service_interfaces.dart';

class SensorService implements ISensorService {
  final StreamController<SensorSnapshot> _streamController = StreamController<SensorSnapshot>.broadcast();
  Timer? _simTimer;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  Vector3D _latestAccel = const Vector3D(0.0, 0.0, 9.81);
  Vector3D _latestGyro = Vector3D.zero();
  Vector3D _latestMag = const Vector3D(20.0, -5.0, 40.0);

  bool _hardwareAvailable = false;
  DateTime _lastHardwareTimestamp = DateTime.now();
  final math.Random _random = math.Random();
  double _simPhase = 0.0;

  SensorSnapshot _currentSnapshot = SensorSnapshot.initial();

  @override
  Stream<SensorSnapshot> get sensorStream => _streamController.stream;

  @override
  SensorSnapshot get currentSnapshot => _currentSnapshot;

  @override
  bool get isHardwareAvailable => _hardwareAvailable;

  SensorService() {
    _initHardwareSensors();
    start();
  }

  void _initHardwareSensors() {
    try {
      _accelSub = userAccelerometerEventStream().listen(
        (UserAccelerometerEvent event) {
          _hardwareAvailable = true;
          _lastHardwareTimestamp = DateTime.now();
          _latestAccel = Vector3D(event.x, event.y, event.z + 9.806);
        },
        onError: (_) {
          _hardwareAvailable = false;
        },
      );

      _gyroSub = gyroscopeEventStream().listen(
        (GyroscopeEvent event) {
          _latestGyro = Vector3D(event.x, event.y, event.z);
        },
        onError: (_) {},
      );

      _magSub = magnetometerEventStream().listen(
        (MagnetometerEvent event) {
          _latestMag = Vector3D(event.x, event.y, event.z);
        },
        onError: (_) {},
      );
    } catch (_) {
      _hardwareAvailable = false;
    }
  }

  @override
  void start() {
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final now = DateTime.now();

      // Check if real hardware event arrived in the last 500ms
      final bool receivesHardware = _hardwareAvailable &&
          now.difference(_lastHardwareTimestamp).inMilliseconds < 500;

      if (!receivesHardware) {
        // Generate realistic IMU synthetic physics data
        _simPhase += 0.05;
        final double accelNoiseX = (_random.nextDouble() - 0.5) * 0.08;
        final double accelNoiseY = (_random.nextDouble() - 0.5) * 0.12;
        final double accelNoiseZ = (_random.nextDouble() - 0.5) * 0.05;

        final double forwardAccel = 0.25 * math.sin(_simPhase * 0.8) + accelNoiseY;
        final double lateralAccel = 0.15 * math.cos(_simPhase * 0.4) + accelNoiseX;
        final double verticalAccel = 9.806 + accelNoiseZ;

        final double gyroYaw = 0.03 * math.sin(_simPhase * 0.5) + (_random.nextDouble() - 0.5) * 0.01;
        final double gyroPitch = 0.01 * math.cos(_simPhase * 0.8) + (_random.nextDouble() - 0.5) * 0.005;
        final double gyroRoll = 0.01 * math.sin(_simPhase * 0.3) + (_random.nextDouble() - 0.5) * 0.005;

        _latestAccel = Vector3D(lateralAccel, forwardAccel, verticalAccel);
        _latestGyro = Vector3D(gyroRoll, gyroPitch, gyroYaw);
        _latestMag = Vector3D(
          22.0 + 3.0 * math.cos(_simPhase * 0.2),
          -6.0 + 2.0 * math.sin(_simPhase * 0.2),
          42.0,
        );
      }

      _currentSnapshot = SensorSnapshot(
        timestamp: now,
        accelerometer: _latestAccel,
        gyroscope: _latestGyro,
        magnetometer: _latestMag,
        isHardwareAvailable: receivesHardware,
        updateFrequencyHz: 20.0,
      );

      if (!_streamController.isClosed) {
        _streamController.add(_currentSnapshot);
      }
    });
  }

  @override
  void stop() {
    _simTimer?.cancel();
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();
    _streamController.close();
  }
}
