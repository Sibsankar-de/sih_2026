# FineLine Navigator - Agent Instruction & Workflow Guide

## Mission Overview
FineLine Navigator is a production-grade Flutter application developed for Smart India Hackathon 2026 (Problem Statement SIH26168: AI-ML Based Intelligent Dead Reckoning System for Seamless Navigation).

The application demonstrates high-precision vehicle navigation under severe GNSS degradation and outages (e.g., long tunnels, underground multi-level parking garages, dense urban canyons, and forest canopies) by fusing Inertial Navigation System (INS) IMU sensor data with deep learning velocity estimation and Extended Kalman Filtering (EKF).

## Core Architectural Guidelines

1. Modular Decoupling
   - Keep data acquisition, AI inference, fusion filtering, map matching, and UI presentation in distinct service layers.
   - All AI/ML components must implement standard abstract interfaces (`MockAIService`, `SensorService`, `FusionService`, `MapMatchingService`, `NavigationService`) to ensure plug-and-play replacement with ONNX Runtime, TFLite, or C++ native libraries.

2. Presentation & Production Quality
   - Follow Material 3 specifications with adaptive dark and light color palettes.
   - Maintain 60fps rendering during continuous simulation and real-time sensor updates.
   - Ensure complete offline operation for simulation, dead reckoning computation, and sensor monitoring.

3. Sensor Resiliency
   - Listen to device accelerometer, gyroscope, and magnetometer streams via `sensors_plus`.
   - Provide seamless automatic fallback to simulated IMU physics engines if physical hardware is unavailable or running in emulators/browsers.

4. Coding Standards
   - No unnecessary comments or auto-generated disclaimers.
   - Maintain strict typing and null safety across all models and services.
   - Visual diagrams in text or markdown documentation must use standard keyboard ASCII characters only.

## Maintenance Workflow
- If service interfaces or data models change, synchronize changes in `architecture.md` immediately.
- Validate state updates via Provider listeners to prevent excessive widget rebuilds.
