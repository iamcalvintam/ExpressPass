import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_setting.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/permission_provider.dart';
import '../../services/launch_orchestrator.dart';
import '../../services/settings_service.dart';
import '../../services/app_list_service.dart';
import '../../services/foreground_service_controller.dart';
import '../../services/shortcut_service.dart';
import 'add_setting_sheet.dart';
import 'template_picker_sheet.dart';

class AppSettingsScreen extends StatefulWidget {
  final String packageName;
  final String appLabel;
  final Uint8List? appIcon;

  const AppSettingsScreen({
    super.key,
    required this.packageName,
    required this.appLabel,
    this.appIcon,
  });

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  late final LaunchOrchestrator _orchestrator;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _orchestrator = LaunchOrchestrator(
      settingsService: SettingsService(),
      appListService: AppListService(),
      serviceController: ForegroundServiceController(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppSettingsProvider>().loadSettings(widget.packageName);
    });
  }

  Future<void> _applyAndLaunch() async {
    final provider = context.read<AppSettingsProvider>();
    final settings = provider.settings;
    if (settings.isEmpty) {
      _showStatus('No settings configured', false);
      return;
    }

    final hasPermission = context.read<PermissionProvider>().writeSecureSettings;
    if (!hasPermission) {
      _showStatus('WRITE_SECURE_SETTINGS permission not granted', false);
      return;
    }

    setState(() => _isApplying = true);
    final result = await _orchestrator.applyAndLaunch(
      widget.packageName,
      settings,
      appLabel: widget.appLabel,
      autoRevert: provider.autoRevert,
    );
    setState(() => _isApplying = false);
    _showStatus(result.message, result.success);
  }

  Future<void> _revertSettings() async {
    final settings = context.read<AppSettingsProvider>().settings;
    await _orchestrator.revertSettings(settings);
    _showStatus('Settings reverted', true);
    if (mounted) {
      context.read<AppSettingsProvider>().refreshCurrentValues();
    }
  }

  void _showStatus(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openAddSettingSheet([AppSetting? setting]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => AddSettingSheet(
        packageName: widget.packageName,
        existingSetting: setting,
        onSave: (newSetting) {
          final provider = context.read<AppSettingsProvider>();
          if (setting != null) {
            provider.updateSetting(newSetting);
          } else {
            provider.addSetting(newSetting);
          }
        },
      ),
    );
  }

  void _openTemplatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => TemplatePickerSheet(
        packageName: widget.packageName,
        onTemplatesSelected: (settings) {
          final provider = context.read<AppSettingsProvider>();
          for (final setting in settings) {
            provider.addSetting(setting);
          }
        },
      ),
    );
  }

  Future<void> _createShortcut() async {
    _showStatus('Creating shortcut...', true);
    try {
      final shortcutService = ShortcutService();
      final supported = await shortcutService.isSupported();
      if (!supported) {
        _showStatus('Shortcuts not supported on this device', false);
        return;
      }
      final success = await shortcutService.requestPinShortcut(
        widget.packageName,
        widget.appLabel,
        widget.appIcon,
      );
      _showStatus(
        success ? 'Drag shortcut to place it' : 'Failed to create shortcut',
        success,
      );
    } catch (e) {
      _showStatus('Error creating shortcut: $e', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppSettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final hasSettings = provider.settings.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Hero(
              tag: 'app_icon_${widget.packageName}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: widget.appIcon != null
                    ? Image.memory(widget.appIcon!, width: 36, height: 36)
                    : Icon(Icons.android, size: 36, color: colorScheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.appLabel,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.settings.isEmpty
              ? _EmptyState(
                  colorScheme: colorScheme,
                  onAddTemplate: _openTemplatePicker,
                  onAddManual: () => _openAddSettingSheet(),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 100),
                  itemCount: provider.settings.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _AutoRevertToggle(
                        colorScheme: colorScheme,
                        value: provider.autoRevert,
                        onChanged: (v) => provider.setAutoRevert(v),
                      );
                    }
                    final setting = provider.settings[index - 1];
                    final currentValue = provider.currentValues[setting.key];
                    return _SettingCard(
                      setting: setting,
                      currentValue: currentValue,
                      colorScheme: colorScheme,
                      onToggle: () => provider.toggleSetting(setting),
                      onEdit: () => _openAddSettingSheet(setting),
                      onDelete: () => provider.deleteSetting(setting.id!),
                    );
                  },
                ),
      bottomNavigationBar: _BottomActionBar(
        colorScheme: colorScheme,
        hasSettings: hasSettings,
        isApplying: _isApplying,
        onLaunch: _applyAndLaunch,
        onRevert: _revertSettings,
        onTemplate: _openTemplatePicker,
        onShortcut: _createShortcut,
        onAddSetting: () => _openAddSettingSheet(),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final ColorScheme colorScheme;
  final bool hasSettings;
  final bool isApplying;
  final VoidCallback onLaunch;
  final VoidCallback onRevert;
  final VoidCallback onTemplate;
  final VoidCallback onShortcut;
  final VoidCallback onAddSetting;

  const _BottomActionBar({
    required this.colorScheme,
    required this.hasSettings,
    required this.isApplying,
    required this.onLaunch,
    required this.onRevert,
    required this.onTemplate,
    required this.onShortcut,
    required this.onAddSetting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Secondary action row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionIconButton(
                    icon: Icons.undo_rounded,
                    label: 'Revert',
                    onTap: hasSettings ? onRevert : null,
                    colorScheme: colorScheme,
                  ),
                  _ActionIconButton(
                    icon: Icons.auto_fix_high,
                    label: 'Templates',
                    onTap: onTemplate,
                    colorScheme: colorScheme,
                  ),
                  _ActionIconButton(
                    icon: Icons.add_circle_outline,
                    label: 'Add',
                    onTap: onAddSetting,
                    colorScheme: colorScheme,
                  ),
                  _ActionIconButton(
                    icon: Icons.add_to_home_screen,
                    label: 'Shortcut',
                    onTap: hasSettings ? onShortcut : null,
                    colorScheme: colorScheme,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Primary launch button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: isApplying || !hasSettings ? null : onLaunch,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isApplying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Apply & Launch',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final ColorScheme colorScheme;

  const _ActionIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final color = isEnabled
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurfaceVariant.withOpacity(0.35);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoRevertToggle extends StatelessWidget {
  final ColorScheme colorScheme;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AutoRevertToggle({
    required this.colorScheme,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(
                value ? Icons.sync_rounded : Icons.sync_disabled_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auto-revert',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      value
                          ? 'Settings revert when app is closed'
                          : 'You must revert settings manually',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final AppSetting setting;
  final String? currentValue;
  final ColorScheme colorScheme;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SettingCard({
    required this.setting,
    this.currentValue,
    required this.colorScheme,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  Color _chipColor() {
    return switch (setting.settingType) {
      SettingType.system => Colors.blue,
      SettingType.secure => Colors.orange,
      SettingType.global => Colors.purple,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Dismissible(
        key: ValueKey(setting.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: colorScheme.error,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) => onDelete(),
        child: Card(
          elevation: 0,
          color: setting.enabled
              ? colorScheme.surfaceContainerLow
              : colorScheme.surfaceContainerLow.withOpacity(0.5),
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _chipColor().withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          setting.settingType.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _chipColor(),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: setting.enabled,
                        onChanged: (_) => onToggle(),
                      ),
                    ],
                  ),
                  Text(
                    setting.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          setting.enabled ? null : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    setting.key,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _ValueChip(
                        label: 'Current',
                        value: currentValue ?? '?',
                        color: colorScheme.tertiary,
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      _ValueChip(
                        label: 'Launch',
                        value: setting.valueOnLaunch,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_back,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      _ValueChip(
                        label: 'Revert',
                        value: setting.valueOnRevert,
                        color: colorScheme.secondary,
                      ),
                    ],
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

class _ValueChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ValueChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style:
            TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  final VoidCallback onAddTemplate;
  final VoidCallback onAddManual;

  const _EmptyState({
    required this.colorScheme,
    required this.onAddTemplate,
    required this.onAddManual,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 72,
              color: colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            Text(
              'No settings configured',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose from common templates or add settings manually',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddTemplate,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Use Templates'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onAddManual,
              icon: const Icon(Icons.add),
              label: const Text('Add Manually'),
            ),
          ],
        ),
      ),
    );
  }
}
