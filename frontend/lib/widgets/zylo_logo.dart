import 'package:flutter/material.dart';
import '../app_colors.dart';

/// Reserves the spot where the real Zylo logo image will go.
///
/// Swap the `Text('Z', ...)` below for your actual asset once you have one,
/// e.g.:
///   Image.asset('assets/images/zylo_logo.png', width: size, height: size)
/// (remember to declare the asset under `flutter: assets:` in pubspec.yaml).
class ZyloMark extends StatelessWidget {
  final double size;

  const ZyloMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.accentGradient),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Text(
        'Z',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.52,
          height: 1,
        ),
      ),
    );
  }
}
