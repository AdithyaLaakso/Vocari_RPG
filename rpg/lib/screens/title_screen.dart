import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import 'character_creation_screen.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();

    return Scaffold(
      body: Stack(
        children: [
          // Animated background
          _buildAnimatedBackground(),

          // Main content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Title
                  _buildTitle(),

                  const SizedBox(height: 20),

                  // Subtitle
                  Text(
                    'A Slide-Based Adventure',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white54,
                          letterSpacing: 4,
                        ),
                  )
                      .animate()
                      .fadeIn(delay: 800.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0),

                  const Spacer(flex: 2),

                  // Loading or buttons
                  if (gameProvider.isLoading)
                    _buildLoadingIndicator()
                  else if (gameProvider.error != null)
                    _buildErrorWidget(gameProvider.error!)
                  else
                    _buildMenuButtons(context),

                  const Spacer(),

                  // Version
                  Text(
                    'Version 1.0.0',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white24,
                        ),
                  )
                      .animate()
                      .fadeIn(delay: 1500.ms, duration: 500.ms),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.5,
          colors: [
            Color(0xFF1A1A3E),
            Color(0xFF0F0F1A),
            Color(0xFF050510),
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _particleController,
        builder: (context, child) {
          return CustomPaint(
            painter: ParticlePainter(_particleController.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        // Crown icon
        const Text(
          '👑',
          style: TextStyle(fontSize: 60),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.1, 1.1),
              duration: 2.seconds,
              curve: Curves.easeInOut,
            )
            .shimmer(
              delay: 500.ms,
              duration: 2.seconds,
              color: const Color(0xFFD4AF37).withOpacity(0.3),
            ),

        const SizedBox(height: 20),

        // Main title
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFD4AF37),
              Color(0xFFFFD700),
              Color(0xFFD4AF37),
            ],
          ).createShader(bounds),
          child: Text(
            'REALM OF\nSHADOWS',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 48,
                  height: 1.2,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
          ),
        )
            .animate()
            .fadeIn(duration: 1.seconds)
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1))
            .shimmer(
              delay: 1.seconds,
              duration: 3.seconds,
              color: Colors.white.withOpacity(0.2),
            ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        const CircularProgressIndicator(
          strokeWidth: 2,
        ).animate(onPlay: (c) => c.repeat()).rotate(duration: 1.seconds),
        const SizedBox(height: 16),
        Text(
          'Loading world data...',
          style: Theme.of(context).textTheme.bodyMedium,
        ).animate().fadeIn(duration: 500.ms),
      ],
    );
  }

  Widget _buildErrorWidget(String error) {
    return Column(
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 16),
        Text(
          error,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.red,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            context.read<GameProvider>().loadGameData();
          },
          child: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildMenuButtons(BuildContext context) {
    return Column(
      children: [
        // New Game button
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const CharacterCreationScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      )),
                      child: child,
                    ),
                  );
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text('NEW GAME'),
        )
            .animate()
            .fadeIn(delay: 1000.ms, duration: 500.ms)
            .slideY(begin: 0.5, end: 0),

        const SizedBox(height: 16),

        // Continue button (disabled for now)
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.bookmark),
          label: const Text('CONTINUE'),
        )
            .animate()
            .fadeIn(delay: 1200.ms, duration: 500.ms)
            .slideY(begin: 0.5, end: 0),

        const SizedBox(height: 16),

        // Settings button
        TextButton.icon(
          onPressed: () {
            _showSettingsDialog(context);
          },
          icon: const Icon(Icons.settings, size: 20),
          label: const Text('SETTINGS'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white54,
          ),
        )
            .animate()
            .fadeIn(delay: 1400.ms, duration: 500.ms)
            .slideY(begin: 0.5, end: 0),
      ],
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.volume_up),
              title: const Text('Sound Effects'),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
                activeColor: const Color(0xFFD4AF37),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('Music'),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
                activeColor: const Color(0xFFD4AF37),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.vibration),
              title: const Text('Vibration'),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
                activeColor: const Color(0xFFD4AF37),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}

// Particle painter for animated background
class ParticlePainter extends CustomPainter {
  final double animationValue;

  ParticlePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4AF37).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Draw floating particles
    for (int i = 0; i < 30; i++) {
      final x = (size.width * ((i * 37) % 100) / 100);
      final baseY = (size.height * ((i * 53) % 100) / 100);
      final y = (baseY + (animationValue * 100) + (i * 20)) % size.height;
      final radius = 1.0 + (i % 3);

      paint.color = const Color(0xFFD4AF37).withOpacity(0.05 + (i % 5) * 0.02);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Draw some larger, glowing particles
    for (int i = 0; i < 10; i++) {
      final x = (size.width * ((i * 73) % 100) / 100);
      final baseY = (size.height * ((i * 41) % 100) / 100);
      final y = (baseY + (animationValue * 50) + (i * 40)) % size.height;
      final radius = 2.0 + (i % 2);

      paint.color = const Color(0xFF4A0E4E).withOpacity(0.1);
      canvas.drawCircle(Offset(x, y), radius + 2, paint);
      paint.color = const Color(0xFFD4AF37).withOpacity(0.15);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
