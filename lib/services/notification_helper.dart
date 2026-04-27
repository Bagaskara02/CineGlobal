import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationHelper {
  NotificationHelper._();
  static final NotificationHelper instance = NotificationHelper._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _plugin.initialize(initSettings);
      // Request permission for Android 13+
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestNotificationsPermission();
      }
      _initialized = true;
      debugPrint("NotificationHelper: Initialized");
    } catch (e) {
      debugPrint("NotificationHelper: Init failed: $e");
    }
  }

  /// Tampilkan notifikasi pembelian tiket berhasil
  Future<void> showTicketPurchaseNotification({
    required String movieTitle,
    required String cinemaName,
    required String showTime,
    required String showDate,
    required String ticketId,
    required String paymentMethod,
    required int totalPrice,
  }) async {
    if (kIsWeb || !_initialized) {
      debugPrint("NotificationHelper: Skipped (web or not initialized)");
      return;
    }

    final fmtPrice = _formatPrice(totalPrice);

    const androidDetails = AndroidNotificationDetails(
      'ticket_channel',
      'Pembelian Tiket',
      channelDescription: 'Notifikasi pembelian tiket bioskop',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Tiket berhasil dibeli!',
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        '🎬 Tiket Berhasil Dibeli!',
        '$movieTitle\n'
        '📍 $cinemaName\n'
        '📅 $showDate • $showTime WIB\n'
        '💳 $paymentMethod • Rp $fmtPrice\n'
        '🎫 $ticketId',
        details,
      );
      debugPrint("NotificationHelper: Notification sent!");
    } catch (e) {
      debugPrint("NotificationHelper: Show failed: $e");
    }
  }

  String _formatPrice(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
