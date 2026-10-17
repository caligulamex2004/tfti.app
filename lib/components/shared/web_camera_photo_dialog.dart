import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'web_camera_photo_stub.dart'
    if (dart.library.html) 'web_camera_photo_web.dart';

class WebCameraPhotoDialog {
  static Future<Uint8List?> show(BuildContext context) {
    return showWebCameraPhotoDialog(context);
  }
}
