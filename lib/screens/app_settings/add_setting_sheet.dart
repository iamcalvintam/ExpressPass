import 'package:flutter/material.dart';
import '../../models/app_setting.dart';
import '../../services/settings_service.dart';

class AddSettingSheet extends StatefulWidget {
  final String packageName;
  final AppSetting? existingSetting;
  final ValueChanged<AppSetting> onSave;

  const AddSettingSheet({
    super.key,
    required this.packageName,
    this.existingSetting,
    required this.onSave,
  });

  @override
  State<AddSettingSheet> createState() => _AddSettingSheetState();
}

class _AddSettingSheetState extends State<AddSettingSheet> {
  late SettingType _settingType;
  late final TextEditingController _labelController;
  late final TextEditingController _keyController;
  late final TextEditingController _launchValueController;
  late final TextEditingController _revertValueController;
  final _formKey = GlobalKey<FormState>();
  final _settingsService = SettingsService();
  bool _isReadingValue = false;

  @override
  void initState() {
    super.initState();
    final s = widget.existingSetting;
    _settingType = s?.settingType ?? SettingType.global;
    _labelController = TextEditingController(text: s?.label ?? '');
    _keyController = TextEditingController(text: s?.key ?? '');
    _launchValueController = TextEditingController(text: s?.valueOnLaunch ?? '');
    _revertValueController = TextEditingController(text: s?.valueOnRevert ?? '');
  }

  @override
  void dispose() {
    _labelController.dispose();
    _keyController.dispose();
    _launchValueController.dispose();
    _revertValueController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final setting = AppSetting(
      id: widget.existingSetting?.id,
      packageName: widget.packageName,
      enabled: widget.existingSetting?.enabled ?? true,
      settingType: _settingType,
      label: _labelController.text.trim().isEmpty
          ? _keyController.text.trim()
          : _labelController.text.trim(),
      key: _keyController.text.trim(),
      valueOnLaunch: _launchValueController.text.trim(),
      valueOnRevert: _revertValueController.text.trim(),
    );

    widget.onSave(setting);
    Navigator.of(context).pop();
  }

  Future<void> _readCurrentValue() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    setState(() => _isReadingValue = true);
    final value = await _settingsService.readSetting(_settingType, key);
    setState(() => _isReadingValue = false);

    if (value != null) {
      _revertValueController.text = value;
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read current value'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = widget.existingSetting != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 24, 24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isEditing ? 'Edit Setting' : 'Add Setting',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Setting Type',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<SettingType>(
                segments: const [
                  ButtonSegment(value: SettingType.system, label: Text('System')),
                  ButtonSegment(value: SettingType.secure, label: Text('Secure')),
                  ButtonSegment(value: SettingType.global, label: Text('Global')),
                ],
                selected: {_settingType},
                onSelectionChanged: (selected) {
                  setState(() => _settingType = selected.first);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _keyController,
                decoration: const InputDecoration(
                  labelText: 'Setting Key',
                  hintText: 'e.g., development_settings_enabled',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label (optional)',
                  hintText: 'e.g., Disable Developer Options',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _launchValueController,
                      decoration: const InputDecoration(
                        labelText: 'Value on Launch',
                        hintText: 'e.g., 0',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _revertValueController,
                      decoration: InputDecoration(
                        labelText: 'Value on Revert',
                        hintText: 'e.g., 1',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: _isReadingValue
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download_rounded, size: 20),
                          tooltip: 'Read current device value',
                          onPressed: _isReadingValue ? null : _readCurrentValue,
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(isEditing ? 'Update' : 'Add Setting'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
