import 'dart:math';

import 'package:flutter/material.dart';

class RadarView extends StatefulWidget {
  final int userCount;
  final VoidCallback onTap;
  final int selectedRadius;
  final bool isSearching;
  final bool hasSearched;
  final Map<String, dynamic>? usersData;

  const RadarView({
    super.key,
    required this.userCount,
    required this.onTap,
    required this.selectedRadius,
    required this.isSearching,
    required this.hasSearched,
    this.usersData,
  });

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final List<UserDot> _userDots = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseAnimation =
        Tween<double>(
          begin: 0.95,
          end: 1.05,
        ).animate(
          CurvedAnimation(
            parent: _pulseController,
            curve: Curves.easeInOut,
          ),
        );

    if (widget.isSearching) {
      _animationController.repeat();
      _pulseController.repeat(reverse: true);
    }

    _generateUserDots();
  }

  @override
  void didUpdateWidget(RadarView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isSearching && !oldWidget.isSearching) {
      _animationController.repeat();
      _pulseController.repeat(reverse: true);
    } else if (!widget.isSearching && oldWidget.isSearching) {
      _animationController.stop();
      _pulseController.stop();
      _animationController.value = 0;
      _pulseController.value = 0;
    }

    if (oldWidget.userCount != widget.userCount || oldWidget.usersData != widget.usersData) {
      _generateUserDots();
    }
  }

  Color _getColorForMatchScore(int matchScore) {
    if (matchScore > 80) {
      return Colors.white;
    } else if (matchScore >= 50) {
      return Colors.white;
    } else {
      return const Color(0xFFE74C3C);
    }
  }

  void _generateUserDots() {
    _userDots.clear();

    if (!widget.hasSearched || widget.usersData == null) {
      return;
    }

    final users = widget.usersData!['users'] as List<dynamic>? ?? [];
    final random = Random();
    final maxDistance = widget.selectedRadius.toDouble();

    for (var user in users) {
      final matchScore = user['match_score'] ?? 0;
      final userDistance = (user['distance'] ?? 0).toDouble();

      final angle = random.nextDouble() * 2 * pi;

      final normalizedDistance = (userDistance / maxDistance).clamp(0.2, 0.95);

      _userDots.add(
        UserDot(
          angle: angle,
          distance: normalizedDistance,
          animationOffset: random.nextDouble(),
          color: _getColorForMatchScore(matchScore),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 320,
        height: 320,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withOpacity(0.1),
              const Color(0xFF3D5A80).withOpacity(0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_animationController, _pulseAnimation]),
          builder: (context, child) {
            return CustomPaint(
              painter: RadarPainter(
                userDots: _userDots,
                animationValue: _animationController.value,
                pulseValue: _pulseAnimation.value,
              ),
              size: const Size(320, 320),
            );
          },
        ),
      ),
    );
  }
}

class UserDot {
  final double angle;
  final double distance;
  final double animationOffset;
  final Color color;

  UserDot({
    required this.angle,
    required this.distance,
    required this.animationOffset,
    this.color = Colors.white,
  });
}

class RadarPainter extends CustomPainter {
  final List<UserDot> userDots;
  final double animationValue;
  final double pulseValue;

  RadarPainter({
    required this.userDots,
    required this.animationValue,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final pulseOpacity = 0.1 + (0.15 * ((pulseValue - 0.95) / 0.1));
    final pulseGlowPaint = Paint()
      ..color = Colors.white.withOpacity(pulseOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(center, maxRadius * 0.33 * pulseValue, pulseGlowPaint);
    canvas.drawCircle(center, maxRadius * 0.66 * pulseValue, pulseGlowPaint);
    canvas.drawCircle(center, maxRadius * pulseValue, pulseGlowPaint);

    canvas.drawCircle(center, maxRadius * 0.33 * pulseValue, circlePaint);
    canvas.drawCircle(center, maxRadius * 0.66 * pulseValue, circlePaint);
    canvas.drawCircle(center, maxRadius * pulseValue, circlePaint);

    final centerIconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final centerPulseSize = 8 * pulseValue;
    canvas.drawCircle(center, centerPulseSize, centerIconPaint);

    final centerBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, centerPulseSize, centerBorderPaint);

    for (final dot in userDots) {
      final distance = dot.distance * maxRadius;
      final x = center.dx + distance * cos(dot.angle);
      final y = center.dy + distance * sin(dot.angle);

      final pulseValue = (animationValue + dot.animationOffset) % 1.0;
      final glowRadius = 12 + (pulseValue * 8);
      final glowOpacity = 0.3 * (1 - pulseValue);

      final glowPaint = Paint()
        ..color = dot.color.withOpacity(glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(Offset(x, y), glowRadius, glowPaint);

      final dotPaint = Paint()
        ..color = dot.color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 6, dotPaint);

      final dotBorderPaint = Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(Offset(x, y), 6, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.pulseValue != pulseValue || oldDelegate.userDots != userDots;
  }
}
