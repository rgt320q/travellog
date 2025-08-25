
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<BitmapDescriptor> getCustomMarkerIcon(Color color, {double size = 100}) async {
  final PictureRecorder pictureRecorder = PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  final Paint paint = Paint()..color = color;
  final double radius = size / 2;

  canvas.drawCircle(Offset(radius, radius), radius, paint);

  final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await img.toByteData(format: ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
}
