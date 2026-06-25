import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling background messaging event: ${message.messageId}");
}

class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  bool _soundEnabled = true;
  bool get soundEnabled => _soundEnabled;

  bool _vibrationEnabled = true;
  bool get vibrationEnabled => _vibrationEnabled;

  // Custom sound profile: 'default', 'alarm', 'ringtone'
  String _soundProfile = 'default';
  String get soundProfile => _soundProfile;

  Future<void> init() async {
    // Load custom settings from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('notifications_sound_enabled') ?? true;
    _vibrationEnabled = prefs.getBool('notifications_vibration_enabled') ?? true;
    _soundProfile = prefs.getString('notifications_sound_profile') ?? 'default';

    // Register Background Handler
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint("FCM Background message handler setup error: $e");
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification tapped: ${response.payload}");
        if (_onNotificationTappedCallback != null) {
          _onNotificationTappedCallback!(response.payload);
        }
      },
    );

    // Create high importance channel for Android
    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important queue notifications.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
    }

    // Request permission
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint("FCM Auth status: ${settings.authorizationStatus}");
    } catch (e) {
      debugPrint("FCM Permission request error: $e");
    }

    // Foreground listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("FCM Foreground message received: ${message.messageId}");
      final notification = message.notification;
      final data = message.data;
      
      final category = data['category'] ?? 'update';
      final title = notification?.title ?? data['title'] ?? 'MediQue Update';
      final body = notification?.body ?? data['body'] ?? '';

      // Trigger tray alert and sound/vibrate
      showLocalNotification(
        id: message.hashCode,
        title: title,
        body: body,
        category: category,
        payload: 'live_queue',
      );
    });

    // Tap callback listener
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("FCM Tap message: ${message.messageId}");
      if (_onNotificationTappedCallback != null) {
        _onNotificationTappedCallback!('live_queue');
      }
    });
  }

  // Callback to route the UI on notification tap
  Function(String?)? _onNotificationTappedCallback;
  void setOnNotificationTapped(Function(String?) callback) {
    _onNotificationTappedCallback = callback;
  }

  // Toggle Sound Alerts
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_sound_enabled', enabled);
    notifyListeners();
  }

  // Toggle Vibration Alerts
  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_vibration_enabled', enabled);
    notifyListeners();
  }

  // Select Sound Profile
  Future<void> setSoundProfile(String profile) async {
    _soundProfile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notifications_sound_profile', profile);
    notifyListeners();
  }

  // Play Sound Alerts based on category/settings
  void playSound(String category) {
    if (!_soundEnabled) return;

    try {
      if (category == 'turn') {
        if (_soundProfile == 'alarm') {
          FlutterRingtonePlayer().playAlarm();
        } else if (_soundProfile == 'ringtone') {
          FlutterRingtonePlayer().playRingtone();
        } else {
          FlutterRingtonePlayer().playNotification();
        }
      } else if (category == 'emergency') {
        FlutterRingtonePlayer().playAlarm();
      } else {
        FlutterRingtonePlayer().playNotification();
      }

      // Stop ringtone/alarm sound after 4 seconds so it doesn't ring forever
      if (category == 'turn' || category == 'emergency') {
        Future.delayed(const Duration(seconds: 4), () {
          FlutterRingtonePlayer().stop();
        });
      }
    } catch (e) {
      debugPrint("Error playing notification sound: $e");
    }
  }

  // Trigger Vibration pattern
  Future<void> triggerVibration(String category) async {
    if (!_vibrationEnabled) return;

    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;

    try {
      if (category == 'update') {
        await Vibration.vibrate(duration: 200);
      } else if (category == 'ahead_1') {
        await Vibration.vibrate(duration: 500);
      } else if (category == 'turn') {
        await Vibration.vibrate(
          pattern: [0, 500, 200, 1000, 200, 1000],
          intensities: [0, 128, 0, 255, 0, 255],
        );
      } else if (category == 'emergency') {
        await Vibration.vibrate(
          pattern: [0, 400, 100, 400, 100, 400, 100, 800],
          intensities: [0, 255, 0, 255, 0, 255, 0, 255],
        );
      } else {
        await Vibration.vibrate(duration: 300);
      }
    } catch (e) {
      debugPrint("Error triggering vibration: $e");
    }
  }

  // Display Local Notification in Tray
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String category = 'update',
  }) async {
    // Trigger sound and vibration
    playSound(category);
    triggerVibration(category);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important queue notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: false, // Managed manually via playSound()
      enableVibration: false, // Managed manually via triggerVibration()
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _localNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
}
