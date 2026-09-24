import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/data_service.dart';
import 'services/settings_service.dart';
import 'services/progress_service.dart';
import 'services/stats_service.dart';
import 'services/audio_service.dart';
import 'services/route_observer.dart';
import 'theming/theme_definition.dart';
import 'theming/theme_controller.dart';
import 'theming/theme_scope.dart';
import 'theming/theme_tokens.dart';
import 'widgets/themed/themed_surface.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // TEMPORARY DIAGNOSTIC (v1.5.0): Flutter's default release-mode
  // ErrorWidget renders as a blank box with no text, to avoid leaking
  // stack traces to end users -- which makes a real build-time bug
  // indistinguishable from "nothing happened". This override shows the
  // actual exception on screen instead, so a crash is visible and
  // reportable instead of silently blank. Safe to leave in during
  // development; revert to the default (remove this block) once the app
  // is confirmed stable.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF200000),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            details.exceptionAsString(),
            style: const TextStyle(color: Color(0xFFFF8080), fontSize: 12),
          ),
        ),
      ),
    );
  };

  runApp(const NihongoTrainerApp());
}

class NihongoTrainerApp extends StatelessWidget {
  const NihongoTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(create: (_) => ProgressService()),
        ChangeNotifierProvider(create: (_) => StatsService()),
        ChangeNotifierProvider(create: (_) => AudioService()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      // Only the MaterialApp is rebuilt when the theme changes -- the
      // Navigator and everything in it keeps its state, so switching themes
      // mid-lesson doesn't lose your place, your score or your review queue.
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          final theme = themeController.theme;
          return MaterialApp(
            title: 'Nihongo Trainer',
            debugShowCheckedModeBanner: false,
            theme: theme.buildMaterialTheme(),
            navigatorObservers: [appRouteObserver],
            // builder wraps the Navigator, so every pushed route sees the
            // ThemeScope -- not just the home screen.
            builder: (context, child) => ThemeScope(
              theme: theme,
              effectsEnabled: themeController.effectsEnabled,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const _AppLoader(),
          );
        },
      ),
    );
  }
}

/// Loads the bundled JSON data and saved settings once before showing the
/// home screen, with a small branded splash while that happens (it's fast
/// -- well under a second on-device -- but never assume zero).
class _AppLoader extends StatefulWidget {
  const _AppLoader();

  @override
  State<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<_AppLoader> {
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = _load();
  }

  Future<void> _load() async {
    await Future.wait([
      DataService.instance.load(),
      context.read<SettingsService>().load(),
      context.read<ProgressService>().load(),
      context.read<StatsService>().load(),
      context.read<AudioService>().load(),
      context.read<ThemeController>().load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SplashScreen();
        }
        if (snapshot.hasError) {
          return _ErrorScreen(error: snapshot.error.toString());
        }
        return const HomeScreen();
      },
    );
  }
}

/// The launch screen. It runs before preferences have been read, so it shows
/// the default theme's backdrop; a moment later the saved theme takes over.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final t = theme.tokens;

    return Scaffold(
      body: theme.buildBackground(
        context,
        const BackgroundRequest(userBackground: null, userDimOpacity: 0),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ThemedSurface(
                level: SurfaceLevel.elevated,
                radius: t.radii.lg,
                allowHeavyEffects: false,
                padding: EdgeInsets.symmetric(
                  horizontal: t.spacing.xl,
                  vertical: t.spacing.lg,
                ),
                child: Text('文', style: t.text.jp(64, weight: FontWeight.w700)),
              ),
              SizedBox(height: t.spacing.lg),
              Text(
                'NIHONGO TRAINER',
                style: t.text.overline.copyWith(letterSpacing: 4),
              ),
              SizedBox(height: t.spacing.lg),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: t.colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final t = theme.tokens;

    return Scaffold(
      body: theme.buildBackground(
        context,
        const BackgroundRequest(userBackground: null, userDimOpacity: 0),
        Center(
          child: Padding(
            padding: EdgeInsets.all(t.spacing.lg),
            child: ThemedSurface(
              level: SurfaceLevel.elevated,
              radius: t.radii.lg,
              allowHeavyEffects: false,
              tint: t.colors.bad,
              tintStrength: 0.5,
              padding: EdgeInsets.all(t.spacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: t.colors.bad, size: 30),
                  SizedBox(height: t.spacing.sm),
                  Text(
                    'Something went wrong loading the app data:\n$error',
                    textAlign: TextAlign.center,
                    style: t.text.body,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
