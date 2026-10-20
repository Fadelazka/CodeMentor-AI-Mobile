import 'dart:math';
import 'package:flutter/material.dart';

class CodeMeteorsBackground extends StatefulWidget {
  final Widget child;
  const CodeMeteorsBackground({super.key, required this.child});

  @override
  State<CodeMeteorsBackground> createState() => _CodeMeteorsBackgroundState();
}

class _CodeMeteorsBackgroundState extends State<CodeMeteorsBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Meteor> _meteors = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    for (var i = 0; i < 20; i++) {
      _meteors.add(_Meteor.random(_random));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: Colors.black),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _MeteorPainter(_meteors, _controller.value),
                size: Size.infinite,
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Meteor {
  double x;
  double y;
  double length;
  double speed;
  double opacity;
  _Meteor(this.x, this.y, this.length, this.speed, this.opacity);

  static _Meteor random(Random rand) {
    return _Meteor(
      rand.nextDouble() * 2 - 0.5,
      rand.nextDouble() * 1.2 - 0.2,
      30 + rand.nextDouble() * 60,
      0.0008 + rand.nextDouble() * 0.0015,
      0.2 + rand.nextDouble() * 0.4,
    );
  }
}

class _MeteorPainter extends CustomPainter {
  final List<_Meteor> meteors;
  final double t;
  _MeteorPainter(this.meteors, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final m in meteors) {
      final progress = (t + m.speed * 1000) % 1.0;
      final startX = m.x * size.width + progress * size.width * 0.5;
      final startY = m.y * size.height + progress * size.height * 0.6;
      final endX = startX - m.length * cos(-pi / 4);
      final endY = startY - m.length * sin(-pi / 4);
      
      paint.shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: m.opacity),
          Colors.cyan.withValues(alpha: m.opacity * 0.5),
          Colors.transparent,
        ],
      ).createShader(Rect.fromPoints(Offset(startX, startY), Offset(endX, endY)));
      
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeteorPainter oldDelegate) => true;
}
