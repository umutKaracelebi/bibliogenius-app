import 'dart:math';
import 'package:flutter/material.dart';

import '../services/translation_service.dart';

/// A celebratory animation when the user levels up on a gamification track.
/// Use [LevelUpAnimation.show] to display it.
class LevelUpAnimation {
  /// Shows the level up animation.
  /// [newLevel] - The new level reached
  /// [trackName] - Name of the track (e.g., "Collector", "Reader")
  /// [trackColor] - Primary color of the track
  static void show(
    BuildContext context, {
    required int newLevel,
    required String trackName,
    required Color trackColor,
    IconData? trackIcon,
  }) {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _LevelUpAnimationWidget(
        newLevel: newLevel,
        trackName: trackName,
        trackColor: trackColor,
        trackIcon: trackIcon ?? Icons.arrow_upward,
        onComplete: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _LevelUpAnimationWidget extends StatefulWidget {
  final int newLevel;
  final String trackName;
  final Color trackColor;
  final IconData trackIcon;
  final VoidCallback onComplete;

  const _LevelUpAnimationWidget({
    required this.newLevel,
    required this.trackName,
    required this.trackColor,
    required this.trackIcon,
    required this.onComplete,
  });

  @override
  State<_LevelUpAnimationWidget> createState() =>
      _LevelUpAnimationWidgetState();
}

class _LevelUpAnimationWidgetState extends State<_LevelUpAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _numberAnimation;

  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Fade in/out
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 75),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_mainController);

    // Scale bounce
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.5,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 35,
      ),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 50),
    ]).animate(_mainController);

    // Text slide up
    _slideAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 50,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 70),
    ]).animate(_mainController);

    // Progress bar fill animation (starts empty, fills with flash)
    _progressAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.7,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 60),
    ]).animate(_mainController);

    // Number counter animation
    _numberAnimation =
        Tween<double>(
          begin: (widget.newLevel - 1).toDouble(),
          end: widget.newLevel.toDouble(),
        ).animate(
          CurvedAnimation(
            parent: _mainController,
            curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
          ),
        );

    // Generate rising particles
    _generateParticles();

    _mainController.forward().then((_) => widget.onComplete());
    _particleController.repeat();
  }

  void _generateParticles() {
    for (int i = 0; i < 20; i++) {
      _particles.add(
        _Particle(
          x: _random.nextDouble(),
          startY: 1.0 + _random.nextDouble() * 0.2,
          speed: _random.nextDouble() * 0.3 + 0.2,
          size: _random.nextDouble() * 6 + 2,
          delay: _random.nextDouble(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return ListenableBuilder(
      listenable: Listenable.merge([_mainController, _particleController]),
      builder: (context, _) {
        return Stack(
          children: [
            // Semi-transparent backdrop
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(
                    alpha: 0.5 * _fadeAnimation.value,
                  ),
                ),
              ),
            ),

            // Rising golden particles
            ..._buildParticles(screenSize),

            // Main content
            Center(
              child: IgnorePointer(
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // "LEVEL UP!" text
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                widget.trackColor,
                                Colors.amber,
                                widget.trackColor,
                              ],
                            ).createShader(bounds),
                            child: Text(
                              TranslationService.translate(
                                context,
                                'level_up',
                              ).toUpperCase(),
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 4,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    offset: Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Animated progress bar with flash
                          Container(
                            width: 200,
                            height: 12,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.white24,
                            ),
                            child: Stack(
                              children: [
                                // Progress fill
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _progressAnimation.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      gradient: LinearGradient(
                                        colors: [
                                          widget.trackColor,
                                          widget.trackColor.withValues(
                                            alpha: 0.8,
                                          ),
                                          Colors.amber,
                                        ],
                                      ),
                                      boxShadow: _progressAnimation.value >= 1.0
                                          ? [
                                              BoxShadow(
                                                color: Colors.amber.withValues(
                                                  alpha: 0.8,
                                                ),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                                // Flash effect when complete
                                if (_progressAnimation.value >= 0.99)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withValues(alpha: 0.0),
                                            Colors.white.withValues(alpha: 0.5),
                                            Colors.white.withValues(alpha: 0.0),
                                          ],
                                          stops: [0.0, 0.5, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Track info with animated level number
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.trackIcon,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                widget.trackName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Level number with animation
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.trackColor,
                                  widget.trackColor.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.trackColor.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Text(
                              'Level ${_numberAnimation.value.round()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Tap to dismiss
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _mainController.animateTo(
                    1.0,
                    duration: const Duration(milliseconds: 200),
                  );
                },
                behavior: HitTestBehavior.translucent,
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildParticles(Size screenSize) {
    final time = _particleController.value;

    return _particles.map((particle) {
      final adjustedTime = (time + particle.delay) % 1.0;
      final y = particle.startY - adjustedTime * particle.speed * 3;
      final opacity =
          (1.0 - adjustedTime).clamp(0.0, 1.0) * _fadeAnimation.value;

      return Positioned(
        left: particle.x * screenSize.width,
        top: y * screenSize.height,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: particle.size,
              height: particle.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _Particle {
  final double x;
  final double startY;
  final double speed;
  final double size;
  final double delay;

  _Particle({
    required this.x,
    required this.startY,
    required this.speed,
    required this.size,
    required this.delay,
  });
}
