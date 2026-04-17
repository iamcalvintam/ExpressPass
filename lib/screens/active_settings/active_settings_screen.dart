import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../services/active_session_service.dart';
import '../../services/launch_orchestrator.dart';
import '../../services/settings_service.dart';
import '../../services/app_list_service.dart';
import '../../services/foreground_service_controller.dart';
import '../../services/notification_service.dart';

class ActiveSettingsScreen extends StatefulWidget {
  const ActiveSettingsScreen({super.key});

  @override
  State<ActiveSettingsScreen> createState() => _ActiveSettingsScreenState();
}

class _ActiveSettingsScreenState extends State<ActiveSettingsScreen> {
  final _sessionService = ActiveSessionService();
  final _db = DatabaseHelper();
  late final LaunchOrchestrator _orchestrator;
  List<ActiveSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _orchestrator = LaunchOrchestrator(
      settingsService: SettingsService(),
      appListService: AppListService(),
      serviceController: ForegroundServiceController(),
      notificationService: NotificationService(),
    );
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    _sessions = await _sessionService.getSessions();
    setState(() => _isLoading = false);
  }

  Future<void> _revertSession(ActiveSession session) async {
    final settings = await _db.getSettingsForPackage(session.packageName);
    if (settings.isEmpty) {
      await _sessionService.removeSession(session.packageName);
      await _loadSessions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No settings found — session removed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    await _orchestrator.revertSettings(settings);
    await _sessionService.removeSession(session.packageName);
    await _loadSessions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reverted ${session.appLabel}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _revertAll() async {
    for (final session in List.of(_sessions)) {
      final settings = await _db.getSettingsForPackage(session.packageName);
      if (settings.isNotEmpty) {
        await _orchestrator.revertSettings(settings);
      }
      await _sessionService.removeSession(session.packageName);
    }
    await _loadSessions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All settings reverted'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Settings'),
        actions: [
          if (_sessions.isNotEmpty)
            TextButton(
              onPressed: _revertAll,
              child: const Text('Revert All'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: colorScheme.primary.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No active settings',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All device settings are at their default values',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    return Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            session.appLabel.isNotEmpty
                                ? session.appLabel[0].toUpperCase()
                                : '?',
                            style: TextStyle(color: colorScheme.onPrimaryContainer),
                          ),
                        ),
                        title: Text(
                          session.appLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${session.settingsCount} setting(s) applied ${_formatTime(session.appliedAt)}',
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                        trailing: FilledButton.tonal(
                          onPressed: () => _revertSession(session),
                          child: const Text('Revert'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
