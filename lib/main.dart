import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/home_page.dart';
import 'pages/post_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';
import 'services/auth/startup_gate.dart';
import 'services/chat/chat_provider.dart';
import 'services/database/database_provider.dart';
import 'services/navigation/bottom_nav_provider.dart';
import 'services/notifications/push_notification_service.dart';
import 'themes/theme_provider.dart';

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

  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp();

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
        Locale('fr'),
      ],
      path: 'assets/lang',
      fallbackLocale: const Locale('en'),
      saveLocale: true,
      useOnlyLangCode: true,
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
  GlobalKey<ScaffoldMessengerState>();

  static const _handledAuthCallbackKey = 'handled_auth_callback_uri';
  static const _handledAuthCallbackAtKey = 'handled_auth_callback_at_ms';

  StreamSubscription<Uri>? _linkSub;

  bool _initialLinkChecked = false;
  bool _forcePasswordRecovery = false;
  bool _isHandlingAuthCallback = false;
  bool _suppressSignedInUi = false;

  String? _pendingSnackBarMessage;
  String? _passwordRecoveryTokenHash;

  @override
  void initState() {
    super.initState();
    setupPushNotifications();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        await _handleUri(initial);
      }
    } catch (_) {
      // Ignore and continue boot.
    } finally {
      if (mounted) {
        setState(() {
          _initialLinkChecked = true;
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _flushPendingSnackBar();
      });
    }

    _linkSub = _appLinks.uriLinkStream.listen((uri) async {
      await _handleUri(uri);
    });
  }

  void _queueSnackBar(String message) {
    _pendingSnackBarMessage = message;
    _flushPendingSnackBar();
  }

  void _flushPendingSnackBar() {
    final messenger = _scaffoldMessengerKey.currentState;
    final message = _pendingSnackBarMessage;

    if (messenger == null || message == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );

    _pendingSnackBarMessage = null;
  }

  Future<bool> _shouldIgnoreAuthCallback(Uri uri) async {
    final prefs = await SharedPreferences.getInstance();

    final lastUri = prefs.getString(_handledAuthCallbackKey);
    final lastAtMs = prefs.getInt(_handledAuthCallbackAtKey);

    if (lastUri == uri.toString()) {
      return true;
    }

    if (lastAtMs != null) {
      final lastAt = DateTime.fromMillisecondsSinceEpoch(lastAtMs);
      final age = DateTime.now().difference(lastAt);

      if (age < const Duration(seconds: 15) &&
          lastUri == uri.toString()) {
        return true;
      }
    }

    return false;
  }

  Future<void> _markAuthCallbackHandled(Uri uri) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_handledAuthCallbackKey, uri.toString());
    await prefs.setInt(
      _handledAuthCallbackAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _completeEmailConfirmationFlow() async {
    const timeout = Duration(seconds: 4);
    const step = Duration(milliseconds: 150);

    final auth = Supabase.instance.client.auth;
    final started = DateTime.now();

    while (auth.currentSession == null &&
        DateTime.now().difference(started) < timeout) {
      await Future.delayed(step);
    }

    try {
      await auth.signOut();
    } catch (_) {
      // Ignore if already signed out.
    }

    if (!mounted) return;

    setState(() {
      _forcePasswordRecovery = false;
      _isHandlingAuthCallback = false;
      _suppressSignedInUi = false;
      _passwordRecoveryTokenHash = null;
    });

    _queueSnackBar('Email confirmed. You can now log in.'.tr());
  }

  Map<String, String> _fragmentParams(Uri uri) {
    final fragment = uri.fragment;
    if (fragment.isEmpty) return {};

    try {
      return Uri.splitQueryString(fragment);
    } catch (_) {
      return {};
    }
  }

  Future<void> _handleUri(Uri uri) async {
    if (uri.scheme != 'ummahchat') return;

    // ✅ EMAIL CONFIRMATION CALLBACK
    if (uri.host == 'auth-callback') {
      if (_isHandlingAuthCallback) return;
      if (!mounted) return;

      final shouldIgnore = await _shouldIgnoreAuthCallback(uri);
      if (shouldIgnore) return;

      await _markAuthCallbackHandled(uri);

      setState(() {
        _isHandlingAuthCallback = true;
        _suppressSignedInUi = true;
        _forcePasswordRecovery = false;
        _passwordRecoveryTokenHash = null;
      });

      await _completeEmailConfirmationFlow();
      return;
    }

    // ✅ PASSWORD RESET
    if (uri.host == 'reset-password') {
      if (!mounted) return;

      final fragmentParams = _fragmentParams(uri);

      final tokenHash =
          uri.queryParameters['token_hash'] ?? fragmentParams['token_hash'];

      setState(() {
        _forcePasswordRecovery = true;
        _passwordRecoveryTokenHash =
        (tokenHash != null && tokenHash.isNotEmpty) ? tokenHash : null;
      });

      return;
    }
  }

  void _onPasswordResetCompleted() {
    if (!mounted) return;

    setState(() {
      _forcePasswordRecovery = false;
      _passwordRecoveryTokenHash = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (!_initialLinkChecked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themeProvider.themeData,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      navigatorKey: PushNotificationService.navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        const fallback = Locale('en');

        if (deviceLocale == null) return fallback;

        for (final l in supportedLocales) {
          final countryOk =
              (l.countryCode == null) ||
                  (l.countryCode == deviceLocale.countryCode);
          if (l.languageCode == deviceLocale.languageCode && countryOk) {
            return l;
          }
        }

        for (final l in supportedLocales) {
          if (l.languageCode == deviceLocale.languageCode) return l;
        }

        return fallback;
      },
      home: _RootGate(
        forcePasswordRecovery: _forcePasswordRecovery,
        suppressSignedInUi: _suppressSignedInUi,
        onPasswordResetCompleted: _onPasswordResetCompleted,
        recoveryTokenHash: _passwordRecoveryTokenHash,
      ),
      routes: {
        '/home': (context) => const HomePage(),
        '/search': (context) => const SearchPage(),
        '/settings': (context) => const SettingsPage(),
        '/post': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final map = (args is Map) ? args : <String, dynamic>{};

          final postId = (map['postId'] ?? '').toString();
          final highlightCommentId =
          (map['highlightCommentId'] ?? '').toString();

          return PostPage(
            post: null,
            postId: postId,
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

class _RootGate extends StatefulWidget {
  final bool forcePasswordRecovery;
  final bool suppressSignedInUi;
  final VoidCallback onPasswordResetCompleted;
  final String? recoveryTokenHash;

  const _RootGate({
    required this.forcePasswordRecovery,
    required this.suppressSignedInUi,
    required this.onPasswordResetCompleted,
    this.recoveryTokenHash,
  });

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool _isInPasswordRecovery = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
    if (widget.forcePasswordRecovery) {
      _isInPasswordRecovery = true;
    }
  }

  @override
  void didUpdateWidget(covariant _RootGate oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.forcePasswordRecovery && !_isInPasswordRecovery) {
      _isInPasswordRecovery = true;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _listenToAuthChanges() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      if (!mounted) return;

      if (event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          _isInPasswordRecovery = true;
        });
        return;
      }

      if (event == AuthChangeEvent.userUpdated) {
        setState(() {
          _isInPasswordRecovery = false;
        });
        return;
      }

      if (event == AuthChangeEvent.signedOut) {
        setState(() {
          _isInPasswordRecovery = false;
        });
      }
    });
  }

  void _handlePasswordResetCompleted() {
    setState(() {
      _isInPasswordRecovery = false;
    });
    widget.onPasswordResetCompleted();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.forcePasswordRecovery || _isInPasswordRecovery) {
      return ResetPasswordPage(
        onPasswordUpdated: _handlePasswordResetCompleted,
        recoveryTokenHash: widget.recoveryTokenHash,
      );
    }

    if (widget.suppressSignedInUi) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const StartupGate();
  }
}