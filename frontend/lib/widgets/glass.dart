import 'dart:ui';
import 'package:flutter/material.dart';
import '../app_colors.dart';

/// A frosted-glass panel: blurred backdrop + translucent fill + thin
/// light border + soft shadow. This is the one visual building block
/// every "translucent button/card" in the app should be built from,
/// so the glass effect stays consistent everywhere.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final Color fill;
  final Color border;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradientFill;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blur = 18,
    this.fill = AppColors.glassFill,
    this.border = AppColors.glassBorder,
    this.padding,
    this.gradientFill,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: gradientFill == null ? fill : null,
            gradient: gradientFill,
            borderRadius: borderRadius,
            border: Border.all(color: border, width: 1),
            boxShadow: const [
              BoxShadow(color: AppColors.glassShadow, blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A tappable glass "chip" / icon button — the translucent circular
/// buttons seen in the reference (menu button, notification bell, etc).
class GlassIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final double size;
  final Color fill;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 44,
    this.fill = AppColors.glassFill,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(size),
      fill: fill,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

/// A full glass card used for list items / content blocks, with a
/// gentle press ripple built in.
class GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color fill;
  final Color border;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.fill = AppColors.glassFill,
    this.border = AppColors.glassBorder,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: borderRadius,
      fill: fill,
      border: border,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Pill-shaped glass button with a gradient-filled variant for primary
/// actions (e.g. "Get Started", send button).
class GlassGradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const GlassGradientButton({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.accentGradient),
            borderRadius: BorderRadius.circular(30),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
