import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fineline_navigator/core/ai/ai_inference_engine.dart';

void main() {
  test('AI Inference Engine matches TensorFlow/Keras outputs', () {
    final weightsFile = File('assets/models/ai_models_weights.json');
    expect(weightsFile.existsSync(), isTrue);

    final jsonStr = weightsFile.readAsStringSync();
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final verif = data['verification'] as Map<String, dynamic>;

    final rawInput = (verif['raw_input_10x6'] as List)
        .map((r) => (r as List).map((v) => (v as num).toDouble()).toList())
        .toList();

    final expectedVelocity = (verif['expected_velocity'] as num).toDouble();
    final expectedVibration = (verif['expected_vibration_probs'] as List)
        .map((v) => (v as num).toDouble())
        .toList();
    final expectedMotion = (verif['expected_motion_probs'] as List)
        .map((v) => (v as num).toDouble())
        .toList();

    final engine = AIInferenceEngine();
    engine.loadFromJsonString(jsonStr);
    expect(engine.isLoaded, isTrue);

    // Feed the 10 samples
    late AIInferenceResult result;
    for (int i = 0; i < rawInput.length; i++) {
      final s = rawInput[i];
      result = engine.processSample(
        accX: s[0],
        accY: s[1],
        accZ: s[2],
        gyroYaw: s[3],
        gyroPitch: s[4],
        gyroRoll: s[5],
      );
    }

    // ignore: avoid_print
    print('Predicted speed: ${result.predictedSpeedMs}, Expected: $expectedVelocity');
    // ignore: avoid_print
    print('Vibration probs: ${result.vibrationProbabilities}, Expected: $expectedVibration');
    // ignore: avoid_print
    print('Motion probs: ${result.motionProbabilities}, Expected: $expectedMotion');

    expect(result.predictedSpeedMs, closeTo(expectedVelocity, 1e-3));
    for (int i = 0; i < expectedVibration.length; i++) {
      expect(result.vibrationProbabilities[i], closeTo(expectedVibration[i], 1e-3));
    }
    for (int i = 0; i < expectedMotion.length; i++) {
      expect(result.motionProbabilities[i], closeTo(expectedMotion[i], 1e-3));
    }
  });
}
