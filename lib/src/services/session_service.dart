import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _userIdKey = 'user_id';
  static const _blockedUserIdsKey = 'blocked_user_ids';
  static String? currentUserId;
  static List<String> blockedUserIds = const [];
  static bool noticePopupShown = false;

  static bool get isAdmin => currentUserId == 'admin';

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getString(_userIdKey);
    blockedUserIds = prefs.getStringList(_blockedUserIdsKey) ?? const [];
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

  static bool isBlocked(String userId) {
    return blockedUserIds.contains(userId);
  }

  static Future<void> blockUser(String userId) async {
    if (userId.isEmpty || isBlocked(userId)) return;

    final prefs = await SharedPreferences.getInstance();
    blockedUserIds = [...blockedUserIds, userId];
    await prefs.setStringList(_blockedUserIdsKey, blockedUserIds);
  }
}
