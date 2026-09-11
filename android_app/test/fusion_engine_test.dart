import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:fineline_navigator/core/fusion/fusion_types.dart';
import 'package:fineline_navigator/core/fusion/ekf.dart';
import 'package:fineline_navigator/core/fusion/local_frame.dart';
import 'package:fineline_navigator/core/fusion/fusion_engine.dart';

void main() {
  group('Local Frame Tests', () {
    test('Round trip conversion preserve coordinates', () {
      final frame = LocalFrame();
      const lat0 = 52.40166;
      const lon0 = -1.50529;
      frame.setOrigin(lat0, lon0);

      // 100m East, 200m North
      final geo = frame.localToGeo(100.0, 200.0);
      final local = frame.geoToLocal(geo[0], geo[1]);

      expect(local[0], closeTo(100.0, 1e-4));
      expect(local[1], closeTo(200.0, 1e-4));
    });
  });

  group('EKF Prediction Tests', () {
    test('Straight line constant velocity', () {
      final ekf = EKF();
      final x = List<double>.filled(kStateDim, 0.0);
      x[kIdxVx] = 10.0; // 10 m/s East
      x[kIdxYaw] = 0.0; // Heading East
      ekf.initialize(x, FusionConfig());

      for (int i = 0; i <= 100; i++) {
        ekf.predict(IMUSample(timestamp: i * 0.01, accelX: 0.0, accelY: 0.0, gyroZ: 0.0));
      }

      expect(ekf.px, closeTo(10.0, 0.5));
      expect(ekf.py, closeTo(0.0, 0.5));
      expect(ekf.vx, closeTo(10.0, 0.1));
      expect(ekf.vy, closeTo(0.0, 0.1));
    });

    test('Constant acceleration in vehicle frame', () {
      final ekf = EKF();
      final x = List<double>.filled(kStateDim, 0.0);
      ekf.initialize(x, FusionConfig());

      for (int i = 0; i <= 200; i++) {
        ekf.predict(IMUSample(timestamp: i * 0.01, accelX: 1.0, accelY: 0.0, gyroZ: 0.0));
      }

      // x = 0.5 * 1.0 * 2^2 = 2.0 m
      expect(ekf.px, closeTo(2.0, 0.2));
      expect(ekf.vx, closeTo(2.0, 0.1));
    });

    test('Constant turn rate', () {
      final ekf = EKF();
      final x = List<double>.filled(kStateDim, 0.0);
      x[kIdxVx] = 10.0;
      ekf.initialize(x, FusionConfig());

      const double gyroRate = math.pi / 4.0; // 45 deg/s
      for (int i = 0; i <= 100; i++) {
        ekf.predict(IMUSample(timestamp: i * 0.01, accelX: 0.0, accelY: 0.0, gyroZ: gyroRate));
      }

      expect(ekf.yaw, closeTo(math.pi / 4.0, 0.05));
    });
  });

  group('EKF Correction Tests', () {
    test('ML velocity update pulls state velocity', () {
      final ekf = EKF();
      final x = List<double>.filled(kStateDim, 0.0);
      x[kIdxVx] = 5.0; // EKF thinks 5 m/s East
      x[kIdxYaw] = 0.0;
      ekf.initialize(x, FusionConfig());

      // ML predicts 6.8 m/s within gating bound
      final success = ekf.updateMLVelocity(const MLVelocityMeasurement(
        timestamp: 1.0,
        forwardVelocityMps: 6.8,
        confidence: 0.95,
        sigmaMps: 0.5,
      ));

      expect(success, isTrue);
      expect(ekf.vx, greaterThan(5.0));
    });

    test('Non-holonomic constraint reduces lateral velocity', () {
      final ekf = EKF();
      final x = List<double>.filled(kStateDim, 0.0);
      x[kIdxVx] = 10.0;
      x[kIdxVy] = 0.5; // Lateral slip
      x[kIdxYaw] = 0.0; // Heading East -> Vy is lateral
      ekf.initialize(x, FusionConfig());

      final success = ekf.updateNHC(0.1);
      expect(success, isTrue);
      expect(ekf.vy.abs(), lessThan(0.5));
    });

    test('Zero velocity update forces velocity to zero', () {
      final ekf = EKF();
      final x = List<double>.filled(kStateDim, 0.0);
      x[kIdxVx] = 0.3;
      x[kIdxVy] = 0.2;
      ekf.initialize(x, FusionConfig());

      final success = ekf.updateZUPT(0.01);
      expect(success, isTrue);
      expect(ekf.speed, lessThan(0.1));
    });
  });

  group('Full Fusion Engine Tests', () {
    test('Outage transitions to dead reckoning and recovers upon GNSS return', () {
      final engine = FusionEngine();
      expect(engine.isInitialized, isFalse);

      // 1. First GNSS fix initializes engine
      const initGnss = GNSSMeasurement(
        timestamp: 100.0,
        latitudeDeg: 28.6139,
        longitudeDeg: 77.2090,
        horizontalAccuracyM: 2.0,
        hasVelocity: true,
        velocityEastMps: 10.0,
        velocityNorthMps: 0.0,
        hasCourse: true,
        courseRad: 0.0,
      );

      final initialized = engine.processGNSS(initGnss);
      expect(initialized, isTrue);
      expect(engine.isInitialized, isTrue);
      expect(engine.mode, equals(FusionMode.gnssAided));
      expect(engine.gnssQuality, equals(GNSSQuality.available));

      // 2. Predict through IMU during outage (no GNSS fixes for 10 seconds)
      for (int i = 1; i <= 100; i++) {
        engine.processIMU(IMUSample(
          timestamp: 100.0 + i * 0.1,
          accelX: 0.0,
          accelY: 0.0,
          gyroZ: 0.0,
        ));
        // ML continues aiding velocity
        engine.processMLVelocity(MLVelocityMeasurement(
          timestamp: 100.0 + i * 0.1,
          forwardVelocityMps: 10.0,
          confidence: 0.92,
        ));
        engine.processNHC();
      }

      final statusOutage = engine.getStatus();
      expect(statusOutage.mode, equals(FusionMode.deadReckoning));
      expect(statusOutage.gnssQuality, equals(GNSSQuality.lost));
      expect(statusOutage.gnssOutageDuration, greaterThan(5.0));

      final stateOutage = engine.getState();
      expect(stateOutage.deadReckoning, isTrue);
      expect(stateOutage.speedMps, closeTo(10.0, 1.0));

      // 3. GNSS Reacquisition
      final recoveryGnss = GNSSMeasurement(
        timestamp: 110.1,
        latitudeDeg: stateOutage.latitudeDeg,
        longitudeDeg: stateOutage.longitudeDeg,
        horizontalAccuracyM: 2.0,
        hasVelocity: true,
        velocityEastMps: 10.0,
        velocityNorthMps: 0.0,
      );

      final recovered = engine.processGNSS(recoveryGnss);
      expect(recovered, isTrue);
      expect(engine.gnssQuality, equals(GNSSQuality.available));
    });
  });
}
