#!/usr/bin/env python3
"""Streaming dead reckoning inference pipeline: raw IMU window -> preprocessing -> models -> predictions."""

import os
import sys
import time
import json
import numpy as np
from pathlib import Path
import tensorflow as tf
import joblib

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MODELS_DIR = PROJECT_ROOT / "models"
ARTIFACTS_DIR = PROJECT_ROOT / "artifacts"


class DeadReckoningInference:
    """Real-time streaming inference engine executing all three dead reckoning models."""

    def __init__(self, models_dir=MODELS_DIR, artifacts_dir=ARTIFACTS_DIR):
        self.models_dir = Path(models_dir)
        self.artifacts_dir = Path(artifacts_dir)
        self.window_size = 10
        self.stride = 5
        self.n_features = 6
        self.buffer = []
        self.sample_count = 0
        self._load_models()

    def _load_models(self):
        # Velocity model
        vel_path = self.models_dir / "velocity" / "velocity_cnn_gru.tflite"
        self.vel_interp = tf.lite.Interpreter(model_path=str(vel_path))
        self.vel_interp.allocate_tensors()
        self.vel_scaler = joblib.load(self.artifacts_dir / "scalers" / "velocity_scaler.joblib")

        # Vibration model
        vib_path = self.models_dir / "vibration" / "vibration_cnn.tflite"
        self.vib_interp = tf.lite.Interpreter(model_path=str(vib_path))
        self.vib_interp.allocate_tensors()
        self.vib_scaler = joblib.load(self.artifacts_dir / "scalers" / "vibration_scaler.joblib")
        self.vib_classes = {0: 'smooth', 1: 'moderate', 2: 'high_vibration'}

        # Motion model
        mot_path = self.models_dir / "motion" / "motion_cnn_gru.tflite"
        self.mot_interp = tf.lite.Interpreter(model_path=str(mot_path))
        self.mot_interp.allocate_tensors()
        self.mot_scaler = joblib.load(self.artifacts_dir / "scalers" / "motion_scaler.joblib")
        self.mot_classes = {
            0: 'stationary', 1: 'moving_straight', 2: 'turning_left',
            3: 'turning_right', 4: 'accelerating', 5: 'braking'
        }

    def process_sample(self, acc_x, acc_y, acc_z, gyro_yaw, gyro_pitch, gyro_roll):
        """Append sample to rolling buffer and trigger windowed inference when buffer fills."""
        self.buffer.append([acc_x, acc_y, acc_z, gyro_yaw, gyro_pitch, gyro_roll])
        self.sample_count += 1

        if len(self.buffer) >= self.window_size:
            window = np.array(self.buffer[-self.window_size:])
            self.buffer = self.buffer[self.stride:]

            # Velocity prediction
            w_vel = self.vel_scaler.transform(window).astype(np.float32).reshape(1, self.window_size, self.n_features)
            self.vel_interp.set_tensor(self.vel_interp.get_input_details()[0]['index'], w_vel)
            self.vel_interp.invoke()
            vel_ms = max(0.0, float(self.vel_interp.get_tensor(self.vel_interp.get_output_details()[0]['index'])[0][0]))

            # Vibration prediction
            w_vib = self.vib_scaler.transform(window).astype(np.float32).reshape(1, self.window_size, self.n_features)
            self.vib_interp.set_tensor(self.vib_interp.get_input_details()[0]['index'], w_vib)
            self.vib_interp.invoke()
            vib_probs = self.vib_interp.get_tensor(self.vib_interp.get_output_details()[0]['index'])[0]
            vib_idx = int(np.argmax(vib_probs))

            # Motion state prediction
            w_mot = self.mot_scaler.transform(window).astype(np.float32).reshape(1, self.window_size, self.n_features)
            self.mot_interp.set_tensor(self.mot_interp.get_input_details()[0]['index'], w_mot)
            self.mot_interp.invoke()
            mot_probs = self.mot_interp.get_tensor(self.mot_interp.get_output_details()[0]['index'])[0]
            mot_idx = int(np.argmax(mot_probs))

            return {
                'timestamp_sample': self.sample_count,
                'velocity_ms': vel_ms,
                'velocity_kmh': vel_ms * 3.6,
                'vibration_class': self.vib_classes[vib_idx],
                'vibration_confidence': float(vib_probs[vib_idx]),
                'motion_state': self.mot_classes[mot_idx],
                'motion_confidence': float(mot_probs[mot_idx])
            }
        return None


if __name__ == '__main__':
    engine = DeadReckoningInference()
    print("Inference engine initialized. Simulating 30 streaming samples at 10 Hz...")

    for i in range(30):
        # Simulated raw IMU reading
        out = engine.process_sample(0.1, -0.2, 9.81, 0.01, -0.01, 0.00)
        if out:
            print(f"Sample {out['timestamp_sample']}: Speed={out['velocity_kmh']:.1f} km/h, "
                  f"Vib={out['vibration_class']} ({out['vibration_confidence']:.2f}), "
                  f"Motion={out['motion_state']} ({out['motion_confidence']:.2f})")
