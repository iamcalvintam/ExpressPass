import 'package:flutter/material.dart';
import '../../models/app_setting.dart';
import '../../models/setting_template.dart';
import '../../services/template_service.dart';

class TemplatePickerSheet extends StatefulWidget {
  final String packageName;
  final ValueChanged<List<AppSetting>> onTemplatesSelected;
  final List<AppSetting> existingSettings;

  const TemplatePickerSheet({
    super.key,
    required this.packageName,
    required this.onTemplatesSelected,
    this.existingSettings = const [],
  });

  @override
  State<TemplatePickerSheet> createState() => _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends State<TemplatePickerSheet> {
  final _templateService = TemplateService();
  List<SettingTemplate> _templates = [];
  final Set<int> _selectedIndices = {};
  bool _isLoading = true;
  String _searchQuery = '';

  static const _categoryOrder = [
    'My Templates',
    'Security',
    'Display',
    'Audio',
    'Performance',
    'Connectivity',
    'Misc',
  ];

  static const _categoryIcons = {
    'My Templates': Icons.star_outlined,
    'Security': Icons.shield_outlined,
    'Display': Icons.brightness_6_outlined,
    'Audio': Icons.volume_up_outlined,
    'Performance': Icons.speed_outlined,
    'Connectivity': Icons.wifi_outlined,
    'Misc': Icons.tune_outlined,
  };

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

  /// Returns the set of keys that are selected more than once or conflict with existing settings.
  Set<String> get _conflictingKeys {
    final selectedKeys = <String, int>{};
    for (final i in _selectedIndices) {
      final key = _templates[i].key;
      selectedKeys[key] = (selectedKeys[key] ?? 0) + 1;
    }
    final conflicts = <String>{};
    // Keys selected more than once
    for (final entry in selectedKeys.entries) {
      if (entry.value > 1) conflicts.add(entry.key);
    }
    // Keys that already exist in the app's settings
    final existingKeys = widget.existingSettings.map((s) => s.key).toSet();
    for (final key in selectedKeys.keys) {
      if (existingKeys.contains(key)) conflicts.add(key);
    }
    return conflicts;
  }

  List<SettingTemplate> get _filteredTemplates {
    if (_searchQuery.isEmpty) return _templates;
    final q = _searchQuery.toLowerCase();
    return _templates.where((t) {
      return t.label.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q) ||
          t.key.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q);
    }).toList();
  }

  Map<String, List<(SettingTemplate, int)>> get _groupedTemplates {
    final filtered = _filteredTemplates;
    final grouped = <String, List<(SettingTemplate, int)>>{};
    for (final t in filtered) {
      final globalIndex = _templates.indexOf(t);
      grouped.putIfAbsent(t.category, () => []).add((t, globalIndex));
    }
    // Sort by category order
    final sorted = <String, List<(SettingTemplate, int)>>{};
    for (final cat in _categoryOrder) {
      if (grouped.containsKey(cat)) sorted[cat] = grouped[cat]!;
    }
    // Add any remaining categories not in the order
    for (final entry in grouped.entries) {
      if (!sorted.containsKey(entry.key)) sorted[entry.key] = entry.value;
    }
    return sorted;
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
    final conflicts = _conflictingKeys;

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
          const SizedBox(height: 12),
          // Search field
          TextField(
            decoration: InputDecoration(
              hintText: 'Search templates...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHigh,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Flexible(
              child: _buildGroupedList(colorScheme, conflicts),
            ),
          if (conflicts.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: colorScheme.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Some templates modify the same setting and will override each other',
                    style: TextStyle(fontSize: 11, color: colorScheme.error),
                  ),
                ),
              ],
            ),
          ],
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

  Widget _buildGroupedList(ColorScheme colorScheme, Set<String> conflicts) {
    final grouped = _groupedTemplates;
    if (grouped.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No templates match your search',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: grouped.entries.fold<int>(0, (sum, e) => sum + 1 + e.value.length),
      itemBuilder: (context, index) {
        var current = 0;
        for (final entry in grouped.entries) {
          // Category header
          if (index == current) {
            return _buildCategoryHeader(entry.key, colorScheme);
          }
          current++;
          // Templates in this category
          for (final (template, globalIndex) in entry.value) {
            if (index == current) {
              return _buildTemplateItem(
                template, globalIndex, colorScheme, conflicts,
              );
            }
            current++;
          }
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCategoryHeader(String category, ColorScheme colorScheme) {
    final icon = _categoryIcons[category] ?? Icons.tune_outlined;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            category,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateItem(
    SettingTemplate t,
    int globalIndex,
    ColorScheme colorScheme,
    Set<String> conflicts,
  ) {
    final selected = _selectedIndices.contains(globalIndex);
    final hasConflict = selected && conflicts.contains(t.key);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Card(
        elevation: 0,
        color: selected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerLow,
        shape: hasConflict
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colorScheme.error, width: 1),
              )
            : null,
        child: ListTile(
          dense: true,
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
          title: Text(t.label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          subtitle: Text(
            t.description.isNotEmpty ? t.description : t.key,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
          trailing: hasConflict
              ? Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 20)
              : selected
                  ? Icon(Icons.check_circle, color: colorScheme.primary)
                  : const Icon(Icons.circle_outlined),
          onTap: () {
            setState(() {
              if (selected) {
                _selectedIndices.remove(globalIndex);
              } else {
                _selectedIndices.add(globalIndex);
              }
            });
          },
        ),
      ),
    );
  }
}
