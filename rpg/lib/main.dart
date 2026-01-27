import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/game_provider.dart';
import 'screens/title_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const RPGGame());
}

class RPGGame extends StatelessWidget {
  const RPGGame({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameProvider()..loadGameData(),
      child: MaterialApp(
        title: 'Realm of Shadows',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFD4AF37), // Gold
            secondary: Color(0xFF8B4513), // Saddle Brown
            tertiary: Color(0xFF4A0E4E), // Purple
            surface: Color(0xFF1A1A2E),
            error: Color(0xFFCF6679),
          ),
          scaffoldBackgroundColor: const Color(0xFF0F0F1A),
          cardTheme: CardThemeData(
            color: const Color(0xFF1A1A2E),
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: const Color(0xFFD4AF37).withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          textTheme: GoogleFonts.cinzelTextTheme(
            ThemeData.dark().textTheme,
          ).copyWith(
            headlineLarge: GoogleFonts.cinzelDecorative(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFD4AF37),
            ),
            headlineMedium: GoogleFonts.cinzel(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFD4AF37),
            ),
            headlineSmall: GoogleFonts.cinzel(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            bodyLarge: GoogleFonts.lora(
              fontSize: 16,
              color: Colors.white70,
            ),
            bodyMedium: GoogleFonts.lora(
              fontSize: 14,
              color: Colors.white60,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: const Color(0xFF0F0F1A),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.cinzel(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD4AF37),
              side: const BorderSide(color: Color(0xFFD4AF37), width: 2),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.cinzel(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          iconTheme: const IconThemeData(
            color: Color(0xFFD4AF37),
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: Color(0xFFD4AF37),
          ),
        ),
        home: const TitleScreen(),
      ),
    );
  }
}
