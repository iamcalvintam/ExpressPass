import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<PermissionProvider>().checkAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final permissions = context.watch<PermissionProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Appearance section
          _SectionHeader(title: 'Appearance', colorScheme: colorScheme),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android, size: 16)),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 16)),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 16)),
              ],
              selected: {themeProvider.themeMode},
              onSelectionChanged: (selected) {
                themeProvider.setThemeMode(selected.first);
              },
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.color_lens_outlined),
            title: const Text('Dynamic Color'),
            subtitle: const Text('Use Material You wallpaper colors'),
            value: themeProvider.useDynamicColor,
            onChanged: (value) => themeProvider.setDynamicColor(value),
          ),
          const Divider(),

          // Permissions section
          _SectionHeader(title: 'Permissions', colorScheme: colorScheme),
          _PermissionTile(
            icon: Icons.terminal,
            title: 'Secure Settings',
            subtitle: 'Required to modify device settings',
            isGranted: permissions.writeSecureSettings,
            onTap: () async {
              final cmd = await permissions.getAdbCommand();
              if (mounted) {
                Clipboard.setData(ClipboardData(text: cmd));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ADB command copied to clipboard')),
                );
              }
            },
          ),
          _PermissionTile(
            icon: Icons.analytics_outlined,
            title: 'Usage Access',
            subtitle: permissions.usageStats
                ? 'Permission granted'
                : 'Tap to grant usage access',
            isGranted: permissions.usageStats,
            onTap: () async {
              await permissions.requestUsageStats();
            },
          ),
          _PermissionTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: permissions.notifications
                ? 'Tap to open notification settings'
                : 'Tap to grant notification permission',
            isGranted: permissions.notifications,
            onTap: () async {
              if (!permissions.notifications) {
                final granted = await permissions.requestNotifications();
                if (!granted && mounted) {
                  // Runtime request was denied or unavailable, open system settings
                  await permissions.openNotificationSettings();
                }
              } else {
                await permissions.openNotificationSettings();
              }
              // Re-check after returning from settings
              if (mounted) {
                await Future.delayed(const Duration(milliseconds: 500));
                permissions.checkAll();
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: () => permissions.checkAll(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Permissions'),
            ),
          ),
          const Divider(),

          // About section
          _SectionHeader(title: 'About', colorScheme: colorScheme),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('ExpressPass'),
            subtitle: Text('Version 1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open Source Licenses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(context: context, applicationName: 'ExpressPass'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ColorScheme colorScheme;

  const _SectionHeader({required this.title, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isGranted;
  final VoidCallback? onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        isGranted ? Icons.check_circle : Icons.cancel,
        color: isGranted ? Colors.green : Colors.red,
      ),
      onTap: onTap,
    );
  }
}
