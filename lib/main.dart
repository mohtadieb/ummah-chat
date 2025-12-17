import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'pages/home_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';
import 'services/auth/startup_gate.dart';
import 'services/database/database_provider.dart';
import 'services/chat/chat_provider.dart';
import 'themes/theme_provider.dart';
import 'services/navigation/bottom_nav_provider.dart';
import 'package:easy_localization/easy_localization.dart';

// 🔔 Push notification utilities
import 'services/notifications/push_notification_service.dart';

// 🔔 Background handler (top-level)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(
    '🔔 Background message: ${message.messageId} | data=${message.data}',
  );
}

// 🔔 Push notification setup
Future<void> setupPushNotifications() async {
  final messaging = FirebaseMessaging.instance;

  // Ask for permission (Android 13+ and iOS)
  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  debugPrint(
    '🔔 Notification permission status: ${settings.authorizationStatus}',
  );

  // Optional: log token for debugging
  final token = await messaging.getToken();
  debugPrint('📲 FCM token (from setupPushNotifications): $token');

  // ✅ Sync token once (will no-op if no user yet)
  await PushNotificationService.syncFcmTokenWithSupabase();

  // ✅ Register listener so refreshed tokens are also saved
  PushNotificationService.registerTokenRefreshListener();

  // Foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('📩 Foreground message: ${message.messageId}');
    debugPrint('Data: ${message.data}');
    debugPrint(
      'Notification: ${message.notification?.title} | ${message.notification?.body}',
    );
  });

  // When user taps a notification and opens the app
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('📬 Notification opened app: ${message.data}');
    // Later: navigate to a chat / notifications page based on message.data
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🟢 Initialize Easy Localization
  await EasyLocalization.ensureInitialized();

  await Firebase.initializeApp();

  // Register background handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: 'https://njotewktazwhoprvhsvj.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5qb3Rld2t0YXp3aG9wcnZoc3ZqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE4MzY1NjgsImV4cCI6MjA3NzQxMjU2OH0.SDr9TdrMIm-6LXdaaAMMhFDujt-PAgqyreebWPtV9NQ',
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('nl'),
        Locale('ar'), // later if you add Arabic
      ],
      path: 'assets/lang', // folder where en.json / nl.json live
      fallbackLocale: const Locale('en'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => DatabaseProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
          ChangeNotifierProvider(create: (_) => BottomNavProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

// 🔄 MyApp is STATEFUL so we can call setupPushNotifications() in initState
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    setupPushNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,

      // 🟢 EasyLocalization wiring
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      // ✅ Fallback to English if device locale isn't supported
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (deviceLocale == null) return const Locale('en');

        // 1) Try exact match (language + country if present)
        for (final l in supportedLocales) {
          final countryOk =
              (l.countryCode == null) || (l.countryCode == deviceLocale.countryCode);
          if (l.languageCode == deviceLocale.languageCode && countryOk) {
            return l;
          }
        }

        // 2) Try language-only match
        for (final l in supportedLocales) {
          if (l.languageCode == deviceLocale.languageCode) return l;
        }

        // 3) Fallback to English
        return const Locale('en');
      },

      initialRoute: '/',
      routes: {
        '/': (context) => const StartupGate(),
        '/home': (context) => const HomePage(),
        '/search': (context) => const SearchPage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}
