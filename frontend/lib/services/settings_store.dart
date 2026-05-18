import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  SettingsStore._(this._prefs);
  final SharedPreferences _prefs;

  static const _kApiBase = 'api_base';
  static const _kOnboardingDone = 'onboarding_done';

  static const String compiledDefault = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://yingwu.kuangshin.tw',
  );

  static Future<SettingsStore> load() async {
    final p = await SharedPreferences.getInstance();
    return SettingsStore._(p);
  }

  String get apiBase => _prefs.getString(_kApiBase) ?? compiledDefault;
  bool get onboardingDone => _prefs.getBool(_kOnboardingDone) ?? false;

  Future<void> setApiBase(String v) => _prefs.setString(_kApiBase, v);
  Future<void> markOnboardingDone() => _prefs.setBool(_kOnboardingDone, true);
}
