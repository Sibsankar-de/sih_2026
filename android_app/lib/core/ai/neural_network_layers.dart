import 'dart:math' as math;

/// Fast, vectorized neural network layer operations for mobile AI inference in Dart.
class NeuralNetworkLayers {
  /// 1D Convolution with 'same' zero-padding and stride 1.
  static List<List<double>> conv1dSame(
    List<List<double>> input,
    List<List<List<double>>> kernel,
    List<double> bias, {
    String activation = 'relu',
  }) {
    final int t = input.length;
    final int k = kernel.length;
    final int inChannels = kernel[0].length;
    final int outChannels = kernel[0][0].length;

    final int padTotal = k - 1;
    final int padLeft = padTotal ~/ 2;

    final output = List.generate(
      t,
      (_) => List<double>.filled(outChannels, 0.0),
      growable: false,
    );

    for (int step = 0; step < t; step++) {
      for (int outC = 0; outC < outChannels; outC++) {
        double sum = bias[outC];
        for (int kIdx = 0; kIdx < k; kIdx++) {
          final int inStep = step - padLeft + kIdx;
          if (inStep >= 0 && inStep < t) {
            final inRow = input[inStep];
            final kRow = kernel[kIdx];
            for (int inC = 0; inC < inChannels; inC++) {
              sum += inRow[inC] * kRow[inC][outC];
            }
          }
        }
        if (activation == 'relu') {
          output[step][outC] = sum > 0.0 ? sum : 0.0;
        } else {
          output[step][outC] = sum;
        }
      }
    }
    return output;
  }

  /// Batch Normalization: y = gamma * (x - mean) / sqrt(var + eps) + beta
  static List<List<double>> batchNorm(
    List<List<double>> input,
    List<double> gamma,
    List<double> beta,
    List<double> movingMean,
    List<double> movingVar, {
    double eps = 1e-3,
  }) {
    final int t = input.length;
    final int channels = gamma.length;

    final invStd = List<double>.generate(
      channels,
      (c) => gamma[c] / math.sqrt(movingVar[c] + eps),
      growable: false,
    );
    final offset = List<double>.generate(
      channels,
      (c) => beta[c] - movingMean[c] * invStd[c],
      growable: false,
    );

    final output = List.generate(
      t,
      (_) => List<double>.filled(channels, 0.0),
      growable: false,
    );

    for (int step = 0; step < t; step++) {
      final inRow = input[step];
      final outRow = output[step];
      for (int c = 0; c < channels; c++) {
        outRow[c] = inRow[c] * invStd[c] + offset[c];
      }
    }
    return output;
  }

  /// Global Average Pooling 1D: collapses (T, channels) -> (channels,)
  static List<double> globalAveragePooling1D(List<List<double>> input) {
    final int t = input.length;
    final int channels = input[0].length;
    final output = List<double>.filled(channels, 0.0);

    for (int step = 0; step < t; step++) {
      final inRow = input[step];
      for (int c = 0; c < channels; c++) {
        output[c] += inRow[c];
      }
    }
    final double invT = 1.0 / t;
    for (int c = 0; c < channels; c++) {
      output[c] *= invT;
    }
    return output;
  }

  /// Keras GRU unrolled forward pass (with reset_after = true).
  static List<double> gruUnrolled(
    List<List<double>> input,
    List<List<double>> kernel,
    List<List<double>> recurrentKernel,
    List<List<double>> bias,
  ) {
    final int t = input.length;
    final int inDim = kernel.length;
    final int units = recurrentKernel.length;

    final bInput = bias[0];
    final bRec = bias[1];

    List<double> h = List<double>.filled(units, 0.0);

    for (int step = 0; step < t; step++) {
      final x = input[step];

      final xz = List<double>.generate(units, (i) => bInput[i], growable: false);
      final xr = List<double>.generate(units, (i) => bInput[units + i], growable: false);
      final xh = List<double>.generate(units, (i) => bInput[2 * units + i], growable: false);

      for (int inC = 0; inC < inDim; inC++) {
        final double xv = x[inC];
        final kW = kernel[inC];
        for (int u = 0; u < units; u++) {
          xz[u] += xv * kW[u];
          xr[u] += xv * kW[units + u];
          xh[u] += xv * kW[2 * units + u];
        }
      }

      final hz = List<double>.generate(units, (i) => bRec[i], growable: false);
      final hr = List<double>.generate(units, (i) => bRec[units + i], growable: false);
      final hh = List<double>.generate(units, (i) => bRec[2 * units + i], growable: false);

      for (int u = 0; u < units; u++) {
        final double hv = h[u];
        final rU = recurrentKernel[u];
        for (int outU = 0; outU < units; outU++) {
          hz[outU] += hv * rU[outU];
          hr[outU] += hv * rU[units + outU];
          hh[outU] += hv * rU[2 * units + outU];
        }
      }

      final newH = List<double>.filled(units, 0.0);
      for (int u = 0; u < units; u++) {
        final double z = _sigmoid(xz[u] + hz[u]);
        final double r = _sigmoid(xr[u] + hr[u]);
        final double hCandidate = _tanh(xh[u] + r * hh[u]);
        newH[u] = z * h[u] + (1.0 - z) * hCandidate;
      }
      h = newH;
    }
    return h;
  }

  /// Fully connected Dense layer.
  static List<double> dense(
    List<double> input,
    List<List<double>> kernel,
    List<double> bias, {
    String activation = 'linear',
  }) {
    final int inDim = input.length;
    final int outDim = bias.length;
    final output = List<double>.filled(outDim, 0.0);

    for (int outIdx = 0; outIdx < outDim; outIdx++) {
      double sum = bias[outIdx];
      for (int inIdx = 0; inIdx < inDim; inIdx++) {
        sum += input[inIdx] * kernel[inIdx][outIdx];
      }
      output[outIdx] = sum;
    }

    if (activation == 'relu') {
      for (int i = 0; i < outDim; i++) {
        if (output[i] < 0.0) output[i] = 0.0;
      }
    } else if (activation == 'softmax') {
      double maxVal = output[0];
      for (int i = 1; i < outDim; i++) {
        if (output[i] > maxVal) maxVal = output[i];
      }
      double sumExp = 0.0;
      for (int i = 0; i < outDim; i++) {
        output[i] = math.exp(output[i] - maxVal);
        sumExp += output[i];
      }
      if (sumExp > 0.0) {
        final double invSum = 1.0 / sumExp;
        for (int i = 0; i < outDim; i++) {
          output[i] *= invSum;
        }
      }
    }
    return output;
  }

  static double _sigmoid(double x) {
    if (x >= 30.0) return 1.0;
    if (x <= -30.0) return 0.0;
    return 1.0 / (1.0 + math.exp(-x));
  }

  static double _tanh(double x) {
    if (x >= 20.0) return 1.0;
    if (x <= -20.0) return -1.0;
    final double e2x = math.exp(2.0 * x);
    return (e2x - 1.0) / (e2x + 1.0);
  }
}
