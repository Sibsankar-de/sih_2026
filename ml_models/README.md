# SIH 2026 - Problem Statement SIH26168
# AI-ML Based Intelligent Dead Reckoning System for Seamless Navigation
## Machine Learning Pipeline & Mobile TFLite Models

This folder contains the complete machine learning pipeline and exported TensorFlow Lite edge models for smartphone-based inertial navigation in GNSS-denied environments.

---

## Folder Organization

* **`notebooks/`** - Interactive Jupyter Notebooks (`.ipynb`) pre-executed with complete markdown documentation, tables, and rendered figures:
  * `01_dataset_inspection.ipynb` - Dataset discovery, schema check, sampling rate analysis
  * `02_velocity_model.ipynb` - Velocity CNN-GRU pipeline, baseline benchmarks, speed-range error analysis
  * `03_vibration_model.ipynb` - Vibration 1D-CNN classifier, confusion matrix, noise covariance tuning
  * `04_motion_model.ipynb` - Motion state CNN-GRU model, ZUPT evaluation, transition stability
  * `05_model_comparison_and_export.ipynb` - Unified comparison, TFLite audit, and Dead Reckoning trajectory simulation
* **`src/`** - Clean, modular Python scripts (`.py`):
  * `common_utils.py` - Core data loader, feature transforms, and metrics
  * `01_dataset_inspection.py` - Dataset discovery and schema inspection script
  * `02_velocity_model.py` - Velocity model training and pure TFLite export
  * `03_vibration_model.py` - Vibration classification and TFLite export
  * `04_motion_model.py` - Motion state model and TFLite export
  * `05_model_comparison_and_export.py` - Unified comparison and DR simulation script
  * `inference_example.py` - Standalone real-time streaming inference engine
  * `generate_executed_notebooks.py` - Automated notebook generator and runner
* **`models/`** - Trained Keras (`.keras`) and pure TFLite (`.tflite`) binaries for mobile deployment
* **`artifacts/`** - StandardScaler instances (`.joblib`) and metadata configs (`.json`, `.csv`)
* **`reports/`** - Markdown summary report and 15 high-resolution evaluation figures

---

## Model Performance Summary

| Property | Model 1: Velocity Estimator | Model 2: Vibration Classifier | Model 3: Motion State Classifier |
| :--- | :--- | :--- | :--- |
| **Task Type** | Temporal Regression | 3-Class Classification | 6-Class Classification |
| **Target Variable** | Forward Speed ($m/s$) | Smooth / Moderate / High | Stationary, Straight, Left, Right, Accel, Brake |
| **Input Shape** | $(10, 6)$ [1.0s @ 10 Hz] | $(10, 6)$ [1.0s @ 10 Hz] | $(10, 6)$ [1.0s @ 10 Hz] |
| **Architecture** | **CNN-GRU** (unrolled) | **1D-CNN** (Conv1D + GAP) | **CNN-GRU** (unrolled) |
| **Parameters** | **16,161** | **9,379** | **11,558** |
| **TFLite Size** | **55.1 KB** | **20.5 KB** | **52.9 KB** |
| **CPU Latency** | **0.01 ms** | **0.005 ms** | **0.02 ms** |
| **Test Performance** | **MAE: 3.87 m/s (13.9 km/h)**<br>**RMSE: 5.04 m/s**<br>**$R^2$: 0.649** | **Accuracy: 97.06%**<br>**Precision: 97.11%**<br>**Macro F1: 0.971** | **Accuracy: 49.43%**<br>**Precision: 56.30%**<br>**Macro F1: 0.507** |
| **Baseline 1** | Mean: MAE 7.34 m/s | Rule-based: Acc 91.2% | Rule-based: Acc 50.85% |
| **Baseline 2** | Random Forest: MAE 4.22 m/s | Random Forest: Acc 97.7% | Random Forest: Acc 52.71% |
| **Mobile Ops** | Pure built-in TFLite (0 Flex) | Pure built-in TFLite (0 Flex) | Pure built-in TFLite (0 Flex) |

---

## Quickstart

```bash
# Activate venv
source venv/bin/activate

# Run real-time streaming inference test
python src/inference_example.py

# Launch interactive notebooks
jupyter notebook notebooks/
```
