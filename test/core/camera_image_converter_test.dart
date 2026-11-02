import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safedrive/core/utils/camera_image_converter.dart';

class FakePlane extends Fake implements Plane {
  @override
  final Uint8List bytes;
  @override
  final int bytesPerRow;
  @override
  final int? bytesPerPixel;
  @override
  final int? width;
  @override
  final int? height;

  FakePlane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel = 1,
    this.width,
    this.height,
  });
}

class FakeCameraImage extends Fake implements CameraImage {
  @override
  final int width;
  @override
  final int height;
  @override
  final List<Plane> planes;

  FakeCameraImage({
    required this.width,
    required this.height,
    required this.planes,
  });
}

void main() {
  group('CameraImageConverter - Utilidad de conversión desacoplada', () {
    test('concatenatePlanes une los bytes de todos los planos usando WriteBuffer', () {
      final yBytes = Uint8List.fromList([1, 2, 3, 4]);
      final uBytes = Uint8List.fromList([5, 6]);
      final vBytes = Uint8List.fromList([7, 8]);

      final image = FakeCameraImage(
        width: 2,
        height: 2,
        planes: [
          FakePlane(bytes: yBytes, bytesPerRow: 2),
          FakePlane(bytes: uBytes, bytesPerRow: 1),
          FakePlane(bytes: vBytes, bytesPerRow: 1),
        ],
      );

      final combined = CameraImageConverter.concatenatePlanes(image);
      expect(combined.length, equals(8));
      expect(combined, equals([1, 2, 3, 4, 5, 6, 7, 8]));
    });

    test('concatenatePlanes con 1 solo plano devuelve directamente los bytes', () {
      final bytes = Uint8List.fromList([10, 20, 30]);
      final image = FakeCameraImage(
        width: 3,
        height: 1,
        planes: [FakePlane(bytes: bytes, bytesPerRow: 3)],
      );

      final result = CameraImageConverter.concatenatePlanes(image);
      expect(result, equals(bytes));
    });
  });
}
