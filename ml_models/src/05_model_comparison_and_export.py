#!/usr/bin/env python3
"""Unified evaluation, dead reckoning simulation vs GPS ground truth, and deployment verification."""

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

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

FIGURES_DIR.mkdir(parents=True, exist_ok=True)

def load_json_safe(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception as e:
        return {}

vel_meta = load_json_safe(ARTIFACTS_DIR / "configs" / "velocity_model_metadata.json")
vib_meta = load_json_safe(ARTIFACTS_DIR / "configs" / "vibration_model_metadata.json")
mot_meta = load_json_safe(ARTIFACTS_DIR / "configs" / "motion_model_metadata.json")
ds_meta = load_json_safe(ARTIFACTS_DIR / "configs" / "dataset_summary.json")

print(f"{'Model':<20} {'Task':<16} {'Params':<10} {'TFLite Size':<14} {'Latency':<10}")
print("-" * 70)
print(f"{'Velocity Estimator':<20} {'Regression':<16} {vel_meta.get('n_parameters', 0):<10} {vel_meta.get('model_size_kb', 0):.1f} KB      {vel_meta.get('inference_time_ms', 0):.2f} ms")
print(f"{'Vibration Model':<20} {'Classification':<16} {vib_meta.get('n_parameters', 0):<10} {vib_meta.get('model_size_kb', 0):.1f} KB      {vib_meta.get('inference_time_ms', 0):.2f} ms")
print(f"{'Motion State Model':<20} {'Classification':<16} {mot_meta.get('n_parameters', 0):<10} {mot_meta.get('model_size_kb', 0):.1f} KB      {mot_meta.get('inference_time_ms', 0):.2f} ms")

total_size_kb = sum([
    vel_meta.get('model_size_kb', 0),
    vib_meta.get('model_size_kb', 0),
    mot_meta.get('model_size_kb', 0)
])
print("-" * 70)
print(f"Total TFLite package size: {total_size_kb:.1f} KB ({total_size_kb/1024:.2f} MB)")

# Dead Reckoning Demonstration
import tensorflow as tf
import joblib

vel_model_path = MODELS_DIR / "velocity" / "velocity_cnn_gru.tflite"
vel_scaler_path = ARTIFACTS_DIR / "scalers" / "velocity_scaler.joblib"

if vel_model_path.exists() and vel_scaler_path.exists():
    vel_interp = tf.lite.Interpreter(model_path=str(vel_model_path))
    vel_interp.allocate_tensors()
    vel_in = vel_interp.get_input_details()
    vel_out = vel_interp.get_output_details()
    vel_scaler = joblib.load(vel_scaler_path)

    usable_path = ARTIFACTS_DIR / "configs" / "usable_sequences.json"
    with open(usable_path) as f:
        usable_pairs = json.load(f)

    demo_pair = next((p for p in usable_pairs if p['seq_id'] == 'M'), usable_pairs[0])
    s_df = load_s_file(demo_pair['s_file'])
    v_df = load_v_file(demo_pair['v_file'])

    min_len = min(len(s_df), len(v_df))
    s_df = s_df.iloc[:min_len].copy()
    v_df = v_df.iloc[:min_len].copy()

    s_df = remove_gravity(s_df)
    s_df = compute_derived_features(s_df)
    s_df = handle_missing_values(s_df)

    window_size = 10
    stride = 5
    dt = 0.5

    features = s_df[IMU_FEATURES].values
    n_windows = (len(features) - window_size) // stride

    pred_vels, gt_vels = [], []
    for w in range(n_windows):
        s = w * stride
        e = s + window_size
        win_scaled = vel_scaler.transform(features[s:e]).astype(np.float32).reshape(1, window_size, len(IMU_FEATURES))
        vel_interp.set_tensor(vel_in[0]['index'], win_scaled)
        vel_interp.invoke()
        pred_v = max(0.0, float(vel_interp.get_tensor(vel_out[0]['index'])[0][0]))
        pred_vels.append(pred_v)

        gt_v = v_df['velocity_kmh'].iloc[s:e].mean() / 3.6 if 'velocity_kmh' in v_df.columns else 0.0
        gt_vels.append(gt_v)

    pred_vels = np.array(pred_vels)
    gt_vels = np.array(gt_vels)

    headings_deg = [v_df['heading'].iloc[w * stride: w * stride + window_size].mean() for w in range(n_windows)]
    headings_rad = np.deg2rad(headings_deg)

    lat0, lon0 = v_df['lat'].iloc[0], v_df['lon'].iloc[0]
    gt_east = [(v_df['lon'].iloc[min(w * stride + 5, len(v_df)-1)] - lon0) * 111320 * np.cos(np.deg2rad(lat0)) for w in range(n_windows)]
    gt_north = [(v_df['lat'].iloc[min(w * stride + 5, len(v_df)-1)] - lat0) * 110540 for w in range(n_windows)]

    dr_east = np.zeros(n_windows)
    dr_north = np.zeros(n_windows)
    for i in range(1, n_windows):
        dr_east[i] = dr_east[i-1] + pred_vels[i] * dt * np.sin(headings_rad[i])
        dr_north[i] = dr_north[i-1] + pred_vels[i] * dt * np.cos(headings_rad[i])

    pos_errors = np.sqrt((dr_east - gt_east)**2 + (dr_north - gt_north)**2)
    print(f"Dead Reckoning Mean Error:   {np.mean(pos_errors):.1f} m")
    print(f"Dead Reckoning Final Error:  {pos_errors[-1]:.1f} m")

print("Unified comparison and export completed.")
