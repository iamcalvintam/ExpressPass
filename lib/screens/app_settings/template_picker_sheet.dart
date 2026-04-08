import 'package:flutter/material.dart';
import '../../models/app_setting.dart';
import '../../models/setting_template.dart';
import '../../services/template_service.dart';

class TemplatePickerSheet extends StatefulWidget {
  final String packageName;
  final ValueChanged<List<AppSetting>> onTemplatesSelected;

  const TemplatePickerSheet({
    super.key,
    required this.packageName,
    required this.onTemplatesSelected,
  });

  @override
  State<TemplatePickerSheet> createState() => _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends State<TemplatePickerSheet> {
  final _templateService = TemplateService();
  List<SettingTemplate> _templates = [];
  final Set<int> _selectedIndices = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    _templates = await _templateService.getTemplates();
    setState(() => _isLoading = false);
  }

  void _apply() {
    final settings = _selectedIndices.map((i) {
      return _templates[i].toAppSetting(widget.packageName);
    }).toList();
    widget.onTemplatesSelected(settings);
    Navigator.of(context).pop();
  }

  Color _typeColor(SettingType type) {
    return switch (type) {
      SettingType.system => Colors.blue,
      SettingType.secure => Colors.orange,
      SettingType.global => Colors.purple,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
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
            'Setting Templates',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select templates to add to this app',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _templates.length,
                itemBuilder: (context, index) {
                  final t = _templates[index];
                  final selected = _selectedIndices.contains(index);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      elevation: 0,
                      color: selected
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerLow,
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _typeColor(t.settingType).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t.settingType.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _typeColor(t.settingType),
                            ),
                          ),
                        ),
                        title: Text(t.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          t.description.isNotEmpty ? t.description : t.key,
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                        trailing: selected
                            ? Icon(Icons.check_circle, color: colorScheme.primary)
                            : const Icon(Icons.circle_outlined),
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedIndices.remove(index);
                            } else {
                              _selectedIndices.add(index);
                            }
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedIndices.isEmpty ? null : _apply,
              child: Text('Add ${_selectedIndices.length} Template${_selectedIndices.length == 1 ? '' : 's'}'),
            ),
          ),
        ],
      ),
    );
  }
}
