import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _userIdKey = 'user_id';
  static String? currentUserId;
  static bool noticePopupShown = false;

  static bool get isAdmin => currentUserId == 'admin';

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getString(_userIdKey);
    return currentUserId;
  }

  static Future<void> save(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    currentUserId = userId;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    currentUserId = null;
    noticePopupShown = false;
  }
}
