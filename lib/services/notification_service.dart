import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  Future<void> init() async {
    // 1. Inisialisasi Zona Waktu
    tz.initializeTimeZones();

    // 2. Setup Android Settings
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    
    // 3. Minta Izin Notifikasi (Khusus Android 13+)
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // --- FUNGSI JADWAL HARIAN JAM 19:00 ---
  Future<void> scheduleDailyNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0, // ID Notifikasi (0 = ID Promo Harian)
      '🎬 Waktunya Nonton!', // Judul Notif
      'Cek film trending hari ini. Ada promo tiket buy 1 get 1 lho!', // Isi Pesan
      _nextInstanceOf7PM(), // Waktu: Jam 7 Malam
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_promo_channel', 
          'Daily Promos',
          channelDescription: 'Notifikasi promo harian jam 7 malam',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Tetap bunyi meski HP idle
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Ulangi setiap 'Waktu' yang sama (Setiap Hari)
    );
  }

  // Helper: Hitung jam 19:00 berikutnya
  tz.TZDateTime _nextInstanceOf7PM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    
    // Set target jam 19:00:00
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 19, 0, 0);
    
    // Kalau sekarang sudah lewat jam 19:00, jadwalkan buat BESOK
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // Fungsi Notifikasi Langsung (Manual)
  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'cineglobal_channel', 'CineGlobal Notifs',
      importance: Importance.max, priority: Priority.high, showWhen: true
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(0, title, body, platformChannelSpecifics);
  }
}