import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ActiveSession {
  final String packageName;
  final String appLabel;
  final int settingsCount;
  final String appliedAt;

  const ActiveSession({
    required this.packageName,
    required this.appLabel,
    required this.settingsCount,
    required this.appliedAt,
  });

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'appLabel': appLabel,
    'settingsCount': settingsCount,
    'appliedAt': appliedAt,
  };

  factory ActiveSession.fromJson(Map<String, dynamic> json) => ActiveSession(
    packageName: json['packageName'] as String,
    appLabel: json['appLabel'] as String,
    settingsCount: json['settingsCount'] as int,
    appliedAt: json['appliedAt'] as String,
  );
}

class ActiveSessionService {
  static const _key = 'active_sessions';

  Future<List<ActiveSession>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => ActiveSession.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> addSession(String packageName, String appLabel, int settingsCount) async {
    final sessions = await getSessions();
    // Remove existing session for this package if any
    sessions.removeWhere((s) => s.packageName == packageName);
    sessions.add(ActiveSession(
      packageName: packageName,
      appLabel: appLabel,
      settingsCount: settingsCount,
      appliedAt: DateTime.now().toIso8601String(),
    ));
    await _save(sessions);
  }

  Future<void> removeSession(String packageName) async {
    final sessions = await getSessions();
    sessions.removeWhere((s) => s.packageName == packageName);
    await _save(sessions);
  }

  Future<void> _save(List<ActiveSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(sessions.map((s) => s.toJson()).toList()));
  }
}
