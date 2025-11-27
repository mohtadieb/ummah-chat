import 'package:shared_preferences/shared_preferences.dart';

class StoryProgressService {
  static const _keyPrefix = 'story_completed_';

  static String _key(String storyId) => '$_keyPrefix$storyId';

  /// Mark a story as completed for this device.
  static Future<void> markCompleted(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(storyId), true);
  }

  /// Check if a story is completed.
  static Future<bool> isCompleted(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(storyId)) ?? false;
  }

  /// Get completion map for a list of story IDs.
  static Future<Map<String, bool>> getCompletedStates(
      List<String> storyIds) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, bool> result = {};
    for (final id in storyIds) {
      result[id] = prefs.getBool(_key(id)) ?? false;
    }
    return result;
  }
}
