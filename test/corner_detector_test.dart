import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:measure_reality/measure/corner_detector.dart';

Uint8List _image(int w, int h, int Function(int x, int y) f, {int stride = 0}) {
  final s = stride == 0 ? w : stride;
  final out = Uint8List(s * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      out[y * s + x] = f(x, y);
    }
  }
  return out;
}

void main() {
  test('finds the four corners of a bright square', () {
    final img = _image(160, 120, (x, y) => (x >= 60 && x < 100 && y >= 40 && y < 80) ? 220 : 30);
    final r = CornerDetector.detect(img, 160, 120, 160);
    expect(r.corners.length, 4);
    const targets = [
      [60 / 160, 40 / 120],
      [100 / 160, 40 / 120],
      [60 / 160, 80 / 120],
      [100 / 160, 80 / 120],
    ];
    for (final t in targets) {
      final near = r.corners.any((c) => (c.x - t[0]).abs() < 0.03 && (c.y - t[1]).abs() < 0.04);
      expect(near, isTrue, reason: 'no corner near $t');
    }
  });

  test('works when rows are padded (stride larger than width)', () {
    final img = _image(160, 120, (x, y) => (x >= 60 && x < 100 && y >= 40 && y < 80) ? 220 : 30, stride: 192);
    expect(CornerDetector.detect(img, 160, 120, 192).corners.length, 4);
  });

  test('flat wall: no corners', () {
    final img = _image(160, 120, (x, y) => 128);
    expect(CornerDetector.detect(img, 160, 120, 160).corners, isEmpty);
  });

  test('a single straight edge is not a corner', () {
    final img = _image(160, 120, (x, y) => x > 80 ? 220 : 30);
    expect(CornerDetector.detect(img, 160, 120, 160).corners, isEmpty);
  });

  test('finds the corners of a SOFT, low-contrast, noisy shape (like a real room)', () {
    double ramp(double t) => t < 0 ? 0 : (t > 1 ? 1 : t);
    final img = _image(160, 120, (x, y) {
      final ax = ramp((x - 60) / 6.0) * (1 - ramp((x - 100) / 6.0));
      final ay = ramp((y - 40) / 6.0) * (1 - ramp((y - 80) / 6.0));
      final noise = (x * 7919 + y * 104729) % 7 - 3;
      return (110 + 25 * ax * ay + noise).round().clamp(0, 255).toInt();
    });
    final r = CornerDetector.detect(img, 160, 120, 160);
    expect(r.corners.length, greaterThanOrEqualTo(4));
    const targets = [
      [60 / 160, 40 / 120],
      [100 / 160, 40 / 120],
      [60 / 160, 80 / 120],
      [100 / 160, 80 / 120],
    ];
    for (final t in targets) {
      final near = r.corners.any((c) => (c.x - t[0]).abs() < 0.07 && (c.y - t[1]).abs() < 0.09);
      expect(near, isTrue, reason: 'no corner near $t');
    }
  });

  test('camera noise alone gives no corners', () {
    final img = _image(320, 240, (x, y) => 128 + ((x * 7919 + y * 104729) % 15) - 7);
    expect(CornerDetector.detect(img, 320, 240, 320).corners, isEmpty);
  });

  test('reports brightness', () {
    final img = _image(160, 120, (x, y) => 100);
    expect(CornerDetector.detect(img, 160, 120, 160).brightness, closeTo(100, 0.5));
  });
}
