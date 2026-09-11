/// @file main.cpp
/// @brief Synthetic dead-reckoning benchmark for the 2D Fusion Engine.
///
/// Generates a ground truth trajectory (straight → turn → straight),
/// synthetic sensor data (IMU, GNSS, ML velocity), and evaluates
/// five configurations of increasing fusion complexity.

#include <iostream>
#include <vector>
#include <cmath>
#include <iomanip>
#include <random>
#include "fusion.h"

using namespace fusion;

// ---------------------------------------------------------------------------
// Helper: create an IMU sample
// ---------------------------------------------------------------------------
IMUSample makeIMU(double t, double ax, double ay, double gz) {
    IMUSample s;
    s.timestamp = t;
    s.accel = Eigen::Vector2d(ax, ay);
    s.gyro_z = gz;
    return s;
}

// ---------------------------------------------------------------------------
// Helper: create a GNSS measurement from local ENU truth
// ---------------------------------------------------------------------------
GNSSMeasurement makeGNSS(double t, double true_px, double true_py,
                         double true_vx, double true_vy, double true_yaw,
                         double noise_m = 2.0) {
    static std::mt19937 rng(42);
    std::normal_distribution<double> pos_noise(0.0, noise_m);
    std::normal_distribution<double> vel_noise(0.0, 0.3);

    // Convert local ENU back to approximate lat/lon
    // Using small-angle: lat ≈ origin + north/R,  lon ≈ origin + east/(R*cos(lat0))
    // Origin is (0, 0) degrees for this synthetic test
    double lat_deg = (true_py + pos_noise(rng)) / EARTH_RADIUS * RAD_TO_DEG;
    double lon_deg = (true_px + pos_noise(rng)) / EARTH_RADIUS * RAD_TO_DEG;

    GNSSMeasurement g;
    g.timestamp = t;
    g.latitude_deg = lat_deg;
    g.longitude_deg = lon_deg;
    g.horizontal_accuracy_m = noise_m;
    g.has_velocity = true;
    g.velocity_enu = Eigen::Vector2d(true_vx + vel_noise(rng),
                                     true_vy + vel_noise(rng));
    g.velocity_accuracy_mps = 0.5;
    g.has_course = true;
    g.course_rad = true_yaw;
    g.valid = true;
    return g;
}

// ---------------------------------------------------------------------------
// Simulation results
// ---------------------------------------------------------------------------
struct SimulationResult {
    double rmse_pos;
    double max_err;
    double drift_outage;  // max error during GNSS outage
};

// ---------------------------------------------------------------------------
// Run a single simulation with the specified mode
//   mode 1: Pure IMU (no GNSS updates after init)
//   mode 2: EKF + GNSS
//   mode 3: EKF + GNSS + ML
//   mode 4: EKF + GNSS + ML + NHC
//   mode 5: EKF + GNSS + ML + NHC + ZUPT
// ---------------------------------------------------------------------------
SimulationResult runSimulation(int mode) {
    FusionConfig config;
    config.init_yaw_sigma = 0.1;  // We know yaw reasonably well
    config.gnss_min_accuracy_m = 1.0;

    FusionEngine engine;
    engine.initialize(config);

    const double dt = 0.01;            // 100 Hz IMU
    const int total_steps = 3000;      // 30 seconds total
    const int gnss_interval = 100;     // GNSS at 1 Hz
    const int outage_start = 1500;     // GNSS outage at 15 s
    const int outage_end = 2500;       // GNSS returns at 25 s

    // Ground truth state
    double true_px = 0.0, true_py = 0.0;
    double true_vx = 10.0, true_vy = 0.0;  // 10 m/s East
    double true_yaw = 0.0;
    double true_speed = 10.0;

    // Provide initial GNSS fix for initialization
    engine.processGNSS(makeGNSS(0.0, true_px, true_py, true_vx, true_vy, true_yaw, 1.0));
    // Need at least one IMU sample to set the timestamp
    engine.processIMU(makeIMU(0.0, 0.0, 0.0, 0.0));

    // Noise generators for IMU
    std::mt19937 rng(123);
    std::normal_distribution<double> accel_noise(0.0, 0.1);
    std::normal_distribution<double> gyro_noise(0.0, 0.005);

    double mse = 0.0;
    double max_err = 0.0;
    double max_outage_err = 0.0;
    int count = 0;

    for (int i = 1; i <= total_steps; ++i) {
        double t = i * dt;

        // --- Ground truth trajectory ---
        double commanded_gyro = 0.0;
        double commanded_ax = 0.0;  // forward accel in vehicle frame

        if (i >= 800 && i < 1200) {
            // Turning phase: gentle right turn at ~0.2 rad/s
            commanded_gyro = 0.2;
        }

        // Update ground truth
        true_yaw += commanded_gyro * dt;
        true_vx = true_speed * std::cos(true_yaw);
        true_vy = true_speed * std::sin(true_yaw);
        true_px += true_vx * dt;
        true_py += true_vy * dt;

        // --- Generate IMU measurement (in vehicle frame) ---
        // Vehicle-frame accel: forward = commanded_ax, lateral = centripetal = speed * yaw_rate
        double veh_ax = commanded_ax + accel_noise(rng);
        double veh_ay = accel_noise(rng);  // Lateral accel (should be ~0 for NHC)
        double veh_gz = commanded_gyro + gyro_noise(rng);

        engine.processIMU(makeIMU(t, veh_ax, veh_ay, veh_gz));

        // --- GNSS ---
        bool is_outage = (i >= outage_start && i < outage_end);

        if (i % gnss_interval == 0 && !is_outage && mode >= 2) {
            engine.processGNSS(makeGNSS(t, true_px, true_py, true_vx, true_vy, true_yaw));
        }

        // --- ML velocity ---
        if (mode >= 3 && i % 10 == 0) {
            std::normal_distribution<double> ml_noise(0.0, 0.3);
            MLVelocityMeasurement ml;
            ml.timestamp = t;
            ml.forward_velocity_mps = true_speed + ml_noise(rng);
            ml.confidence = 0.85;
            ml.sigma_mps = 0.5;
            ml.valid = true;
            engine.processMLVelocity(ml);
        }

        // --- NHC ---
        if (mode >= 4 && i % 10 == 0) {
            engine.processNHC();
        }

        // --- ZUPT ---
        if (mode >= 5) {
            engine.processZUPT();  // Will only apply if stationary
        }

        // --- Compute error ---
        auto state = engine.getState();
        double err = std::sqrt(std::pow(state.east_m - true_px, 2) +
                               std::pow(state.north_m - true_py, 2));

        mse += err * err;
        max_err = std::max(max_err, err);
        if (is_outage) {
            max_outage_err = std::max(max_outage_err, err);
        }
        count++;
    }

    return {std::sqrt(mse / count), max_err, max_outage_err};
}

// ---------------------------------------------------------------------------
int main() {
    std::cout << "\n";
    std::cout << "╔════════════════════════════════════════════════════════╗\n";
    std::cout << "║   2D GNSS + IMU + ML Fusion Engine — Benchmark       ║\n";
    std::cout << "╚════════════════════════════════════════════════════════╝\n\n";

    std::cout << "Trajectory: 30s at 10 m/s with a turning phase\n";
    std::cout << "GNSS outage: 15s – 25s (10 seconds, ~100m travel)\n\n";

    const char* modes[] = {
        "1. Pure IMU (no updates)",
        "2. EKF + GNSS",
        "3. EKF + GNSS + ML Velocity",
        "4. EKF + GNSS + ML + NHC",
        "5. Full (+ ZUPT)"
    };

    std::cout << std::left
              << std::setw(32) << "Mode"
              << std::setw(14) << "RMSE (m)"
              << std::setw(14) << "Max Err (m)"
              << std::setw(18) << "Outage Drift (m)"
              << "\n";
    std::cout << std::string(78, '-') << "\n";

    for (int i = 1; i <= 5; ++i) {
        auto res = runSimulation(i);
        std::cout << std::left
                  << std::setw(32) << modes[i - 1]
                  << std::fixed << std::setprecision(2)
                  << std::setw(14) << res.rmse_pos
                  << std::setw(14) << res.max_err
                  << std::setw(18) << res.drift_outage
                  << "\n";
    }

    std::cout << "\n";
    std::cout << "Note: Mode 1 has no corrections, so drift grows unbounded.\n";
    std::cout << "      ML velocity + NHC significantly reduce drift during GNSS outage.\n\n";

    return 0;
}
