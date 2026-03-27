import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/permission_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  final _pageController = PageController();
  int _currentPage = 0;
  static const _totalPages = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PermissionProvider>().checkAll();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<PermissionProvider>().checkAll();
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _WelcomePage(colorScheme: colorScheme),
                  _AdbPermissionPage(
                    colorScheme: colorScheme,
                    isGranted: permissions.writeSecureSettings,
                    onCheck: () => permissions.checkAll(),
                  ),
                  _UsageStatsPage(
                    colorScheme: colorScheme,
                    isGranted: permissions.usageStats,
                    onRequest: () => permissions.requestUsageStats(),
                    onCheck: () => permissions.checkAll(),
                  ),
                  _NotificationPermissionPage(
                    colorScheme: colorScheme,
                    isGranted: permissions.notifications,
                    onRequest: () async {
                      final granted = await permissions.requestNotifications();
                      if (!granted && mounted) {
                        await permissions.openNotificationSettings();
                      }
                    },
                    onCheck: () => permissions.checkAll(),
                  ),
                  _CompletePage(
                    colorScheme: colorScheme,
                    allGranted: permissions.allGranted,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page indicators
                  Row(
                    children: List.generate(_totalPages, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? colorScheme.primary
                              : colorScheme.primary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  FilledButton.icon(
                    onPressed: _nextPage,
                    icon: Icon(_currentPage < _totalPages - 1 ? Icons.arrow_forward : Icons.check),
                    label: Text(_currentPage < _totalPages - 1 ? 'Next' : 'Get Started'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final ColorScheme colorScheme;
  const _WelcomePage({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/logo.png',
            width: 120,
            height: 120,
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to ExpressPass',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Temporarily modify device settings before launching sensitive apps like banking, then automatically revert them when you\'re done.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AdbPermissionPage extends StatelessWidget {
  final ColorScheme colorScheme;
  final bool isGranted;
  final VoidCallback onCheck;

  const _AdbPermissionPage({
    required this.colorScheme,
    required this.isGranted,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    const adbCommand = 'adb shell pm grant com.expresspass.expresspass android.permission.WRITE_SECURE_SETTINGS';

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isGranted ? Icons.check_circle : Icons.terminal_rounded,
            size: 64,
            color: isGranted ? Colors.green : colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Secure Settings Permission',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'This permission is required to modify device settings. Connect your device to a computer and run the following ADB command:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    adbCommand,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: adbCommand));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ADB command copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onCheck,
            icon: const Icon(Icons.refresh),
            label: const Text('Check Permission'),
          ),
          if (isGranted) ...[
            const SizedBox(height: 12),
            Chip(
              avatar: const Icon(Icons.check, size: 18, color: Colors.green),
              label: const Text('Permission Granted'),
              backgroundColor: Colors.green.withOpacity(0.1),
            ),
          ],
        ],
      ),
    );
  }
}

class _UsageStatsPage extends StatelessWidget {
  final ColorScheme colorScheme;
  final bool isGranted;
  final VoidCallback onRequest;
  final VoidCallback onCheck;

  const _UsageStatsPage({
    required this.colorScheme,
    required this.isGranted,
    required this.onRequest,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isGranted ? Icons.check_circle : Icons.analytics_rounded,
            size: 64,
            color: isGranted ? Colors.green : colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Usage Access Permission',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'This permission allows ExpressPass to detect when you leave a banking app, so it can automatically revert your settings.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!isGranted) ...[
            FilledButton.icon(
              onPressed: onRequest,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Settings'),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: onCheck,
            icon: const Icon(Icons.refresh),
            label: const Text('Check Permission'),
          ),
          if (isGranted) ...[
            const SizedBox(height: 12),
            Chip(
              avatar: const Icon(Icons.check, size: 18, color: Colors.green),
              label: const Text('Permission Granted'),
              backgroundColor: Colors.green.withOpacity(0.1),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationPermissionPage extends StatelessWidget {
  final ColorScheme colorScheme;
  final bool isGranted;
  final VoidCallback onRequest;
  final VoidCallback onCheck;

  const _NotificationPermissionPage({
    required this.colorScheme,
    required this.isGranted,
    required this.onRequest,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isGranted ? Icons.check_circle : Icons.notifications_rounded,
            size: 64,
            color: isGranted ? Colors.green : colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Notification Permission',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'ExpressPass sends notifications when settings are applied or reverted, so you always know what\'s happening with your device.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!isGranted) ...[
            FilledButton.icon(
              onPressed: onRequest,
              icon: const Icon(Icons.notifications_active),
              label: const Text('Allow Notifications'),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: onCheck,
            icon: const Icon(Icons.refresh),
            label: const Text('Check Permission'),
          ),
          if (isGranted) ...[
            const SizedBox(height: 12),
            Chip(
              avatar: const Icon(Icons.check, size: 18, color: Colors.green),
              label: const Text('Permission Granted'),
              backgroundColor: Colors.green.withOpacity(0.1),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletePage extends StatelessWidget {
  final ColorScheme colorScheme;
  final bool allGranted;

  const _CompletePage({
    required this.colorScheme,
    required this.allGranted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          allGranted
              ? Image.asset('assets/logo.png', width: 100, height: 100)
              : Icon(
                  Icons.warning_amber_rounded,
                  size: 80,
                  color: Colors.orange,
                ),
          const SizedBox(height: 24),
          Text(
            allGranted ? 'You\'re All Set!' : 'Almost There',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            allGranted
                ? 'All permissions are granted. You can now configure apps and launch them with modified settings.'
                : 'Some permissions are missing. You can still use ExpressPass, but some features may not work correctly. You can grant them later in Settings.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
