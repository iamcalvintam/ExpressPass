import 'dart:typed_data';

class InstalledApp {
  final String packageName;
  final String label;
  final Uint8List? icon;
  final int settingsCount;

  const InstalledApp({
    required this.packageName,
    required this.label,
    this.icon,
    this.settingsCount = 0,
  });

  InstalledApp copyWith({int? settingsCount}) {
    return InstalledApp(
      packageName: packageName,
      label: label,
      icon: icon,
      settingsCount: settingsCount ?? this.settingsCount,
    );
  }
}
