# FineLine Navigator - System Architecture

## Problem SIH26168 Overview
AI-ML Based Intelligent Dead Reckoning System for Seamless Navigation under GNSS-denied and degraded operating environments.

```
+-----------------------------------------------------------------+
|                        PHYSICAL LAYER                           |
|  +---------------------------+   +---------------------------+  |
|  |   Smartphone IMU Sensors  |   |    GNSS Receiver Module   |  |
|  |  (Accel / Gyro / Magneto) |   |  (GPS / GLONASS / Galileo)|  |
|  +-------------+-------------+   +-------------+-------------+  |
+----------------|-------------------------------|----------------+
                 | (50 Hz Raw Stream)            | (1 Hz Fix)
                 v                               v
+-----------------------------------------------------------------+
|                        PROCESSING LAYER                         |
|  +---------------------------+   +---------------------------+  |
|  |   Sensor Signal Pipeline  |   |   GNSS Signal Validator   |  |
|  |  - Bandpass Filtering     |   |  - HDOP / Accuracy Check  |  |
|  |  - Gravity Compensation   |   |  - Outage Detection       |  |
|  |  - Coordinate Alignment   |   |  - Signal Restoration     |  |
|  +-------------+-------------+   +-------------+-------------+  |
|                |                               |                |
|                v                               |                |
|  +---------------------------+                 |                |
|  |     AI Inference Engine   |                 |                |
|  |  - Speed Prediction Model |                 |                |
|  |  - Heading Drift Estimator|                 |                |
|  |  - ZUPT Zero-Velocity Det.|                 |                |
|  +-------------+-------------+                 |                |
|                |                               |                |
|                v                               |                |
|  +---------------------------+                 |                |
|  |    Inertial Dead Reckoning|                 |                |
|  |    (INS State Integrator) |                 |                |
|  +-------------+-------------+                 |                |
|                |                               |                |
|                +---------------+---------------+                |
|                                |                                |
|                                v                                |
|  +-----------------------------------------------------------+  |
|  |          Extended Kalman Filter (EKF) Fusion Engine       |  |
|  |  - Error State Covariance Matrix Update                   |  |
|  |  - Dynamic Weighting (GNSS Conf vs INS Conf)              |  |
|  +-----------------------------+-----------------------------+  |
|                                |                                |
|                                v                                |
|  +-----------------------------------------------------------+  |
|  |              Map-Matching & Snapping Engine               |  |
|  |  - Road Topology Constraint & Heading Lock                |  |
|  +-----------------------------+-----------------------------+  |
+--------------------------------|--------------------------------+
                                 |
                                 v
+-----------------------------------------------------------------+
|                       APPLICATION LAYER                         |
|  +-----------------------------------------------------------+  |
|  |            FineLine Navigator UI / Presentation           |  |
|  |  - Live Leaflet/OSM Vector Map Layer                      |  |
|  |  - Real-time Telemetry & Drift Gauges                     |  |
|  |  - AI Speed & Sensor Analytics Charts                     |  |
|  |  - Outage Simulation Center (Tunnel, Canyon, Garage, etc.)|  |
|  +-----------------------------------------------------------+  |
+-----------------------------------------------------------------+
```

## Directory Structure

```
lib/
+-- core/
|   +-- constants/
|   |   +-- app_constants.dart
|   |   +-- mock_routes.dart
|   +-- services/
|   |   +-- service_interfaces.dart
|   |   +-- sensor_service.dart
|   |   +-- location_service.dart
|   |   +-- mock_ai_service.dart
|   |   +-- fusion_service.dart
|   |   +-- map_matching_service.dart
|   |   +-- navigation_service.dart
|   +-- theme/
|   |   +-- app_colors.dart
|   |   +-- app_theme.dart
|   +-- utils/
|       +-- formatters.dart
|       +-- geo_utils.dart
+-- features/
|   +-- ai_speed/
|   |   +-- ai_speed_screen.dart
|   +-- architecture_view/
|   |   +-- system_architecture_screen.dart
|   +-- dashboard/
|   |   +-- dashboard_screen.dart
|   +-- fusion_demo/
|   |   +-- fusion_screen.dart
|   +-- navigation/
|   |   +-- navigation_screen.dart
|   +-- research/
|   |   +-- research_screen.dart
|   +-- sensors/
|   |   +-- sensor_monitoring_screen.dart
|   +-- settings/
|   |   +-- settings_screen.dart
|   +-- simulation/
|   |   +-- simulation_center_screen.dart
|   +-- splash/
|       +-- splash_screen.dart
+-- models/
|   +-- fusion_data.dart
|   +-- navigation_state.dart
|   +-- research_data.dart
|   +-- sensor_data.dart
|   +-- simulation_scenario.dart
|   +-- speed_estimate.dart
+-- widgets/
|   +-- custom_app_bar.dart
|   +-- live_chart.dart
|   +-- metric_card.dart
|   +-- nav_drawer.dart
|   +-- status_badge.dart
|   +-- telemetry_tile.dart
+-- main.dart
```

## Service Interface Specifications

1. `ISensorService`: Hardware & synthetic accelerometer, gyroscope, magnetometer data streams.
2. `ILocationService`: Raw GNSS fix provider, satellite telemetry, outage trigger/restoration.
3. `IMockAIService`: Deep learning speed estimation, noise filtering, confidence inference, ZUPT detector.
4. `IFusionService`: Extended Kalman Filter implementation uniting INS Dead Reckoning with GNSS.
5. `IMapMatchingService`: Road geometry alignment, projection, and cross-track error bounds.
6. `INavigationService`: Top-level orchestrator maintaining state, continuous route simulation, scenario execution.
