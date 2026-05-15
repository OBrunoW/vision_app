import 'package:flutter/material.dart';

class StreamingScreen extends StatelessWidget {
  const StreamingScreen({
    super.key,
    required this.rtmpBaseUrl,
    required this.cameraName,
  });

  final String rtmpBaseUrl;
  final String cameraName;

  @override
  Widget build(BuildContext context) {
    return const Scaffold();
  }
}
