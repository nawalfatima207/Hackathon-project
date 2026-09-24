import 'package:flutter/material.dart';

/// The Zylo logo, used in the search bar and on the login screen.
/// Backed by assets/images/zylo_logo.png -- declare it under
/// `flutter: assets:` in pubspec.yaml (see SETUP_NOTES.md).
class ZyloMark extends StatelessWidget {
  final double size;

  const ZyloMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/zylo_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
