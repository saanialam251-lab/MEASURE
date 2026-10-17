import 'dart:math' as math;
import 'dart:typed_data';

/// A detected corner, in normalised IMAGE coordinates (0..1).
class Corner {
  final double x, y, score;
  const Corner(this.x, this.y, this.score);
}

class DetectResult {
  final List<Corner> corners;
  final double brightness; // 0..255 mean luma
  const DetectResult(this.corners, this.brightness);
}

/// Shi-Tomasi corner detector on a block-averaged luma plane.
///
/// 1. Average blocks of pixels (removes camera noise, makes it fast).
/// 2. Sobel gradients.
/// 3. Structure tensor over a 3x3 window; the corner strength is its SMALLER
///    eigenvalue, so straight edges (one big eigenvalue) are rejected and only
///    real corners (two big eigenvalues) survive.
/// 4. Keep only corners well above the image's own noise level, that are local
///    maxima and well separated.
class CornerDetector {
  /// Smallest corner strength ever accepted. The real limit adapts to each image:
  /// a corner must be at least 10x stronger than the image's typical (median)
  /// corner strength, which is just camera noise. Pure noise never reaches 8x.
  static const double _absFloor = 300.0;

  static DetectResult detect(Uint8List luma, int w, int h, int stride) {
    final step = math.max(2, w ~/ 120);
    final gw = w ~/ step, gh = h ~/ step;
    if (gw < 12 || gh < 12) return const DetectResult([], 128);
    final sub = math.max(1, step ~/ 4);

    // 1) block average
    final g = Float32List(gw * gh);
    var sum = 0.0;
    for (var y = 0; y < gh; y++) {
      for (var x = 0; x < gw; x++) {
        var acc = 0.0;
        var n = 0;
        for (var sy = 0; sy < step; sy += sub) {
          final row = (y * step + sy) * stride + x * step;
          for (var sx = 0; sx < step; sx += sub) {
            final idx = row + sx;
            if (idx < luma.length) {
              acc += luma[idx];
              n++;
            }
          }
        }
        final v = n == 0 ? 0.0 : acc / n;
        g[y * gw + x] = v;
        sum += v;
      }
    }
    final brightness = sum / (gw * gh);

    // 2) Sobel gradients
    final ix = Float32List(gw * gh);
    final iy = Float32List(gw * gh);
    for (var y = 2; y < gh - 2; y++) {
      for (var x = 2; x < gw - 2; x++) {
        final i = y * gw + x;
        ix[i] = (g[i - gw + 1] + 2 * g[i + 1] + g[i + gw + 1]) -
            (g[i - gw - 1] + 2 * g[i - 1] + g[i + gw - 1]);
        iy[i] = (g[i + gw - 1] + 2 * g[i + gw] + g[i + gw + 1]) -
            (g[i - gw - 1] + 2 * g[i - gw] + g[i - gw + 1]);
      }
    }

    // 3) smaller eigenvalue of the structure tensor (Shi-Tomasi)
    final r = Float32List(gw * gh);
    var maxR = 0.0;
    for (var y = 4; y < gh - 4; y++) {
      for (var x = 4; x < gw - 4; x++) {
        var sxx = 0.0, syy = 0.0, sxy = 0.0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final j = (y + dy) * gw + (x + dx);
            final a = ix[j], b = iy[j];
            sxx += a * a;
            syy += b * b;
            sxy += a * b;
          }
        }
        final diff = sxx - syy;
        final disc = math.sqrt(math.max(0.0, diff * diff + 4 * sxy * sxy));
        final v = 0.5 * (sxx + syy - disc);
        r[y * gw + x] = v;
        if (v > maxR) maxR = v;
      }
    }
    // noise floor = median corner strength of the whole picture
    final inner = Float32List((gh - 8) * (gw - 8));
    var k = 0;
    for (var y = 4; y < gh - 4; y++) {
      for (var x = 4; x < gw - 4; x++) {
        inner[k++] = r[y * gw + x];
      }
    }
    inner.sort();
    final noiseFloor = math.max(inner[inner.length ~/ 2] * 10.0, _absFloor);
    if (maxR < noiseFloor) return DetectResult(const [], brightness);

    // 4) strong local maxima, best first, well separated
    final thr = math.max(maxR * 0.06, noiseFloor);
    final cand = <Corner>[];
    for (var y = 6; y < gh - 6; y++) {
      for (var x = 6; x < gw - 6; x++) {
        final v = r[y * gw + x];
        if (v < thr) continue;
        var isMax = true;
        for (var dy = -2; dy <= 2 && isMax; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
            if (dx == 0 && dy == 0) continue;
            if (r[(y + dy) * gw + (x + dx)] > v) {
              isMax = false;
              break;
            }
          }
        }
        if (isMax) {
          cand.add(Corner((x * step + step / 2) / w, (y * step + step / 2) / h, v / maxR));
        }
      }
    }
    cand.sort((a, b) => b.score.compareTo(a.score));
    final out = <Corner>[];
    for (final c in cand) {
      var ok = true;
      for (final o in out) {
        final dx = (o.x - c.x) * w / step, dy = (o.y - c.y) * h / step;
        if (dx * dx + dy * dy < 25) {
          ok = false;
          break;
        }
      }
      if (ok) out.add(c);
      if (out.length >= 20) break;
    }
    return DetectResult(out, brightness);
  }
}
