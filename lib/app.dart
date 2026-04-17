import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'providers/theme_provider.dart';
import 'screens/app_list/app_list_screen.dart';
import 'screens/app_settings/app_settings_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/active_settings/active_settings_screen.dart';
import 'services/deep_link_service.dart';
import 'services/launch_orchestrator.dart';
import 'services/settings_service.dart';
import 'services/app_list_service.dart';
import 'services/foreground_service_controller.dart';
import 'services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database_helper.dart';

class ExpressPassApp extends StatefulWidget {
  const ExpressPassApp({super.key});

  @override
  State<ExpressPassApp> createState() => _ExpressPassAppState();
}

class _ExpressPassAppState extends State<ExpressPassApp> {
  static const _defaultSeedColor = Color(0xFFF59E0B); // Amber/gold - express pass theme
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final LaunchOrchestrator _orchestrator;
  final _db = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _orchestrator = LaunchOrchestrator(
      settingsService: SettingsService(),
      appListService: AppListService(),
      serviceController: ForegroundServiceController(),
      notificationService: NotificationService(),
    );

    // Listen for deep links when app is already running
    DeepLinkService.onDeepLink = _handleShortcutLaunch;
    DeepLinkService.init();

    // Check for cold-start deep link
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialPackage = await DeepLinkService.getInitialLink();
      if (initialPackage != null) {
        _handleShortcutLaunch(initialPackage);
      }
    });
  }

  Future<void> _handleShortcutLaunch(String packageName) async {
    // Fetch saved settings for this package from DB
    final settings = await _db.getSettingsForPackage(packageName);
    if (settings.isEmpty) {
      _showSnackBar('No settings configured for $packageName');
      return;
    }

    // Check auto-revert preference
    final prefs = await SharedPreferences.getInstance();
    final autoRevert = prefs.getBool('auto_revert_$packageName') ?? true;

    // Apply settings and launch
    final result = await _orchestrator.applyAndLaunch(
      packageName,
      settings,
      appLabel: packageName,
      autoRevert: autoRevert,
    );

    if (result.success) {
      // Close ExpressPass so it doesn't sit in the recents stack
      await DeepLinkService.closeActivity();
    } else {
      _showSnackBar(result.message);
    }
  }

  void _showSnackBar(String message) {
    final ctx = _navigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightScheme;
        ColorScheme darkScheme;

        if (themeProvider.useDynamicColor && lightDynamic != null && darkDynamic != null) {
          lightScheme = lightDynamic.harmonized();
          darkScheme = darkDynamic.harmonized();
        } else {
          lightScheme = ColorScheme.fromSeed(seedColor: _defaultSeedColor);
          darkScheme = ColorScheme.fromSeed(
            seedColor: _defaultSeedColor,
            brightness: Brightness.dark,
          );
        }

        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'ExpressPass',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            colorScheme: lightScheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkScheme,
            useMaterial3: true,
          ),
          initialRoute: '/',
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/':
                return MaterialPageRoute(
                  builder: (_) => const AppListScreen(),
                );
              case '/onboarding':
                return MaterialPageRoute(
                  builder: (_) => const OnboardingScreen(),
                );
              case '/settings':
                return MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                );
              case '/active-settings':
                return MaterialPageRoute(
                  builder: (_) => const ActiveSettingsScreen(),
                );
              case '/app-settings':
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (_) => AppSettingsScreen(
                    packageName: args['packageName'] as String,
                    appLabel: args['appLabel'] as String,
                    appIcon: args['appIcon'],
                  ),
                );
              default:
                return MaterialPageRoute(
                  builder: (_) => const AppListScreen(),
                );
            }
          },
        );
      },
    );
  }
}
