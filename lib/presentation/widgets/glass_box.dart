import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable glassmorphic container with backdrop blur, customizable opacity, and optional glow borders.
class GlassBox extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color color;
  final bool glowBorder;

  const GlassBox({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.opacity = 0.08,
    this.borderRadius = 24.0,
    this.padding,
    this.color = Colors.white,
    this.glowBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final themePrimary = Theme.of(context).colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: glowBorder
                  ? themePrimary.withValues(alpha: 0.18)
                  : color.withValues(alpha: 0.12),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
