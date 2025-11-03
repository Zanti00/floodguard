import 'package:supabase_flutter/supabase_flutter.dart';

class AppSettingsService {
  // Cache for settings to avoid repeated database calls
  static final Map<String, dynamic> _settingsCache = {};
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Fetches a boolean setting from app_settings table
  /// Uses cache to avoid excessive database queries
  static Future<bool> getBoolSetting(
    String key, {
    bool defaultValue = true,
  }) async {
    try {
      // Check if cache is still valid
      if (_settingsCache.containsKey(key) && _cacheTimestamp != null) {
        final now = DateTime.now();
        if (now.difference(_cacheTimestamp!) < _cacheDuration) {
          return _settingsCache[key] as bool;
        }
      }

      // Fetch from database
      final response = await Supabase.instance.client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', key)
          .limit(1);

      if (response.isEmpty) {
        print('Setting "$key" not found in app_settings table');
        return defaultValue;
      }

      final value = response[0]['setting_value'] as bool;

      // Update cache
      _settingsCache[key] = value;
      _cacheTimestamp = DateTime.now();

      return value;
    } catch (error) {
      print('Error fetching setting "$key": $error');
      // Return default value on error
      return defaultValue;
    }
  }

  /// Updates a boolean setting in app_settings table
  static Future<bool> setBoolSetting(String key, bool value) async {
    try {
      await Supabase.instance.client.from('app_settings').upsert({
        'setting_key': key,
        'setting_value': value,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Update cache
      _settingsCache[key] = value;
      _cacheTimestamp = DateTime.now();

      print('Setting "$key" updated to $value');
      return true;
    } catch (error) {
      print('Error updating setting "$key": $error');
      return false;
    }
  }

  /// Clear the cache (useful when you know settings have changed)
  static void clearCache() {
    _settingsCache.clear();
    _cacheTimestamp = null;
  }

  /// Gets a string setting from app_settings table
  static Future<String> getStringSetting(
    String key, {
    String defaultValue = '',
  }) async {
    try {
      final response = await Supabase.instance.client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', key)
          .limit(1);

      if (response.isEmpty) {
        return defaultValue;
      }

      return response[0]['setting_value'] as String;
    } catch (error) {
      print('Error fetching string setting "$key": $error');
      return defaultValue;
    }
  }
}
