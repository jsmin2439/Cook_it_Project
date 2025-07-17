// lib/settings/push_notification_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../color/colors.dart';

class PushNotificationSettingsScreen extends StatefulWidget {
  final String userId;
  final String idToken;

  const PushNotificationSettingsScreen({
    Key? key,
    required this.userId,
    required this.idToken,
  }) : super(key: key);

  @override
  State<PushNotificationSettingsScreen> createState() =>
      _PushNotificationSettingsScreenState();
}

class _PushNotificationSettingsScreenState
    extends State<PushNotificationSettingsScreen> {
  final FlutterLocalNotificationsPlugin _flutterLocal =
      FlutterLocalNotificationsPlugin();

  bool _recipeNotify = false;
  static const _alarmHours = [8, 12, 18];

  @override
  void initState() {
    super.initState();

    // SharedPreferences 안전 호출
    Future.delayed(Duration.zero, _initNotifications);
  }

  Future<void> _initNotifications() async {
    try {
      // Timezone 초기화
      tz.initializeTimeZones();

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      const settings = InitializationSettings(android: android, iOS: ios);
      await _flutterLocal.initialize(settings);

      // SharedPreferences 안전 로딩
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('daily_recipe_notify') ?? false;

      if (mounted) {
        setState(() => _recipeNotify = saved);
      }

      if (saved) await _scheduleDailyAlarms();
    } catch (e) {
      debugPrint('🔴 Notification Init Error: $e');
    }
  }

  Future<void> _scheduleDailyAlarms() async {
    const androidDetails = AndroidNotificationDetails(
      'daily_recipe_channel',
      'Daily Recipe',
      channelDescription: '매일 세 번 레시피 추천',
      importance: Importance.high,
    );
    const noticeDetails = NotificationDetails(android: androidDetails);

    final now = tz.TZDateTime.now(tz.local);

    for (int i = 0; i < _alarmHours.length; i++) {
      final hour = _alarmHours[i];
      var scheduled =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);

      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _flutterLocal.zonedSchedule(
        10 + i, // unique ID
        '오늘의 레시피 추천',
        '지금 새로운 레시피를 확인해 보세요! 🍽️',
        scheduled,
        noticeDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_recipe',
      );
    }
  }

  Future<void> _cancelDailyAlarms() async {
    for (int i = 0; i < _alarmHours.length; i++) {
      await _flutterLocal.cancel(10 + i);
    }
  }

  Future<void> _onToggleRecipeNotify(bool value) async {
    setState(() => _recipeNotify = value);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_recipe_notify', value);

    if (value) {
      await _scheduleDailyAlarms();
    } else {
      await _cancelDailyAlarms();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextColor),
        title: const Text('알림 설정', style: TextStyle(color: kTextColor)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text(
              '레시피 추천 푸시 알림',
              style: TextStyle(fontSize: 16, color: kTextColor),
            ),
            subtitle: const Text(
              '매일 08:00 · 12:00 · 18:00에 알림을 받아요.',
              style: TextStyle(color: kTextColor),
            ),
            value: _recipeNotify,
            activeColor: kPinkButtonColor,
            onChanged: _onToggleRecipeNotify,
          ),
        ],
      ),
    );
  }
}
