import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/l10n/app_localizations.dart';

import 'package:luci_mobile/state/app_state.dart';
import 'package:luci_mobile/screens/login_screen.dart';
import 'package:luci_mobile/screens/main_screen.dart';
import 'package:luci_mobile/screens/settings_screen.dart';
import 'package:luci_mobile/screens/splash_screen.dart';

void main() {
  runApp(ProviderScope(child: const LuCIApp()));
}

final appStateProvider = ChangeNotifierProvider<AppState>(
  (ref) => AppState.instance,
);

class LuCIApp extends ConsumerStatefulWidget {
  const LuCIApp({super.key});

  @override
  ConsumerState<LuCIApp> createState() => _LuCIAppState();
}

class _LuCIAppState extends ConsumerState<LuCIApp> with WidgetsBindingObserver {
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasInBackground = true;
      ref.read(appStateProvider).pauseDashboardVitalsPolling();
    }
    if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      unawaited(ref.read(appStateProvider).onAppResumed());
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    // Note: title is used for system app name, using English default
    // The actual app title is displayed in screens using AppLocalizations
    return MaterialApp(
      title: 'LuCI Mobile',
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('zh', ''),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        // Edge-to-edge display handled natively in MainActivity
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        // Edge-to-edge display handled natively in MainActivity
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      themeMode: appState.themeMode,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/': (context) => const MainScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
