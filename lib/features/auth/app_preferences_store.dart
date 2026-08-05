import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesStore {
  static const _languageKey = 'preferred_language';
  static const _accountModePrefix = 'active_account_mode_';
  static const _followedFarmsPrefix = 'followed_farms_';

  Future<String?> language() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_languageKey);
    return const {'en', 'fi', 'sv'}.contains(value) ? value : null;
  }

  Future<void> setLanguage(String languageCode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_languageKey, languageCode);
  }

  Future<String?> accountMode(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString('$_accountModePrefix$uid');
  }

  Future<void> setAccountMode(String uid, String mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('$_accountModePrefix$uid', mode);
  }

  Future<Set<String>> followedFarms(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList('$_followedFarmsPrefix$uid') ?? const [])
        .toSet();
  }

  Future<void> setFarmFollowed(
    String uid,
    String farmId, {
    required bool followed,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final farms =
        (preferences.getStringList('$_followedFarmsPrefix$uid') ?? const [])
            .toSet();
    followed ? farms.add(farmId) : farms.remove(farmId);
    final sorted = farms.toList()..sort();
    await preferences.setStringList('$_followedFarmsPrefix$uid', sorted);
  }
}
