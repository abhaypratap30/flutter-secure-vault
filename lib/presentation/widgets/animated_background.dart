import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// A sleek, glassmorphic animated background widget rendering fluid glowing aurora blobs.
class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final scaffoldBg = theme.scaffoldBackgroundColor;
    final accentColor = theme.colorScheme.secondary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;

        // Float positions using trigonometry
        final blob1X = 0.25 + 0.18 * math.sin(t);
        final blob1Y = 0.25 + 0.18 * math.cos(t);

        final blob2X = 0.70 + 0.18 * math.cos(t + math.pi);
        final blob2Y = 0.70 + 0.18 * math.sin(t + math.pi);

        final size = MediaQuery.of(context).size;

        return Stack(
          children: [
            // Dark base background
            Container(color: scaffoldBg),

            // Moving Glowing Aurora Blob 1
            Positioned(
              left: (blob1X * size.width) - 175,
              top: (blob1Y * size.height) - 175,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.16),
                      primaryColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Moving Glowing Aurora Blob 2
            Positioned(
              left: (blob2X * size.width) - 200,
              top: (blob2Y * size.height) - 200,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.12),
                      accentColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Glassmorphic Backdrop Blur overlay
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.18),
                ),
              ),
            ),

            // Main screen content
            widget.child,
          ],
        );
      },
    );
  }
}
