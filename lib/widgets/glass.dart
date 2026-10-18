import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../store.dart';

/// Panel kaca (liquid glass): blur, kilau gradasi, dan tepi tipis.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 20,
    this.dark = false,
    this.blur = 22,
    this.padding,
  });

  final Widget child;
  final double radius;
  final bool dark;
  final double blur;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(dark ? 60 : 28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withAlpha(dark ? 46 : 166),
                  Colors.white.withAlpha(dark ? 16 : 92),
                ],
              ),
              border: Border.all(
                color: Colors.white.withAlpha(dark ? 56 : 190),
                width: 0.9,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlassCircle extends StatelessWidget {
  const GlassCircle({
    super.key,
    required this.icon,
    required this.dark,
    this.onTap,
    this.size = 44,
    this.iconColor,
    this.tint,
  });

  final IconData icon;
  final bool dark;
  final VoidCallback? onTap;
  final double size;
  final Color? iconColor;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final fg = iconColor ?? (dark ? Colors.white : const Color(0xFF111111));
    Widget content = SizedBox(
      width: size,
      height: size,
      child: Center(child: Icon(icon, size: size * 0.5, color: fg)),
    );
    if (tint != null) {
      content = DecoratedBox(
        decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
        child: content,
      );
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Glass(radius: size, dark: dark, blur: 18, child: content),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.file,
    required this.name,
    required this.color,
    this.size = 38,
  });

  final String? file;
  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = Store.resolve(file);
    if (path != null && File(path).existsSync()) {
      return ClipOval(
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: (size * 3).round(),
        ),
      );
    }
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withAlpha(255), color.withAlpha(190)],
        ),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
}
