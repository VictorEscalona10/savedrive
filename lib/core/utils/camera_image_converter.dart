import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

abstract final class CameraImageConverter {
  static InputImage? convertCameraImageToInputImage({
    required CameraImage image,
    required CameraDescription description,
  }) {
    if (image.planes.isEmpty) return null;

    final sensorOrientation = description.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else {
      var rotationCompensation = 0; // Dispositivo en posición vertical (portraitUp = 0°)
      if (description.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    rotation ??= InputImageRotation.rotation270deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        (Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888);

    final bytes = concatenatePlanes(image);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  static Uint8List concatenatePlanes(CameraImage image) {
    if (image.planes.isEmpty) return Uint8List(0);
    if (image.planes.length == 1) {
      return image.planes[0].bytes;
    }
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final byteData = allBytes.done();
    return byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
  }
}
