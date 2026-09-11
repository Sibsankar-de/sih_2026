import 'fusion_types.dart';

/// Optimized 8-state linear algebra routines for the Extended Kalman Filter.
class MatrixMath {
  /// Create an 8x8 identity matrix
  static List<double> identity8() {
    final m = List<double>.filled(64, 0.0);
    for (int i = 0; i < 8; i++) {
      m[i * 8 + i] = 1.0;
    }
    return m;
  }

  /// Create an 8x8 zero matrix
  static List<double> zeros8() => List<double>.filled(64, 0.0);

  /// 8x8 matrix multiplication: C = A * B
  static List<double> mul8x8(List<double> a, List<double> b) {
    final c = List<double>.filled(64, 0.0);
    for (int i = 0; i < 8; i++) {
      final int i8 = i * 8;
      for (int k = 0; k < 8; k++) {
        final double aik = a[i8 + k];
        if (aik == 0.0) continue;
        final int k8 = k * 8;
        for (int j = 0; j < 8; j++) {
          c[i8 + j] += aik * b[k8 + j];
        }
      }
    }
    return c;
  }

  /// C = A * B^T where A and B are 8x8
  static List<double> mul8x8TransposeB(List<double> a, List<double> b) {
    final c = List<double>.filled(64, 0.0);
    for (int i = 0; i < 8; i++) {
      final int i8 = i * 8;
      for (int j = 0; j < 8; j++) {
        final int j8 = j * 8;
        double sum = 0.0;
        for (int k = 0; k < 8; k++) {
          sum += a[i8 + k] * b[j8 + k];
        }
        c[i8 + j] = sum;
      }
    }
    return c;
  }

  /// Propagate covariance: P_next = F * P * F^T + Q
  static List<double> propagateCovariance(List<double> f, List<double> p, List<double> q) {
    final fp = mul8x8(f, p);
    final fpfT = mul8x8TransposeB(fp, f);
    final pNext = List<double>.filled(64, 0.0);
    for (int i = 0; i < 64; i++) {
      pNext[i] = fpfT[i] + q[i];
    }
    // Symmetrize
    for (int i = 0; i < 8; i++) {
      for (int j = i + 1; j < 8; j++) {
        final double avg = 0.5 * (pNext[i * 8 + j] + pNext[j * 8 + i]);
        pNext[i * 8 + j] = avg;
        pNext[j * 8 + i] = avg;
      }
    }
    return pNext;
  }

  /// 1D EKF Update using Joseph form:
  /// H: 1x8 row vector
  /// innovation: scalar z - h(x)
  /// R: scalar variance
  /// gateThreshold: chi-square limit
  static bool applyUpdate1D({
    required List<double> state,      // length 8 (in/out)
    required List<double> covariance, // 64 (in/out)
    required List<double> h,          // 8
    required double innovation,
    required double r,
    required double gateThreshold,
  }) {
    // 1. S = H * P * H^T + R
    // First compute PHt = P * H^T (8x1 vector)
    final pht = List<double>.filled(8, 0.0);
    for (int i = 0; i < 8; i++) {
      final int i8 = i * 8;
      double sum = 0.0;
      for (int j = 0; j < 8; j++) {
        sum += covariance[i8 + j] * h[j];
      }
      pht[i] = sum;
    }

    double s = r;
    for (int j = 0; j < 8; j++) {
      s += h[j] * pht[j];
    }

    if (s <= 1e-15 || !s.isFinite) return false;

    // 2. Innovation gating: d^2 = innovation^2 / S
    final double d2 = (innovation * innovation) / s;
    if (gateThreshold > 0.0 && gateThreshold.isFinite && d2 > gateThreshold) {
      return false; // rejected by gate
    }

    // 3. Kalman Gain K = P * H^T / S (8x1 vector)
    final double invS = 1.0 / s;
    final k = List<double>.generate(8, (i) => pht[i] * invS, growable: false);

    // 4. Update state: x = x + K * innovation
    for (int i = 0; i < 8; i++) {
      state[i] += k[i] * innovation;
    }
    state[kIdxYaw] = wrapAngle(state[kIdxYaw]);

    // 5. Joseph form: P = (I - K*H) * P * (I - K*H)^T + K * R * K^T
    // I_KH = I - K*H (8x8)
    final ikh = identity8();
    for (int i = 0; i < 8; i++) {
      final int i8 = i * 8;
      final double ki = k[i];
      for (int j = 0; j < 8; j++) {
        ikh[i8 + j] -= ki * h[j];
      }
    }

    final ikhP = mul8x8(ikh, covariance);
    final ikhPIkhT = mul8x8TransposeB(ikhP, ikh);

    for (int i = 0; i < 8; i++) {
      final int i8 = i * 8;
      for (int j = 0; j < 8; j++) {
        covariance[i8 + j] = ikhPIkhT[i8 + j] + k[i] * r * k[j];
      }
    }

    // Symmetrize and bound covariance
    _validateAndSymmetrize(covariance);
    return true;
  }

  /// 2D EKF Update using Joseph form:
  /// H: 2x8 (flattened 16)
  /// innovation: 2-element vector
  /// R: 2x2 diagonal variance [r0, r1]
  /// gateThreshold: chi-square limit
  static bool applyUpdate2D({
    required List<double> state,      // length 8 (in/out)
    required List<double> covariance, // 64 (in/out)
    required List<double> h,          // 16: row0=h[0..7], row1=h[8..15]
    required List<double> innovation, // 2
    required List<double> rDiag,      // 2: r[0], r[1]
    required double gateThreshold,
  }) {
    // 1. PHt = P * H^T (8x2)
    final pht0 = List<double>.filled(8, 0.0);
    final pht1 = List<double>.filled(8, 0.0);
    for (int i = 0; i < 8; i++) {
      final int i8 = i * 8;
      double s0 = 0.0;
      double s1 = 0.0;
      for (int j = 0; j < 8; j++) {
        final double pij = covariance[i8 + j];
        s0 += pij * h[j];
        s1 += pij * h[8 + j];
      }
      pht0[i] = s0;
      pht1[i] = s1;
    }

    // 2. S = H * PHt + R (2x2)
    double s00 = rDiag[0];
    double s01 = 0.0;
    double s10 = 0.0;
    double s11 = rDiag[1];

    for (int j = 0; j < 8; j++) {
      s00 += h[j] * pht0[j];
      s01 += h[j] * pht1[j];
      s10 += h[8 + j] * pht0[j];
      s11 += h[8 + j] * pht1[j];
    }

    // 2x2 Inversion
    final double det = s00 * s11 - s01 * s10;
    if (det.abs() <= 1e-15 || !det.isFinite) return false;

    final double invDet = 1.0 / det;
    final double invS00 = s11 * invDet;
    final double invS01 = -s01 * invDet;
    final double invS10 = -s10 * invDet;
    final double invS11 = s00 * invDet;

    // 3. Mahalanobis distance: d^2 = inn^T * S^(-1) * inn
    final double inn0 = innovation[0];
    final double inn1 = innovation[1];
    final double sinvInn0 = invS00 * inn0 + invS01 * inn1;
    final double sinvInn1 = invS10 * inn0 + invS11 * inn1;
    final double d2 = inn0 * sinvInn0 + inn1 * sinvInn1;

    if (gateThreshold > 0.0 && gateThreshold.isFinite && d2 > gateThreshold) {
      return false; // rejected by gate
    }

    // 4. Kalman Gain K = PHt * S^(-1) (8x2)
    final k0 = List<double>.filled(8, 0.0);
    final k1 = List<double>.filled(8, 0.0);
    for (int i = 0; i < 8; i++) {
      k0[i] = pht0[i] * invS00 + pht1[i] * invS10;
      k1[i] = pht0[i] * invS01 + pht1[i] * invS11;
    }

    // 5. Update state: x = x + K * innovation
    for (int i = 0; i < 8; i++) {
      state[i] += k0[i] * inn0 + k1[i] * inn1;
    }
    state[kIdxYaw] = wrapAngle(state[kIdxYaw]);

    // 6. Joseph form: P = (I - K*H) * P * (I - K*H)^T + K * R * K^T
    // I_KH = I - (K0*H0 + K1*H1) (8x8)
    final ikh = identity8();
    for (int i = 0; i < 8; i++) {
      final int i8 = i * 8;
      final double ki0 = k0[i];
      final double ki1 = k1[i];
      for (int j = 0; j < 8; j++) {
        ikh[i8 + j] -= (ki0 * h[j] + ki1 * h[8 + j]);
      }
    }

    final ikhP = mul8x8(ikh, covariance);
    final ikhPIkhT = mul8x8TransposeB(ikhP, ikh);

    final double r0 = rDiag[0];
    final double r1 = rDiag[1];
    for (int i = 0; i < 8; i++) {
      final int i8 = i * 8;
      for (int j = 0; j < 8; j++) {
        covariance[i8 + j] = ikhPIkhT[i8 + j] + (k0[i] * r0 * k0[j] + k1[i] * r1 * k1[j]);
      }
    }

    _validateAndSymmetrize(covariance);
    return true;
  }

  static void _validateAndSymmetrize(List<double> p) {
    for (int i = 0; i < 8; i++) {
      final int ii = i * 8 + i;
      if (!p[ii].isFinite) {
        p[ii] = 1.0;
      } else if (p[ii] < 1e-15) {
        p[ii] = 1e-15;
      } else if (p[ii] > 1e10) {
        p[ii] = 1e10;
      }
      for (int j = i + 1; j < 8; j++) {
        final int ij = i * 8 + j;
        final int ji = j * 8 + i;
        if (!p[ij].isFinite || !p[ji].isFinite) {
          p[ij] = 0.0;
          p[ji] = 0.0;
        } else {
          final double avg = 0.5 * (p[ij] + p[ji]);
          p[ij] = avg;
          p[ji] = avg;
        }
      }
    }
  }
}
