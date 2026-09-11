#!/usr/bin/env python3
"""Vehicle forward velocity estimation model training, baseline benchmarking, and TFLite export."""

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
    'model_name': 'velocity_estimator',
    'version': '1.0.0',
    'target_sampling_rate_hz': 10,
    'window_duration_s': 1.0,
    'window_stride_s': 0.5,
    'feature_cols': ['acc_x', 'acc_y', 'acc_z', 'gyro_yaw', 'gyro_pitch', 'gyro_roll'],
    'random_seed': RANDOM_SEED,
    'batch_size': 128,
    'epochs': 40,
    'patience': 10,
    'learning_rate': 0.001
}

WINDOW_SIZE = int(CONFIG['window_duration_s'] * CONFIG['target_sampling_rate_hz'])
WINDOW_STRIDE = int(CONFIG['window_stride_s'] * CONFIG['target_sampling_rate_hz'])
N_FEATURES = len(CONFIG['feature_cols'])

# Load inspected sequences
usable_path = ARTIFACTS_DIR / "configs" / "usable_sequences.json"
with open(usable_path) as f:
    usable_pairs = json.load(f)

processed_sequences = []
sequence_info = []

for pair in usable_pairs:
    seq_id = pair['seq_id']
    s_df = load_s_file(pair['s_file'])
    v_df = load_v_file(pair['v_file'])

    if s_df is None or v_df is None:
        continue
    if not all(c in s_df.columns for c in CONFIG['feature_cols']):
        continue

    min_len = min(len(s_df), len(v_df))
    s_df = s_df.iloc[:min_len].copy()
    v_df = v_df.iloc[:min_len].copy()

    # Ground truth velocity from vehicle CAN-bus (km/h -> m/s)
    if 'velocity_kmh' in v_df.columns:
        s_df['velocity_ms'] = v_df['velocity_kmh'].values / 3.6
    else:
        continue

    s_df = remove_gravity(s_df)
    s_df = compute_derived_features(s_df)
    s_df = handle_missing_values(s_df, strategy='interpolate')
    s_df = s_df.dropna(subset=CONFIG['feature_cols'] + ['velocity_ms'])

    # Resample to 10 Hz if needed
    fs = compute_sampling_rate(s_df, 'time_since_start_ms', 'ms')
    if fs and abs(fs - CONFIG['target_sampling_rate_hz']) > 1:
        ratio = CONFIG['target_sampling_rate_hz'] / fs
        n_target = int(len(s_df) * ratio)
        if n_target > WINDOW_SIZE:
            indices = np.linspace(0, len(s_df) - 1, n_target).astype(int)
            s_df = s_df.iloc[indices].reset_index(drop=True)

    if len(s_df) < WINDOW_SIZE * 2:
        continue

    processed_sequences.append(s_df)
    sequence_info.append({'seq_id': seq_id, 'driver': pair['driver'], 'n_samples': len(s_df)})

# Sequence-based train/val/test split to prevent temporal leakage
unique_seqs = list(range(len(processed_sequences)))
train_seqs, val_seqs, test_seqs = split_sequences_by_index(
    unique_seqs, 0.70, 0.15, 0.15, CONFIG['random_seed']
)

def create_windows_from_seqs(seq_indices):
    windows, targets = [], []
    for idx in seq_indices:
        df = processed_sequences[idx]
        feat_arr = df[CONFIG['feature_cols']].values
        target_arr = df['velocity_ms'].values
        n_w = (len(df) - WINDOW_SIZE) // WINDOW_STRIDE
        for w in range(n_w):
            s = w * WINDOW_STRIDE
            e = s + WINDOW_SIZE
            windows.append(feat_arr[s:e])
            targets.append(target_arr[e - 1])
    return np.array(windows), np.array(targets)

X_train, y_train = create_windows_from_seqs(train_seqs)
X_val, y_val = create_windows_from_seqs(val_seqs)
X_test, y_test = create_windows_from_seqs(test_seqs)

# Normalization
from sklearn.preprocessing import StandardScaler
import joblib

scaler = StandardScaler()
scaler.fit(X_train.reshape(-1, N_FEATURES))

X_train_s = scaler.transform(X_train.reshape(-1, N_FEATURES)).reshape(-1, WINDOW_SIZE, N_FEATURES)
X_val_s = scaler.transform(X_val.reshape(-1, N_FEATURES)).reshape(-1, WINDOW_SIZE, N_FEATURES)
X_test_s = scaler.transform(X_test.reshape(-1, N_FEATURES)).reshape(-1, WINDOW_SIZE, N_FEATURES)

(ARTIFACTS_DIR / "scalers").mkdir(parents=True, exist_ok=True)
joblib.dump(scaler, ARTIFACTS_DIR / "scalers" / "velocity_scaler.joblib")

# Baselines
y_train_mean = np.mean(y_train)
mean_pred = np.full_like(y_test, y_train_mean)
baseline_mean_metrics = compute_regression_metrics(y_test, mean_pred)

def extract_window_features(X):
    n, ws, nf = X.shape
    feats = []
    for j in range(nf):
        col = X[:, :, j]
        feats.extend([np.mean(col, axis=1), np.std(col, axis=1), np.min(col, axis=1), np.max(col, axis=1)])
    acc_mag = np.sqrt(X[:, :, 0]**2 + X[:, :, 1]**2 + X[:, :, 2]**2)
    gyro_mag = np.sqrt(X[:, :, 3]**2 + X[:, :, 4]**2 + X[:, :, 5]**2)
    feats.extend([np.mean(acc_mag, axis=1), np.std(acc_mag, axis=1), np.mean(gyro_mag, axis=1), np.std(gyro_mag, axis=1)])
    return np.column_stack(feats)

X_train_feat = extract_window_features(X_train_s)
X_test_feat = extract_window_features(X_test_s)

from sklearn.linear_model import Ridge
from sklearn.ensemble import RandomForestRegressor

ridge = Ridge(alpha=1.0)
ridge.fit(X_train_feat, y_train)
ridge_metrics = compute_regression_metrics(y_test, ridge.predict(X_test_feat))

rf = RandomForestRegressor(n_estimators=50, max_depth=12, random_state=CONFIG['random_seed'], n_jobs=-1)
rf_subsample = min(30000, len(X_train_feat))
rf.fit(X_train_feat[:rf_subsample], y_train[:rf_subsample])
rf_metrics = compute_regression_metrics(y_test, rf.predict(X_test_feat))

(MODELS_DIR / "velocity").mkdir(parents=True, exist_ok=True)
joblib.dump(rf, MODELS_DIR / "velocity" / "velocity_rf_baseline.joblib")

# CNN-GRU Model
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

tf.random.set_seed(CONFIG['random_seed'])

inputs = keras.Input(shape=(WINDOW_SIZE, N_FEATURES), name='imu_input')
x = layers.Conv1D(32, 3, padding='same', activation='relu')(inputs)
x = layers.BatchNormalization()(x)
x = layers.Conv1D(32, 3, padding='same', activation='relu')(x)
x = layers.BatchNormalization()(x)
x = layers.GRU(32, return_sequences=False)(x)
x = layers.Dropout(0.2)(x)
x = layers.Dense(32, activation='relu')(x)
x = layers.Dropout(0.2)(x)
output = layers.Dense(1, activation='linear', name='velocity_output')(x)
model = keras.Model(inputs, output, name='velocity_cnn_gru')

model.compile(optimizer=keras.optimizers.Adam(learning_rate=CONFIG['learning_rate']), loss='mse', metrics=['mae'])

callbacks = [
    keras.callbacks.EarlyStopping(monitor='val_loss', patience=CONFIG['patience'], restore_best_weights=True),
    keras.callbacks.ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=5, min_lr=1e-6),
    keras.callbacks.ModelCheckpoint(str(MODELS_DIR / "velocity" / "velocity_cnn_gru_best.keras"), monitor='val_loss', save_best_only=True)
]

# Train or load checkpoint
checkpoint_path = MODELS_DIR / "velocity" / "velocity_cnn_gru.keras"
if checkpoint_path.exists():
    print("Loading existing trained velocity model...")
    model = keras.models.load_model(checkpoint_path)
    train_time = 0.0
else:
    print("Training CNN-GRU velocity model...")
    t0 = time.time()
    history = model.fit(
        X_train_s, y_train,
        validation_data=(X_val_s, y_val),
        epochs=CONFIG['epochs'],
        batch_size=CONFIG['batch_size'],
        callbacks=callbacks,
        verbose=1
    )
    train_time = time.time() - t0
    model.save(checkpoint_path)

nn_test_pred = model.predict(X_test_s, verbose=0).flatten()
nn_metrics = compute_regression_metrics(y_test, nn_test_pred)

print(f"Test MAE:  {nn_metrics['mae']:.4f} m/s ({nn_metrics['mae']*3.6:.2f} km/h)")
print(f"Test RMSE: {nn_metrics['rmse']:.4f} m/s")
print(f"Test R²:   {nn_metrics['r2']:.4f}")

# Export to pure TFLite using unrolled GRU model
inputs_deploy = keras.Input(shape=(WINDOW_SIZE, N_FEATURES), batch_size=1, name='imu_input')
x = layers.Conv1D(32, 3, padding='same', activation='relu')(inputs_deploy)
x = layers.BatchNormalization()(x)
x = layers.Conv1D(32, 3, padding='same', activation='relu')(x)
x = layers.BatchNormalization()(x)
x = layers.GRU(32, return_sequences=False, unroll=True)(x)
x = layers.Dropout(0.2)(x)
x = layers.Dense(32, activation='relu')(x)
x = layers.Dropout(0.2)(x)
output_deploy = layers.Dense(1, activation='linear', name='velocity_output')(x)
deploy_model = keras.Model(inputs_deploy, output_deploy)
deploy_model.set_weights(model.get_weights())

converter = tf.lite.TFLiteConverter.from_keras_model(deploy_model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()
tflite_path = MODELS_DIR / "velocity" / "velocity_cnn_gru.tflite"
with open(tflite_path, 'wb') as f:
    f.write(tflite_model)

# Latency benchmark
interp = tf.lite.Interpreter(model_path=str(tflite_path))
interp.allocate_tensors()
in_idx = interp.get_input_details()[0]['index']
out_idx = interp.get_output_details()[0]['index']

sample_input = X_test_s[0:1].astype(np.float32)
latencies = []
for _ in range(100):
    t0 = time.perf_counter()
    interp.set_tensor(in_idx, sample_input)
    interp.invoke()
    _ = interp.get_tensor(out_idx)
    latencies.append((time.perf_counter() - t0) * 1000)
avg_latency_ms = float(np.mean(latencies))

# Metadata
metadata = {
    'model_name': CONFIG['model_name'],
    'version': CONFIG['version'],
    'timestamp': datetime.now().isoformat(),
    'input_features': CONFIG['feature_cols'],
    'input_shape': [WINDOW_SIZE, N_FEATURES],
    'sampling_rate_hz': CONFIG['target_sampling_rate_hz'],
    'window_length_s': CONFIG['window_duration_s'],
    'window_stride_s': CONFIG['window_stride_s'],
    'target': 'velocity_ms',
    'normalization': 'StandardScaler',
    'model_architecture': 'CNN-GRU (Conv1D x2 -> GRU (unrolled) -> Dense)',
    'n_parameters': model.count_params(),
    'model_size_kb': os.path.getsize(tflite_path) / 1024,
    'n_train_windows': len(X_train),
    'n_val_windows': len(X_val),
    'n_test_windows': len(X_test),
    'metrics': {'test': nn_metrics},
    'baseline_metrics': {
        'mean': baseline_mean_metrics,
        'ridge_regression': ridge_metrics,
        'random_forest': rf_metrics
    },
    'inference_time_ms': avg_latency_ms,
    'export_format': 'TFLite'
}

save_model_metadata(metadata, ARTIFACTS_DIR / "configs" / "velocity_model_metadata.json")
print("Velocity model pipeline completed.")
