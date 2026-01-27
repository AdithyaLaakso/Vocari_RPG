import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import 'game_screen.dart';

class CharacterCreationScreen extends StatefulWidget {
  const CharacterCreationScreen({super.key});

  @override
  State<CharacterCreationScreen> createState() => _CharacterCreationScreenState();
}

class _CharacterCreationScreenState extends State<CharacterCreationScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Begin Your Journey'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, Traveler',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),

                    const SizedBox(height: 8),

                    Text(
                      'You are about to embark on a journey to learn a new language through adventure.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white54,
                      ),
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                    const SizedBox(height: 40),

                    // Character preview
                    Center(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFD4AF37).withOpacity(0.4),
                              const Color(0xFF4A0E4E).withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFFD4AF37),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '\u{1F30D}',
                            style: TextStyle(fontSize: 64),
                          ),
                        ),
                      ).animate()
                          .fadeIn(delay: 300.ms, duration: 500.ms)
                          .scale(begin: const Offset(0.8, 0.8)),
                    ),

                    const SizedBox(height: 40),

                    // Name input section
                    Text(
                      'What is your name?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFD4AF37),
                      ),
                    ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

                    const SizedBox(height: 16),

                    TextField(
                      controller: _nameController,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                      decoration: InputDecoration(
                        hintText: 'Enter your name...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color(0xFFD4AF37).withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color(0xFFD4AF37).withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFD4AF37),
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ).animate().fadeIn(delay: 500.ms, duration: 400.ms).slideY(begin: 0.2),

                    const SizedBox(height: 16),

                    // Name suggestions
                    Center(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          'Alex', 'Luna', 'Marco', 'Sofia', 'Kai', 'Elena'
                        ].map((name) => ActionChip(
                          label: Text(name),
                          onPressed: () {
                            _nameController.text = name;
                            setState(() {});
                          },
                          backgroundColor: Colors.white.withOpacity(0.05),
                          side: BorderSide(
                            color: const Color(0xFFD4AF37).withOpacity(0.3),
                          ),
                        )).toList(),
                      ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
                    ),

                    const SizedBox(height: 40),

                    // Language level info
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.school, color: Color(0xFFD4AF37)),
                              const SizedBox(width: 12),
                              Text(
                                'Starting Level: A0',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'You will begin as a complete beginner. As you interact with NPCs and complete quests, your language skills will improve!',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 700.ms, duration: 400.ms).slideY(begin: 0.1),
                  ],
                ),
              ),
            ),

            // Begin button
            _buildBeginButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBeginButton() {
    final canProceed = _nameController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: canProceed ? _handleBegin : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('BEGIN ADVENTURE'),
        ),
      ),
    );
  }

  void _handleBegin() {
    final gameProvider = context.read<GameProvider>();
    gameProvider.createNewCharacter(_nameController.text.trim());

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GameScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }
}
