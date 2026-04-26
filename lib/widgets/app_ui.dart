import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GradientShell extends StatelessWidget {
  final Widget child;

  const GradientShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.darkPageGradient : AppTheme.pageGradient,
      ),
      child: child,
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final Gradient? gradient;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderColor,
    this.gradient,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedColor =
        color ?? (isDark ? AppTheme.darkSurfaceCard : Colors.white);
    final resolvedBorder =
        borderColor ?? (isDark ? AppTheme.darkBorder : AppTheme.indigoBorder);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? resolvedColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: resolvedBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? AppTheme.brandGradient : null,
        color: enabled ? null : AppTheme.gray200,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppTheme.teal.withAlpha(35),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: padding,
            child: Center(
              child: Semantics(
                button: true,
                enabled: enabled,
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: enabled ? Colors.white : AppTheme.gray500,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  final double size;

  const BrandMark({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(Icons.bolt, color: Colors.white, size: size * 0.5),
    );
  }
}

class BrandHeader extends StatelessWidget {
  final Widget? trailing;
  final String? subtitle;

  const BrandHeader({super.key, this.trailing, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BrandMark(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fuel',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class AppPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const AppPill({
    super.key,
    required this.label,
    required this.color,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? color.withAlpha(28) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(95)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
