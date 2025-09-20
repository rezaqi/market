import 'package:flutter/material.dart';
import 'package:market/core/class/app_color.dart';

class GlowingTitle extends StatefulWidget {
  const GlowingTitle({super.key});

  @override
  State<GlowingTitle> createState() => _GlowingTitleState();
}

class _GlowingTitleState extends State<GlowingTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = 15 + (_controller.value * 25);

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 50, vertical: 30),
          decoration: BoxDecoration(
            color: AppColors.thi,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(100),
              bottomRight: Radius.circular(100),
            ),
            border: Border.all(color: AppColors.pri, width: 10),
          ),
          child: Text(
            "ماركت نور العالم",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 55,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: glow,
                  color: AppColors.pri.withOpacity(0.8),
                  offset: const Offset(0, 0),
                ),
                Shadow(
                  blurRadius: glow * 1.5,
                  color: AppColors.thi.withOpacity(0.7),
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
