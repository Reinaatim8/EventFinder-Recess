import 'dart:ui';
import 'package:flutter/material.dart';

class BlurredDialog extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;

  const BlurredDialog({
    Key? key,
    required this.child,
    this.blurSigma = 10.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding = const EdgeInsets.all(20),
    this.backgroundColor = const Color.fromRGBO(255, 255, 255, 0.85),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blurred background
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            color: Colors.black.withOpacity(0.3),
          ),
        ),
        // Centered dialog content with stunning styling
        Center(
          child: Container(
            padding: padding,
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1.5,
              ),
              gradient: const LinearGradient(
                colors: [
                  Color.fromRGBO(255, 255, 255, 0.9),
                  Color.fromRGBO(245, 245, 255, 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}
