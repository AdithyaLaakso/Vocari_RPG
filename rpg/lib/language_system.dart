import 'package:flutter/foundation.dart';

/// Enum representing the available display languages
enum DisplayLanguage {
  nativeLanguage,
  targetLanguage,
}

/// A string that can be localized in both native and target languages.
/// This is the core data structure for bilingual content.
class LocalizedString {
  final String nativeLanguage;
  final String targetLanguage;

  const LocalizedString({
    required this.nativeLanguage,
    required this.targetLanguage,
  });

  /// Creates a LocalizedString from JSON with native_language and target_language keys
  factory LocalizedString.fromJson(dynamic json) {
    if (json is String) {
      // Handle legacy format where it's just a plain string
      return LocalizedString(nativeLanguage: json, targetLanguage: json);
    }
    if (json is Map<String, dynamic>) {
      return LocalizedString(
        nativeLanguage: json['native_language'] ?? '',
        targetLanguage: json['target_language'] ?? '',
      );
    }
    return const LocalizedString(nativeLanguage: '', targetLanguage: '');
  }

  /// Returns the string for the given display language
  String get(DisplayLanguage language) {
    switch (language) {
      case DisplayLanguage.nativeLanguage:
        return nativeLanguage;
      case DisplayLanguage.targetLanguage:
        return targetLanguage;
    }
  }

  /// Returns the string using the current language from LanguageService
  String get current => LanguageService.instance.getString(this);

  Map<String, dynamic> toJson() => {
        'native_language': nativeLanguage,
        'target_language': targetLanguage,
      };

  @override
  String toString() => current;

  /// Convenience for empty check
  bool get isEmpty => nativeLanguage.isEmpty && targetLanguage.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

/// A list of localized strings
class LocalizedStringList {
  final List<LocalizedString> items;

  const LocalizedStringList(this.items);

  factory LocalizedStringList.fromJson(List<dynamic>? json) {
    if (json == null) return const LocalizedStringList([]);
    return LocalizedStringList(
      json.map((item) => LocalizedString.fromJson(item)).toList(),
    );
  }

  List<String> get current =>
      items.map((item) => LanguageService.instance.getString(item)).toList();

  List<Map<String, dynamic>> toJson() => items.map((i) => i.toJson()).toList();
}

/// Service that manages the current display language.
/// This is a singleton that can be accessed globally.
class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  static LanguageService get instance => _instance;

  LanguageService._internal();

  DisplayLanguage _currentLanguage = DisplayLanguage.nativeLanguage;

  /// The player's current language proficiency level (A0, A0+, A1, A1+, A2, B1, etc.)
  String _playerLanguageLevel = 'A0';

  /// Get the current display language
  DisplayLanguage get currentLanguage => _currentLanguage;

  /// Get the player's current language level
  String get playerLanguageLevel => _playerLanguageLevel;

  /// Set the current display language
  set currentLanguage(DisplayLanguage language) {
    if (_currentLanguage != language) {
      _currentLanguage = language;
      notifyListeners();
    }
  }

  /// Set the player's language level
  set playerLanguageLevel(String level) {
    if (_playerLanguageLevel != level) {
      _playerLanguageLevel = level;
      notifyListeners();
    }
  }

  /// Get the appropriate string based on current language setting
  String getString(LocalizedString localizedString) {
    return localizedString.get(_currentLanguage);
  }

  /// Switch to native language display
  void useNativeLanguage() {
    currentLanguage = DisplayLanguage.nativeLanguage;
  }

  /// Switch to target language display
  void useTargetLanguage() {
    currentLanguage = DisplayLanguage.targetLanguage;
  }

  /// Toggle between languages
  void toggleLanguage() {
    currentLanguage = _currentLanguage == DisplayLanguage.nativeLanguage
        ? DisplayLanguage.targetLanguage
        : DisplayLanguage.nativeLanguage;
  }

  /// Check if player's language level meets or exceeds required level
  bool meetsLanguageLevel(String requiredLevel) {
    return _compareLevels(_playerLanguageLevel, requiredLevel) >= 0;
  }

  /// Compare two language levels. Returns:
  /// - negative if level1 < level2
  /// - 0 if level1 == level2
  /// - positive if level1 > level2
  int _compareLevels(String level1, String level2) {
    const levelOrder = ['A0', 'A0+', 'A1', 'A1+', 'A2', 'A2+', 'B1', 'B1+', 'B2', 'B2+', 'C1', 'C1+', 'C2'];
    final index1 = levelOrder.indexOf(level1);
    final index2 = levelOrder.indexOf(level2);
    // Default unknown levels to A0
    final i1 = index1 >= 0 ? index1 : 0;
    final i2 = index2 >= 0 ? index2 : 0;
    return i1 - i2;
  }
}
