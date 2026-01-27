import 'dart:math';
import '../language_system.dart';

/// Service for managing bilingual text display with level-based language shifting.
///
/// As the player progresses in their language learning journey, text elements
/// shift from primarily native language to primarily target language.
class BilingualTextService {
  static final BilingualTextService _instance = BilingualTextService._internal();
  static BilingualTextService get instance => _instance;

  BilingualTextService._internal();

  final Random _random = Random();

  // Language configuration (extensible for future languages)
  String _nativeLanguage = 'en';
  String _targetLanguage = 'es';

  String get nativeLanguage => _nativeLanguage;
  String get targetLanguage => _targetLanguage;

  /// Set the language pair
  void setLanguages({required String native, required String target}) {
    _nativeLanguage = native;
    _targetLanguage = target;
  }

  /// Get the probability of showing target language based on CEFR level.
  /// Returns a value between 0.0 (always native) and 1.0 (always target).
  double getTargetLanguageProbability(String level) {
    switch (level.toUpperCase()) {
      case 'A0':
        return 0.05;  // 5% target language
      case 'A0+':
        return 0.15;  // 15% target language
      case 'A1':
        return 0.30;  // 30% target language
      case 'A1+':
        return 0.45;  // 45% target language
      case 'A2':
        return 0.60;  // 60% target language
      case 'A2+':
        return 0.70;  // 70% target language
      case 'B1':
        return 0.80;  // 80% target language
      case 'B1+':
        return 0.85;  // 85% target language
      case 'B2':
        return 0.90;  // 90% target language
      case 'B2+':
        return 0.92;  // 92% target language
      case 'C1':
        return 0.95;  // 95% target language
      case 'C1+':
        return 0.97;  // 97% target language
      case 'C2':
        return 0.99;  // 99% target language
      default:
        return 0.10;  // Default to mostly native
    }
  }

  /// Determine which language to display based on player level.
  /// Returns true if target language should be shown.
  bool shouldShowTargetLanguage(String level) {
    final probability = getTargetLanguageProbability(level);
    return _random.nextDouble() < probability;
  }

  /// Get the appropriate text from a localized pair based on player level.
  /// Uses weighted randomness to shift language over time.
  String getTextForLevel({
    required String nativeText,
    required String targetText,
    required String level,
    bool forceNative = false,
    bool forceTarget = false,
  }) {
    if (forceNative) return nativeText;
    if (forceTarget) return targetText;

    return shouldShowTargetLanguage(level) ? targetText : nativeText;
  }

  /// Get bilingual text with both versions shown.
  /// Format: "targetText (nativeText)" or "nativeText" based on level.
  String getBilingualText({
    required String nativeText,
    required String targetText,
    required String level,
    bool alwaysShowBoth = false,
  }) {
    if (alwaysShowBoth) {
      return '$targetText ($nativeText)';
    }

    final showTarget = shouldShowTargetLanguage(level);
    if (showTarget) {
      // Show target with native hint in parentheses
      return '$targetText ($nativeText)';
    } else {
      // Show native with target hint in parentheses
      return '$nativeText ($targetText)';
    }
  }

  /// Get primary text (what to show prominently) based on level.
  String getPrimaryText({
    required String nativeText,
    required String targetText,
    required String level,
  }) {
    return shouldShowTargetLanguage(level) ? targetText : nativeText;
  }

  /// Get secondary text (shown as hint/subtitle) based on level.
  String getSecondaryText({
    required String nativeText,
    required String targetText,
    required String level,
  }) {
    return shouldShowTargetLanguage(level) ? nativeText : targetText;
  }
}

/// A pair of bilingual labels for UI elements like buttons.
class BilingualLabel {
  final String native;
  final String target;

  const BilingualLabel({
    required this.native,
    required this.target,
  });

  /// Get the appropriate label for the player's level.
  String forLevel(String level) {
    return BilingualTextService.instance.getTextForLevel(
      nativeText: native,
      targetText: target,
      level: level,
    );
  }

  /// Get both labels formatted together.
  String bothForLevel(String level) {
    return BilingualTextService.instance.getBilingualText(
      nativeText: native,
      targetText: target,
      level: level,
    );
  }

  /// Get primary label for the level.
  String primaryForLevel(String level) {
    return BilingualTextService.instance.getPrimaryText(
      nativeText: native,
      targetText: target,
      level: level,
    );
  }

  /// Get secondary/hint label for the level.
  String secondaryForLevel(String level) {
    return BilingualTextService.instance.getSecondaryText(
      nativeText: native,
      targetText: target,
      level: level,
    );
  }
}

/// Common UI labels in bilingual format.
/// These are the standard navigation and action labels used throughout the app.
class UILabels {
  // Navigation
  static const map = BilingualLabel(native: 'Map', target: 'Mapa');
  static const quests = BilingualLabel(native: 'Quests', target: 'Misiones');
  static const inventory = BilingualLabel(native: 'Inventory', target: 'Inventario');
  static const settings = BilingualLabel(native: 'Settings', target: 'Ajustes');

  // Actions
  static const lookAround = BilingualLabel(native: 'Look Around', target: 'Mira alrededor');
  static const pickUp = BilingualLabel(native: 'Pick Up', target: 'Recoger');
  static const talk = BilingualLabel(native: 'Talk', target: 'Hablar');
  static const travel = BilingualLabel(native: 'Travel', target: 'Viajar');
  static const buy = BilingualLabel(native: 'Buy', target: 'Comprar');
  static const sell = BilingualLabel(native: 'Sell', target: 'Vender');
  static const use = BilingualLabel(native: 'Use', target: 'Usar');
  static const equip = BilingualLabel(native: 'Equip', target: 'Equipar');
  static const accept = BilingualLabel(native: 'Accept', target: 'Aceptar');
  static const decline = BilingualLabel(native: 'Decline', target: 'Rechazar');
  static const close = BilingualLabel(native: 'Close', target: 'Cerrar');
  static const back = BilingualLabel(native: 'Back', target: 'Volver');
  static const send = BilingualLabel(native: 'Send', target: 'Enviar');

  // Sections
  static const peopleHere = BilingualLabel(native: 'People Here', target: 'Gente aqui');
  static const itemsHere = BilingualLabel(native: 'Items Here', target: 'Objetos aqui');
  static const activeQuests = BilingualLabel(native: 'Active Quests', target: 'Misiones activas');
  static const completedQuests = BilingualLabel(native: 'Completed', target: 'Completadas');
  static const yourInventory = BilingualLabel(native: 'Your Inventory', target: 'Tu inventario');

  // Status
  static const health = BilingualLabel(native: 'Health', target: 'Salud');
  static const gold = BilingualLabel(native: 'Gold', target: 'Oro');
  static const level = BilingualLabel(native: 'Level', target: 'Nivel');
  static const experience = BilingualLabel(native: 'Experience', target: 'Experiencia');

  // Common phrases
  static const newQuest = BilingualLabel(native: 'New Quest', target: 'Nueva mision');
  static const questComplete = BilingualLabel(native: 'Quest Complete', target: 'Mision completada');
  static const itemReceived = BilingualLabel(native: 'Item Received', target: 'Objeto recibido');
  static const nothingHere = BilingualLabel(native: 'Nothing here', target: 'Nada aqui');
  static const youFound = BilingualLabel(native: 'You found', target: 'Encontraste');
}
