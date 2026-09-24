import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Google's standard 4-color "G" mark, for the "Continue with Google" button.
/// Rendered from inline SVG (Google's own published path data) rather than
/// an image asset, so there's nothing to add to pubspec's `assets:` list.
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 20});

  static const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#4285F4" d="M23.49 12.27c0-.79-.07-1.54-.19-2.27H12v4.51h6.47c-.29 1.48-1.14 2.73-2.4 3.58v2.84h3.86c2.26-2.09 3.56-5.17 3.56-8.66z"/>
  <path fill="#34A853" d="M12 24c3.24 0 5.95-1.08 7.93-2.91l-3.86-2.84c-1.08.73-2.46 1.16-4.07 1.16-3.13 0-5.78-2.11-6.72-4.96H1.29v3.09C3.25 21.3 7.31 24 12 24z"/>
  <path fill="#FBBC05" d="M5.28 14.45c-.25-.73-.38-1.5-.38-2.29s.14-1.56.38-2.29V6.78H1.29C.47 8.34 0 10.11 0 12s.47 3.66 1.29 5.22l3.99-3.09z"/>
  <path fill="#EA4335" d="M12 4.75c1.77 0 3.35.61 4.6 1.8l3.42-3.42C17.95 1.19 15.24 0 12 0 7.31 0 3.25 2.7 1.29 6.78l3.99 3.09c.94-2.85 3.59-4.96 6.72-4.96z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(_svg, width: size, height: size);
  }
}
