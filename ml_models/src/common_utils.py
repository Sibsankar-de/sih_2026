"""Shared utilities for data loading, preprocessing, windowing, and evaluation."""

import os
import re
import json
import warnings
import numpy as np
import pandas as pd
from pathlib import Path

# Paths
PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATASET_ROOT = PROJECT_ROOT / "datasets"
SYNC_DATASET = DATASET_ROOT / "Synchronised V abd S datasets"
UNSYNC_DATASET = DATASET_ROOT / "Unsynchronised V and S Dataset"
MODELS_DIR = PROJECT_ROOT / "models"
ARTIFACTS_DIR = PROJECT_ROOT / "artifacts"
REPORTS_DIR = PROJECT_ROOT / "reports"
FIGURES_DIR = REPORTS_DIR / "figures"

RANDOM_SEED = 42
np.random.seed(RANDOM_SEED)

# Sensor column mappings
S_COLUMNS = [
    'gps_lat', 'gps_lon', 'gps_alt', 'gps_speed_kmh', 'gps_accuracy',
    'gps_orientation', 'gps_satellites', 'time_since_start_ms', 'date',
    'acc_x', 'acc_y', 'acc_z',
    'gravity_x', 'gravity_y', 'gravity_z',
    'gyro_yaw', 'gyro_pitch', 'gyro_roll',
    'mag_x', 'mag_y', 'mag_z',
    'orient_yaw', 'orient_pitch', 'orient_roll'
]

V_COLUMNS = [
    'gps_satellites', 'time_since_day_start_s', 'lat', 'lon',
    'velocity_kmh', 'heading', 'height_km', 'vertical_velocity_kmh',
    'sample_period_s', 'steering_angle',
    'wheel_speed_fl', 'wheel_speed_fr', 'wheel_speed_rl', 'wheel_speed_rr',
    'yaw_rate', 'indicated_speed_kmh',
    'longitudinal_accel_g', 'lateral_accel_g',
    'handbrake', 'gear_requested', 'gear',
    'engine_speed_rpm', 'coolant_temp', 'clutch_position',
    'brake_pressure_psi', 'brake_position',
    'battery_voltage', 'air_temp', 'accelerator_position'
]

IMU_FEATURES = ['acc_x', 'acc_y', 'acc_z', 'gyro_yaw', 'gyro_pitch', 'gyro_roll']


def discover_sync_pairs(base_dir=None):
    """Discover all synchronized smartphone-vehicle CSV pairs."""
    if base_dir is None:
        base_dir = SYNC_DATASET

    pairs = []
    cat_dir = base_dir / "Categorised IOVNB Dataset"
    if cat_dir.exists():
        for s_file in sorted(cat_dir.rglob("S-*.csv")):
            folder = s_file.parent
            v_candidates = list(folder.glob("V-*.csv"))
            if v_candidates:
                v_file = v_candidates[0]
                seq_match = re.search(r'S-(.+)\.csv', s_file.name)
                seq_id = seq_match.group(1) if seq_match else s_file.stem
                driver_match = re.search(r'\(Driver (\w+)\)', str(folder))
                driver = driver_match.group(1) if driver_match else 'Unknown'
                parts = folder.relative_to(cat_dir).parts
                category = parts[0].split(' ')[0] if parts else 'Unknown'
                pairs.append({
                    'seq_id': seq_id,
                    's_file': str(s_file),
                    'v_file': str(v_file),
                    'driver': driver,
                    'category': category,
                    'dataset_type': 'categorised'
                })

    # Uncategorised dataset fallback
    uncat_dir = base_dir / "Uncategorised IOVNB Dataset"
    if uncat_dir.exists():
        s_folder = uncat_dir / "S"
        v_folder = uncat_dir / "V"
        if s_folder.exists() and v_folder.exists():
            for s_file in sorted(s_folder.glob("S-*.csv")):
                seq_match = re.search(r'S-(.+)\.csv', s_file.name)
                if seq_match:
                    seq_id = seq_match.group(1)
                    v_file = v_folder / f"V-{seq_id}.csv"
                    if v_file.exists():
                        pairs.append({
                            'seq_id': seq_id,
                            's_file': str(s_file),
                            'v_file': str(v_file),
                            'driver': 'Unknown',
                            'category': 'Unknown',
                            'dataset_type': 'uncategorised'
                        })

    # Deduplicate by sequence ID, preferring categorised
    seen = {}
    unique_pairs = []
    for p in pairs:
        sid = p['seq_id']
        if sid not in seen or (p['dataset_type'] == 'categorised' and seen[sid]['dataset_type'] != 'categorised'):
            seen[sid] = p

    for sid in sorted(seen.keys()):
        unique_pairs.append(seen[sid])

    return unique_pairs


def load_s_file(filepath, clean_columns=True):
    """Load smartphone sensor CSV file with encoding fallback."""
    try:
        try:
            df = pd.read_csv(filepath, header=0, encoding='utf-8')
        except UnicodeDecodeError:
            df = pd.read_csv(filepath, header=0, encoding='latin-1')

        if clean_columns and len(df.columns) == len(S_COLUMNS):
            df.columns = S_COLUMNS
        elif clean_columns:
            cleaned = []
            for col in df.columns:
                c = col.strip().lower()
                c = re.sub(r'[^a-z0-9_]', '_', c)
                c = re.sub(r'_+', '_', c).strip('_')
                cleaned.append(c)
            df.columns = cleaned
        return df
    except Exception as e:
        warnings.warn(f"Failed to load {filepath}: {e}")
        return None


def load_v_file(filepath, clean_columns=True):
    """Load vehicle CAN-bus CSV file with encoding fallback."""
    try:
        try:
            df = pd.read_csv(filepath, header=0, encoding='utf-8')
        except UnicodeDecodeError:
            df = pd.read_csv(filepath, header=0, encoding='latin-1')

        if clean_columns and len(df.columns) == len(V_COLUMNS):
            df.columns = V_COLUMNS
        elif clean_columns:
            cleaned = []
            for col in df.columns:
                c = col.strip().lower()
                c = re.sub(r'[^a-z0-9_]', '_', c)
                c = re.sub(r'_+', '_', c).strip('_')
                cleaned.append(c)
            df.columns = cleaned
        return df
    except Exception as e:
        warnings.warn(f"Failed to load {filepath}: {e}")
        return None


def compute_sampling_rate(df, time_col='time_since_start_ms', unit='ms'):
    """Compute empirical sampling rate in Hz from timestamps."""
    if time_col not in df.columns or len(df) < 2:
        return None
    time_diffs = df[time_col].diff().dropna()
    median_dt = time_diffs.median()
    if median_dt <= 0:
        return None
    return 1000.0 / median_dt if unit == 'ms' else 1.0 / median_dt


def remove_gravity(df):
    """Subtract Android gravity components from raw acceleration if present."""
    df = df.copy()
    if all(c in df.columns for c in ['gravity_x', 'gravity_y', 'gravity_z']):
        df['linear_acc_x'] = df['acc_x'] - df['gravity_x']
        df['linear_acc_y'] = df['acc_y'] - df['gravity_y']
        df['linear_acc_z'] = df['acc_z'] - df['gravity_z']
    else:
        df['linear_acc_x'] = df['acc_x']
        df['linear_acc_y'] = df['acc_y']
        df['linear_acc_z'] = df['acc_z']
    return df


def compute_derived_features(df):
    """Compute sensor vector magnitudes."""
    df = df.copy()
    if all(c in df.columns for c in ['acc_x', 'acc_y', 'acc_z']):
        df['acc_mag'] = np.sqrt(df['acc_x']**2 + df['acc_y']**2 + df['acc_z']**2)
    if all(c in df.columns for c in ['linear_acc_x', 'linear_acc_y', 'linear_acc_z']):
        df['linear_acc_mag'] = np.sqrt(df['linear_acc_x']**2 + df['linear_acc_y']**2 + df['linear_acc_z']**2)
    if all(c in df.columns for c in ['gyro_yaw', 'gyro_pitch', 'gyro_roll']):
        df['gyro_mag'] = np.sqrt(df['gyro_yaw']**2 + df['gyro_pitch']**2 + df['gyro_roll']**2)
    return df


def handle_missing_values(df, strategy='interpolate'):
    """Handle missing values in continuous time-series sensor signals."""
    df = df.copy()
    numeric_cols = df.select_dtypes(include=[np.number]).columns
    if strategy == 'interpolate':
        df[numeric_cols] = df[numeric_cols].interpolate(method='linear', limit_direction='both')
    elif strategy == 'forward_fill':
        df[numeric_cols] = df[numeric_cols].ffill().bfill()
    return df


def split_sequences_by_index(seq_indices, train_ratio=0.70, val_ratio=0.15, test_ratio=0.15, seed=RANDOM_SEED):
    """Split sequences by ID to strictly prevent temporal data leakage."""
    rng = np.random.RandomState(seed)
    shuffled = rng.permutation(seq_indices)
    n = len(shuffled)
    n_train = int(n * train_ratio)
    n_val = int(n * val_ratio)
    train_idx = sorted(shuffled[:n_train])
    val_idx = sorted(shuffled[n_train:n_train + n_val])
    test_idx = sorted(shuffled[n_train + n_val:])
    return train_idx, val_idx, test_idx


def compute_regression_metrics(y_true, y_pred):
    """Compute MAE, RMSE, and R2 score for velocity regression."""
    mae = float(np.mean(np.abs(y_true - y_pred)))
    rmse = float(np.sqrt(np.mean((y_true - y_pred)**2)))
    ss_tot = np.sum((y_true - np.mean(y_true))**2)
    ss_res = np.sum((y_true - y_pred)**2)
    r2 = float(1.0 - (ss_res / ss_tot)) if ss_tot > 0 else 0.0
    return {'mae': mae, 'rmse': rmse, 'r2': r2}


def compute_classification_metrics(y_true, y_pred, class_names=None):
    """Compute accuracy, precision, recall, F1, and confusion matrix."""
    from sklearn.metrics import accuracy_score, precision_recall_fscore_support, confusion_matrix, classification_report
    acc = float(accuracy_score(y_true, y_pred))
    p, r, f1, _ = precision_recall_fscore_support(y_true, y_pred, average='macro', zero_division=0)
    cm = confusion_matrix(y_true, y_pred).tolist()
    report = classification_report(y_true, y_pred, target_names=class_names, output_dict=True, zero_division=0)
    return {
        'accuracy': acc,
        'precision': float(p),
        'recall': float(r),
        'f1': float(f1),
        'confusion_matrix': cm,
        'report': report
    }


def save_model_metadata(metadata_dict, filepath):
    """Save model configuration and metrics metadata to JSON."""
    filepath = Path(filepath)
    filepath.parent.mkdir(parents=True, exist_ok=True)
    with open(filepath, 'w') as f:
        json.dump(metadata_dict, f, indent=2, default=str)
