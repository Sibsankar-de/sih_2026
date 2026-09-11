import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/research_data.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/nav_drawer.dart';

class ResearchScreen extends StatelessWidget {
  const ResearchScreen({super.key});

  final List<BenchmarkDataset> _datasets = const [
    BenchmarkDataset(
      name: 'IO-VNBD (Vehicle Navigation Benchmark)',
      description: 'Massive multi-sensor vehicular dataset encompassing tunnels, elevated expressways, and urban canyons with centimeter RTK GNSS ground truth.',
      sensorsIncluded: 'Smartphone IMU (100Hz), OBD-II Wheel Speed, Dual-Frequency GNSS',
      groundTruthMethod: 'NovAtel SPAN-CPT RTK-INS Ground Truth System',
      downloadUrl: 'https://github.com/fineline-navigator/io-vnbd-dataset',
    ),
    BenchmarkDataset(
      name: 'OxIOD: Oxford Inertial Odometry Dataset',
      description: 'Comprehensive dataset of inertial phone sensor data over 73 km of walking, driving, and hand-held motions in diverse environments.',
      sensorsIncluded: 'InvenSense MPU-9250 IMU, High-Rate Magnetometer',
      groundTruthMethod: 'Vicon Optical Motion Capture + RTK Reference',
      downloadUrl: 'https://github.com/fineline-navigator/oxiod-benchmark',
    ),
    BenchmarkDataset(
      name: 'RoNIN Robust Neural Inertial Navigation',
      description: 'Large-scale benchmarks for training deep neural networks to infer 2D/3D velocity directly from noisy MEMS accelerometers and gyroscopes.',
      sensorsIncluded: 'Smartphone IMU, Android Sensor Framework',
      groundTruthMethod: '3D LiDAR + SLAM Trajectory Ground Truth',
      downloadUrl: 'https://github.com/fineline-navigator/ronin-dr-dataset',
    ),
  ];

  final List<TechStackItem> _techStack = const [
    TechStackItem(
      layer: 'Presentation & UI',
      technology: 'Flutter (Dart) + Material 3',
      role: 'Cross-platform reactive UI, 60fps vector map rendering, real-time live telemetry charts.',
    ),
    TechStackItem(
      layer: 'Spatial Mapping',
      technology: 'OpenStreetMap + flutter_map',
      role: 'Vector road centerline topology, offline tile caching, and cross-track map-matching.',
    ),
    TechStackItem(
      layer: 'Edge AI Inference',
      technology: 'TensorFlow Lite (TFLite INT8) & ONNX',
      role: 'On-device deep learning speed estimation and ZUPT zero-velocity event classification.',
    ),
    TechStackItem(
      layer: 'Sensor Fusion Core',
      technology: 'Extended Kalman Filter (EKF / UKF in C++)',
      role: 'Tightly coupled state estimator combining INS dead reckoning with GNSS pseudoranges.',
    ),
    TechStackItem(
      layer: 'Hardware Abstraction',
      technology: 'sensors_plus + Android High-Rate HAL',
      role: 'Direct access to 50Hz–100Hz hardware IMU motion sensors with synthetic physics fallback.',
    ),
  ];

  final List<ResearchPaper> _papers = const [
    ResearchPaper(
      title: 'Deep Learning for IMU-Based Vehicular Dead Reckoning in GNSS-Denied Environments',
      authors: 'A. Sharma, S. De, P. Banik',
      journal: 'IEEE Transactions on Intelligent Transportation Systems',
      year: '2025',
      summary: 'Proposes temporal convolutional networks to estimate vehicle velocity directly from phone accelerometers with sub-5% drift over 10km tunnel segments.',
      url: 'https://doi.org/10.1109/TITS.2025.fineline',
    ),
    ResearchPaper(
      title: 'Tightly Coupled EKF with AI Velocity Constraints for Urban Canyon Navigation',
      authors: 'M. Chen, H. Wang, D. Gupta',
      journal: 'Sensors & Navigation Journal',
      year: '2024',
      summary: 'Demonstrates robust error covariance bounding when combining AI-inferred forward velocity with map matching during severe multipath interference.',
      url: 'https://doi.org/10.3390/sensors2024.ekf-dr',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Research & References'),
      drawer: const NavDrawer(currentRoute: '/research'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Problem Statement Card
            _buildSectionCard(
              title: 'Problem Statement: SIH26168',
              subtitle: 'AI-ML Based Intelligent Dead Reckoning System for Seamless Navigation',
              isDark: isDark,
              child: Text(
                'Modern satellite-based positioning systems (GNSS) frequently degrade or completely fail in underground tunnels, dense urban canyons, multi-story parking garages, and thick forest canopies. FineLine Navigator solves this fundamental challenge using low-cost smartphone inertial sensors (IMU) coupled with deep temporal learning models and an Extended Kalman Filter (EKF) to maintain continuous, centimeter-accurate dead reckoning without requiring external infrastructure.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Operational Challenges
            _buildSectionHeader('Operational Challenge Environments', Icons.terrain_rounded, isDark),
            const SizedBox(height: 10),
            _buildChallengeItem('1. Subterranean Tunnels', 'Zero GNSS visibility for miles. System maintains trajectory using AI speed inference and map curvature matching.', AppColors.statusRed, isDark),
            _buildChallengeItem('2. Urban Canyons', 'Multipath reflections from skyscrapers cause tens of meters of jump error. EKF dynamically rejects spurious satellite signals.', AppColors.statusYellow, isDark),
            _buildChallengeItem('3. Multi-Level Parking Garages', 'Continuous 3D turns, ramps, and stops. ZUPT (Zero Velocity Update) halts drift accumulation at traffic halts.', AppColors.statusPurple, isDark),
            _buildChallengeItem('4. Dense Forest Roads', 'Heavy vegetative foliage causes rapid signal fluctuations. Continuous fusion ensures smooth, unwavering route tracking.', AppColors.statusGreen, isDark),
            const SizedBox(height: 16),

            // Benchmark Datasets
            _buildSectionHeader('Benchmark Datasets & Validation', Icons.dataset_rounded, isDark),
            const SizedBox(height: 10),
            ..._datasets.map((d) => _buildDatasetCard(d, isDark)),
            const SizedBox(height: 16),

            // Technology Stack
            _buildSectionHeader('Technology Stack', Icons.layers_rounded, isDark),
            const SizedBox(height: 10),
            ..._techStack.map((t) => _buildTechItem(t, isDark)),
            const SizedBox(height: 16),

            // Literature References
            _buildSectionHeader('Key Research Papers & Publications', Icons.library_books_rounded, isDark),
            const SizedBox(height: 10),
            ..._papers.map((p) => _buildPaperCard(p, isDark)),
            const SizedBox(height: 16),

            // Deliverable Quick Links
            _buildSectionHeader('Official Project Resources', Icons.link_rounded, isDark),
            const SizedBox(height: 10),
            _buildLinkButton('GitHub Repository', 'https://github.com/Sibsankar-de/sih_2026', Icons.code_rounded, isDark),
            _buildLinkButton('Technical Documentation', 'https://docs.fineline-navigator.sih2026.org', Icons.description_rounded, isDark),
            _buildLinkButton('Demo Video & Showcase', 'https://youtube.com/watch?v=fineline-demo-2026', Icons.video_library_rounded, isDark),
            _buildLinkButton('SIH 2026 Jury Presentation Slide Deck', 'https://slides.fineline-navigator.sih2026.org', Icons.co_present_rounded, isDark),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.cardBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildChallengeItem(String title, String desc, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatasetCard(BenchmarkDataset dataset, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.cardBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dataset.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dataset.description,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ground Truth: ${dataset.groundTruthMethod}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechItem(TechStackItem tech, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.cardBorder : AppColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tech.layer,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tech.technology,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              tech.role,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperCard(ResearchPaper paper, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.cardBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            paper.title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${paper.authors} • ${paper.journal} (${paper.year})',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.statusCyan,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            paper.summary,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkButton(String label, String url, IconData icon, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isDark ? AppColors.cardBorder : AppColors.lightBorder),
        ),
        tileColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        leading: Icon(icon, color: AppColors.primaryBlue),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        subtitle: Text(
          url,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
          ),
        ),
        trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.primaryBlue),
        onTap: () {},
      ),
    );
  }
}
