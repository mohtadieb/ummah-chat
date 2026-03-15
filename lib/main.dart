import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'pages/home_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';
import 'pages/post_page.dart'; // ✅ NEW
import 'services/auth/startup_gate.dart';
import 'services/database/database_provider.dart';
import 'services/chat/chat_provider.dart';
import 'themes/theme_provider.dart';
import 'services/navigation/bottom_nav_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:app_links/app_links.dart';
import 'pages/reset_password_page.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';

// 🔔 Push notification utilities
import 'services/notifications/push_notification_service.dart';

// 🔔 Background handler (top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(
    '🔔 Background message: ${message.messageId} | data=${message.data}',
  );
}

// 🔔 Push notification setup
Future<void> setupPushNotifications() async {
  final messaging = FirebaseMessaging.instance;

  // iOS always needs permission.
  // Android should not blindly call requestPermission here.
  if (!kIsWeb && Platform.isIOS) {
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      '🔔 Notification permission status: ${settings.authorizationStatus}',
    );
  } else {
    debugPrint('🔔 Skipping requestPermission on this platform');
  }

  final token = await messaging.getToken();
  debugPrint('📲 FCM token (from setupPushNotifications): $token');

  await PushNotificationService.syncFcmTokenWithSupabase();
  PushNotificationService.registerTokenRefreshListener();
  await PushNotificationService.initPushTapHandlers();

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('📩 Foreground message: ${message.messageId}');
    debugPrint('Data: ${message.data}');
    debugPrint(
      'Notification: ${message.notification?.title} | ${message.notification?.body}',
    );
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
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('nl'),
        Locale('ar'),
        Locale('fr'), // ✅ French added
      ],
      path: 'assets/lang', // ✅ must match your assets folder + pubspec.yaml
      fallbackLocale: const Locale('en'),
      saveLocale: true, // ✅ persists AFTER user chooses a language
      useOnlyLangCode: true,

      // ✅ IMPORTANT for autodetect:
      // do NOT set startLocale here.
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
  final AppLinks _appLinks = AppLinks();
  bool _didHandleInitialLink = false;

  void _startResetPasswordDeepLinkListener() {
    // Handle links while app is open / resumed
    _appLinks.uriLinkStream.listen((uri) async {
      await _handleIncomingUri(uri);
    });

    // Handle the very first link if app was launched from the email
    _handleInitialUriOnce();
  }

  Future<void> _handleInitialUriOnce() async {
    if (_didHandleInitialLink) return;
    _didHandleInitialLink = true;

    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        await _handleIncomingUri(uri);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    // Example: ummahchat://reset-password#access_token=...&refresh_token=...&type=recovery
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
    } catch (_) {
      // If parsing fails, still allow navigation attempt
    }

    final isReset =
        (uri.host == 'reset-password') || uri.path.contains('reset-password');

    if (!isReset) return;

    final nav = PushNotificationService.navigatorKey.currentState;
    if (nav == null) return;

    nav.pushNamedAndRemoveUntil('/reset-password', (route) => route.isFirst);
  }

  @override
  void initState() {
    super.initState();
    setupPushNotifications();

    // ✅ Reset password deep links
    _startResetPasswordDeepLinkListener();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,

      // ✅ Allows PushNotificationService to navigate on tap
      navigatorKey: PushNotificationService.navigatorKey,

      // 🟢 EasyLocalization wiring
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      // ✅ Device language on first launch:
      // EasyLocalization will pick device locale if no saved locale exists.
      // This callback just improves matching.
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        // Prefer fallback from EasyLocalization config if device locale is null
        const fallback = Locale('en');

        if (deviceLocale == null) return fallback;

        // 1) Exact match (language + country if provided)
        for (final l in supportedLocales) {
          final countryOk =
              (l.countryCode == null) ||
                  (l.countryCode == deviceLocale.countryCode);
          if (l.languageCode == deviceLocale.languageCode && countryOk) {
            return l;
          }
        }

        // 2) Language-only match
        for (final l in supportedLocales) {
          if (l.languageCode == deviceLocale.languageCode) return l;
        }

        // 3) Fallback
        return fallback;
      },

      initialRoute: '/',
      routes: {
        '/': (context) => const StartupGate(),
        '/home': (context) => const HomePage(),
        '/search': (context) => const SearchPage(),
        '/settings': (context) => const SettingsPage(),
        '/reset-password': (context) => const ResetPasswordPage(),

        // ✅ NEW: Post deep link route used by pushes
        '/post': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final map = (args is Map) ? args : <String, dynamic>{};

          final postId = (map['postId'] ?? '').toString();
          final highlightCommentId = (map['highlightCommentId'] ?? '')
              .toString();

          return PostPage(
            post: null,
            postId: postId,
            // for comment notifications, we highlight the comments area
            scrollToComments: true,
            highlightComments: true,
            highlightCommentId:
            highlightCommentId.isNotEmpty ? highlightCommentId : null,
          );
        },
      },
    );
  }
}
