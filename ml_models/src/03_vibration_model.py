#!/usr/bin/env python3
"""Vibration and road-noise classification model training, signal-derived labeling, and TFLite export."""

import os
import sys
import json
import time
import warnings
import numpy as np
import pandas as pd
from pathlib import Path
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common_utils import *

warnings.filterwarnings('ignore')

CONFIG = {
    'model_name': 'vibration_classifier',
    'version': '1.0.0',
    'target_sampling_rate_hz': 10,
    'window_duration_s': 1.0,
    'window_stride_s': 0.5,
    'feature_cols': ['acc_x', 'acc_y', 'acc_z', 'gyro_yaw', 'gyro_pitch', 'gyro_roll'],
    'random_seed': RANDOM_SEED,
    'batch_size': 128,
    'epochs': 40,
    'patience': 10,
    'learning_rate': 0.001,
    'vibration_classes': {0: 'smooth', 1: 'moderate', 2: 'high_vibration'},
    'smooth_rms_threshold': 1.5,
    'moderate_rms_threshold': 3.0,
    'shock_jerk_threshold': 15.0
}

WINDOW_SIZE = int(CONFIG['window_duration_s'] * CONFIG['target_sampling_rate_hz'])
WINDOW_STRIDE = int(CONFIG['window_stride_s'] * CONFIG['target_sampling_rate_hz'])
N_FEATURES = len(CONFIG['feature_cols'])
N_CLASSES = len(CONFIG['vibration_classes'])

# Load inspected sequences
usable_path = ARTIFACTS_DIR / "configs" / "usable_sequences.json"
with open(usable_path) as f:
    usable_pairs = json.load(f)

processed_sequences = []
for pair in usable_pairs:
    s_df = load_s_file(pair['s_file'])
    if s_df is None or not all(c in s_df.columns for c in CONFIG['feature_cols']):
        continue
    s_df = remove_gravity(s_df)
    s_df = compute_derived_features(s_df)
    s_df = handle_missing_values(s_df, strategy='interpolate')
    s_df = s_df.dropna(subset=CONFIG['feature_cols'])
    if len(s_df) < WINDOW_SIZE * 2:
        continue
    processed_sequences.append(s_df)

# Create labeled windows
all_windows = []
all_labels = []
window_seq_ids = []

for idx, s_df in enumerate(processed_sequences):
    imu_arr = s_df[CONFIG['feature_cols']].values
    if 'linear_acc_mag' in s_df.columns:
        lin_acc_arr = s_df['linear_acc_mag'].values
    else:
        acc_vals = s_df[['acc_x', 'acc_y', 'acc_z']].values
        lin_acc_arr = np.sqrt(np.sum(acc_vals**2, axis=1)) - 9.81

    n_samples = len(imu_arr)
    n_windows = (n_samples - WINDOW_SIZE) // WINDOW_STRIDE
    if n_windows <= 0:
        continue

    for w in range(n_windows):
        start = w * WINDOW_STRIDE
        end = start + WINDOW_SIZE
        imu_window = imu_arr[start:end]
        lin_acc = lin_acc_arr[start:end]

        rms_accel = np.sqrt(np.mean(lin_acc**2))
        jerk = np.diff(lin_acc)
        peak_jerk = np.max(np.abs(jerk)) if len(jerk) > 0 else 0

        # Proxy labeling based on jerk and linear acceleration RMS
        if peak_jerk > CONFIG['shock_jerk_threshold'] or rms_accel > CONFIG['moderate_rms_threshold']:
            label = 2
        elif rms_accel > CONFIG['smooth_rms_threshold']:
            label = 1
        else:
            label = 0

        all_windows.append(imu_window)
        all_labels.append(label)
        window_seq_ids.append(idx)

X_all = np.array(all_windows)
y_all = np.array(all_labels)
seq_idx_all = np.array(window_seq_ids)

# Sequence-based train/val/test split
unique_seqs = list(range(len(processed_sequences)))
train_seqs, val_seqs, test_seqs = split_sequences_by_index(unique_seqs, 0.70, 0.15, 0.15, CONFIG['random_seed'])

train_mask = np.isin(seq_idx_all, train_seqs)
val_mask = np.isin(seq_idx_all, val_seqs)
test_mask = np.isin(seq_idx_all, test_seqs)

X_train, y_train = X_all[train_mask], y_all[train_mask]
X_val, y_val = X_all[val_mask], y_all[val_mask]
X_test, y_test = X_all[test_mask], y_all[test_mask]

# Normalization
from sklearn.preprocessing import StandardScaler
import joblib

scaler = StandardScaler()
scaler.fit(X_train.reshape(-1, N_FEATURES))

X_train_s = scaler.transform(X_train.reshape(-1, N_FEATURES)).reshape(-1, WINDOW_SIZE, N_FEATURES)
X_val_s = scaler.transform(X_val.reshape(-1, N_FEATURES)).reshape(-1, WINDOW_SIZE, N_FEATURES)
X_test_s = scaler.transform(X_test.reshape(-1, N_FEATURES)).reshape(-1, WINDOW_SIZE, N_FEATURES)

(ARTIFACTS_DIR / "scalers").mkdir(parents=True, exist_ok=True)
joblib.dump(scaler, ARTIFACTS_DIR / "scalers" / "vibration_scaler.joblib")

# Baselines
def extract_vibration_features(X):
    n, ws, nf = X.shape
    feat_list = []
    for j in range(nf):
        col = X[:, :, j]
        feat_list.append(np.mean(col, axis=1))
        feat_list.append(np.std(col, axis=1))
        feat_list.append(np.min(col, axis=1))
        feat_list.append(np.max(col, axis=1))
        feat_list.append(np.sqrt(np.mean(col**2, axis=1)))
        feat_list.append(np.max(np.abs(np.diff(col, axis=1)), axis=1))
    acc_mag = np.sqrt(X[:, :, 0]**2 + X[:, :, 1]**2 + X[:, :, 2]**2)
    gyro_mag = np.sqrt(X[:, :, 3]**2 + X[:, :, 4]**2 + X[:, :, 5]**2)
    feat_list.extend([np.mean(acc_mag, axis=1), np.std(acc_mag, axis=1), np.mean(gyro_mag, axis=1), np.std(gyro_mag, axis=1)])
    return np.column_stack(feat_list)

X_train_feat = extract_vibration_features(X_train_s)
X_test_feat = extract_vibration_features(X_test_s)

# Rule-based thresholding baseline
rule_pred = np.zeros(len(X_test), dtype=int)
for i in range(len(X_test)):
    w = X_test[i]
    acc_mag = np.sqrt(w[:, 0]**2 + w[:, 1]**2 + w[:, 2]**2)
    rms = np.sqrt(np.mean((acc_mag - 9.81)**2))
    if rms > CONFIG['moderate_rms_threshold']:
        rule_pred[i] = 2
    elif rms > CONFIG['smooth_rms_threshold']:
        rule_pred[i] = 1

rule_metrics = compute_classification_metrics(y_test, rule_pred, list(CONFIG['vibration_classes'].values()))

from sklearn.ensemble import RandomForestClassifier

rf = RandomForestClassifier(n_estimators=50, max_depth=12, random_state=CONFIG['random_seed'], n_jobs=-1)
rf_subsample = min(30000, len(X_train_feat))
rf.fit(X_train_feat[:rf_subsample], y_train[:rf_subsample])
rf_pred = rf.predict(X_test_feat)
rf_metrics = compute_classification_metrics(y_test, rf_pred, list(CONFIG['vibration_classes'].values()))

(MODELS_DIR / "vibration").mkdir(parents=True, exist_ok=True)
joblib.dump(rf, MODELS_DIR / "vibration" / "vibration_rf_baseline.joblib")

# 1D-CNN Model
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

tf.random.set_seed(CONFIG['random_seed'])

inputs = keras.Input(shape=(WINDOW_SIZE, N_FEATURES), name='imu_input')
x = layers.Conv1D(32, 3, padding='same', activation='relu')(inputs)
x = layers.BatchNormalization()(x)
x = layers.Conv1D(64, 3, padding='same', activation='relu')(x)
x = layers.BatchNormalization()(x)
x = layers.GlobalAveragePooling1D()(x)
x = layers.Dense(32, activation='relu')(x)
x = layers.Dropout(0.3)(x)
output = layers.Dense(N_CLASSES, activation='softmax', name='vibration_output')(x)
model = keras.Model(inputs, output, name='vibration_cnn')

model.compile(optimizer=keras.optimizers.Adam(learning_rate=CONFIG['learning_rate']), loss='sparse_categorical_crossentropy', metrics=['accuracy'])

from sklearn.utils.class_weight import compute_class_weight
class_weights_arr = compute_class_weight('balanced', classes=np.unique(y_train), y=y_train)
class_weight_dict = dict(zip(np.unique(y_train), class_weights_arr))

callbacks = [
    keras.callbacks.EarlyStopping(monitor='val_loss', patience=CONFIG['patience'], restore_best_weights=True),
    keras.callbacks.ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=5, min_lr=1e-6),
    keras.callbacks.ModelCheckpoint(str(MODELS_DIR / "vibration" / "vibration_cnn_best.keras"), monitor='val_loss', save_best_only=True)
]

checkpoint_path = MODELS_DIR / "vibration" / "vibration_cnn.keras"
if checkpoint_path.exists():
    print("Loading existing trained vibration model...")
    model = keras.models.load_model(checkpoint_path)
    train_time = 0.0
else:
    print("Training 1D-CNN vibration model...")
    t0 = time.time()
    history = model.fit(
        X_train_s, y_train,
        validation_data=(X_val_s, y_val),
        epochs=CONFIG['epochs'],
        batch_size=CONFIG['batch_size'],
        class_weight=class_weight_dict,
        callbacks=callbacks,
        verbose=1
    )
    train_time = time.time() - t0
    model.save(checkpoint_path)

nn_probs = model.predict(X_test_s, verbose=0)
nn_pred = np.argmax(nn_probs, axis=1)
nn_metrics = compute_classification_metrics(y_test, nn_pred, list(CONFIG['vibration_classes'].values()))

print(f"Test Accuracy: {nn_metrics['accuracy']:.4f}")
print(f"Test F1:       {nn_metrics['f1']:.4f}")

# TFLite export
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()
tflite_path = MODELS_DIR / "vibration" / "vibration_cnn.tflite"
with open(tflite_path, 'wb') as f:
    f.write(tflite_model)

# Latency benchmark
interp = tf.lite.Interpreter(model_path=str(tflite_path))
interp.allocate_tensors()
in_idx = interp.get_input_details()[0]['index']
out_idx = interp.get_output_details()[0]['index']

sample = X_test_s[0:1].astype(np.float32)
latencies = []
for _ in range(100):
    t0 = time.perf_counter()
    interp.set_tensor(in_idx, sample)
    interp.invoke()
    _ = interp.get_tensor(out_idx)
    latencies.append((time.perf_counter() - t0) * 1000)
avg_latency_ms = float(np.mean(latencies))

metadata = {
    'model_name': CONFIG['model_name'],
    'version': CONFIG['version'],
    'timestamp': datetime.now().isoformat(),
    'task': 'classification',
    'input_features': CONFIG['feature_cols'],
    'input_shape': [WINDOW_SIZE, N_FEATURES],
    'sampling_rate_hz': CONFIG['target_sampling_rate_hz'],
    'window_length_s': CONFIG['window_duration_s'],
    'window_stride_s': CONFIG['window_stride_s'],
    'n_classes': N_CLASSES,
    'class_mapping': CONFIG['vibration_classes'],
    'normalization': 'StandardScaler',
    'model_architecture': '1D-CNN (Conv1D x2 -> GAP -> Dense -> Softmax)',
    'n_parameters': model.count_params(),
    'model_size_kb': os.path.getsize(tflite_path) / 1024,
    'metrics': {
        'cnn': nn_metrics,
        'random_forest': rf_metrics,
        'rule_based': rule_metrics
    },
    'inference_time_ms': avg_latency_ms,
    'export_format': 'TFLite'
}

save_model_metadata(metadata, ARTIFACTS_DIR / "configs" / "vibration_model_metadata.json")
print("Vibration classification pipeline completed.")
