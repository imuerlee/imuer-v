import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlowBox extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double blurRadius;
  final double spreadRadius;
  final BorderRadius? borderRadius;

  const GlowBox({
    super.key,
    required this.child,
    this.glowColor = AppColors.primary,
    this.blurRadius = 20,
    this.spreadRadius = 2,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.3),
            blurRadius: blurRadius,
            spreadRadius: spreadRadius,
          ),
        ],
      ),
      child: child,
    );
  }
}

class SciFiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<Color>? gradientColors;
  final VoidCallback? onTap;
  final bool showGlow;

  const SciFiCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.gradientColors,
    this.onTap,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors ?? [
            AppColors.surface,
            AppColors.surface.withOpacity(0.8),
          ],
        ),
        border: Border.all(
          color: showGlow ? AppColors.primary.withOpacity(0.5) : AppColors.border,
          width: showGlow ? 2 : 1,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class NeonBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double borderWidth;
  final BorderRadius? borderRadius;

  const NeonBorder({
    super.key,
    required this.child,
    this.color = AppColors.primary,
    this.borderWidth = 2,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: Border.all(color: color, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}

class AnimatedPulse extends StatefulWidget {
  final Widget child;
  final Color pulseColor;
  final Duration duration;

  const AnimatedPulse({
    super.key,
    required this.child,
    this.pulseColor = AppColors.primary,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<AnimatedPulse> createState() => _AnimatedPulseState();
}

class _AnimatedPulseState extends State<AnimatedPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.pulseColor.withOpacity(_animation.value),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
