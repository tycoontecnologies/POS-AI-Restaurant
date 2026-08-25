import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Current Tycoon POS branding supplied by Tycoon Technologies.
/// Embedded to keep production web builds independent from legacy image assets.
class TycoonPosBrand {
  TycoonPosBrand._();

  static Uint8List? _bytes;
  static Uint8List get bytes => _bytes ??= base64Decode(_logoBase64);

  static const String productName = 'TYCOON POS';
  static const String companyName = 'Tycoon Technologies (Pvt.) Ltd.';

  static const String _logoBase64 = '__B64__';
}

class TycoonPosLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const TycoonPosLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.memory(
      TycoonPosBrand.bytes,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const Center(
        child: Text(
          TycoonPosBrand.productName,
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
    return borderRadius == null ? image : ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
