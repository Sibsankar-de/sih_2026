#!/usr/bin/env python3
"""Dataset discovery, schema verification, sampling rate analysis, and validation."""

import os
import sys
import json
import warnings
import numpy as np
import pandas as pd
from pathlib import Path
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common_utils import *

warnings.filterwarnings('ignore')

print("Starting Dataset Inspection...")

all_csvs = list(DATASET_ROOT.rglob("*.csv"))
s_files = [f for f in all_csvs if f.name.startswith("S-")]
v_files = [f for f in all_csvs if f.name.startswith("V-")]
sync_pairs = discover_sync_pairs()

print(f"Total CSV files found: {len(all_csvs)}")
print(f"Smartphone sensor files (S-*): {len(s_files)}")
print(f"Vehicle CAN-bus files (V-*):   {len(v_files)}")
print(f"Synchronized S-V pairs found:  {len(sync_pairs)}")

# Schema verification on sample pair
if sync_pairs:
    sample_pair = sync_pairs[0]
    try:
        s_df_sample = pd.read_csv(sample_pair['s_file'], nrows=5, encoding='utf-8')
    except UnicodeDecodeError:
        s_df_sample = pd.read_csv(sample_pair['s_file'], nrows=5, encoding='latin-1')
    try:
        v_df_sample = pd.read_csv(sample_pair['v_file'], nrows=5, encoding='utf-8')
    except UnicodeDecodeError:
        v_df_sample = pd.read_csv(sample_pair['v_file'], nrows=5, encoding='latin-1')

    print(f"Sample pair: {Path(sample_pair['s_file']).name} & {Path(sample_pair['v_file']).name}")
    print(f"Smartphone columns: {len(s_df_sample.columns)}, Vehicle columns: {len(v_df_sample.columns)}")

# Sequence profiling
sequence_stats = []
usable_pairs = []

for idx, pair in enumerate(sync_pairs):
    seq_id = pair['seq_id']
    s_df = load_s_file(pair['s_file'])
    v_df = load_v_file(pair['v_file'])

    if s_df is None or v_df is None:
        continue

    s_rows, v_rows = len(s_df), len(v_df)
    s_fs = compute_sampling_rate(s_df, 'time_since_start_ms', 'ms')
    v_fs = compute_sampling_rate(v_df, 'time_since_day_start_s', 's')

    s_duration_s = s_rows / s_fs if s_fs else 0
    v_duration_s = v_rows / v_fs if v_fs else 0

    speed_col = 'velocity_kmh' if 'velocity_kmh' in v_df.columns else None
    speed_mean = float(v_df[speed_col].mean()) if speed_col else 0.0
    speed_max = float(v_df[speed_col].max()) if speed_col else 0.0

    has_accel = all(c in s_df.columns for c in ['acc_x', 'acc_y', 'acc_z'])
    has_gyro = all(c in s_df.columns for c in ['gyro_yaw', 'gyro_pitch', 'gyro_roll'])
    is_usable = has_accel and has_gyro and s_rows >= 100 and speed_col is not None

    stats = {
        'seq_id': seq_id,
        'driver': pair['driver'],
        'category': pair['category'],
        's_rows': s_rows,
        'v_rows': v_rows,
        'row_diff': abs(s_rows - v_rows),
        's_sampling_rate_hz': round(s_fs, 2) if s_fs else None,
        'v_sampling_rate_hz': round(v_fs, 2) if v_fs else None,
        'duration_seconds': round(s_duration_s, 1),
        'speed_mean_kmh': round(speed_mean, 1),
        'speed_max_kmh': round(speed_max, 1),
        'is_usable': is_usable,
        's_file': pair['s_file'],
        'v_file': pair['v_file']
    }
    sequence_stats.append(stats)
    if is_usable:
        usable_pairs.append(pair)

stats_df = pd.DataFrame(sequence_stats)
usable_df = stats_df[stats_df['is_usable']]

total_usable_samples = int(usable_df['s_rows'].sum())
total_duration_min = round(usable_df['duration_seconds'].sum() / 60, 1)

print(f"Usable sequences: {len(usable_pairs)} / {len(sync_pairs)}")
print(f"Total usable samples: {total_usable_samples:,}")
print(f"Total usable duration: {total_duration_min} minutes ({total_duration_min/60:.1f} hours)")

# Save metadata
ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
(ARTIFACTS_DIR / "configs").mkdir(parents=True, exist_ok=True)

stats_df.to_csv(ARTIFACTS_DIR / "configs" / "sequence_statistics.csv", index=False)
with open(ARTIFACTS_DIR / "configs" / "usable_sequences.json", "w") as f:
    json.dump(usable_pairs, f, indent=2)

summary = {
    'total_csv_files': len(all_csvs),
    'smartphone_files': len(s_files),
    'vehicle_files': len(v_files),
    'sync_pairs_found': len(sync_pairs),
    'usable_sequences': len(usable_pairs),
    'total_usable_samples': total_usable_samples,
    'total_duration_minutes': total_duration_min,
    'mean_speed_kmh': round(float(usable_df['speed_mean_kmh'].mean()), 1),
    'max_speed_kmh': round(float(usable_df['speed_max_kmh'].max()), 1),
    'inspection_timestamp': datetime.now().isoformat()
}

with open(ARTIFACTS_DIR / "configs" / "dataset_summary.json", "w") as f:
    json.dump(summary, f, indent=2)

print("Dataset inspection outputs saved to artifacts/configs/")
