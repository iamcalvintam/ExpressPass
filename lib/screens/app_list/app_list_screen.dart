import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/app_list_provider.dart';
import '../../providers/permission_provider.dart';
import '../../models/installed_app.dart';

/// LRU icon cache — caps at 100 entries to avoid unbounded memory growth.
final _iconCache = _LruCache<String, MemoryImage>(100);

MemoryImage _getCachedIcon(Uint8List bytes, String packageName) {
  final cached = _iconCache.get(packageName);
  if (cached != null) return cached;
  final image = MemoryImage(bytes);
  _iconCache.put(packageName, image);
  return image;
}

class _LruCache<K, V> {
  final int maxSize;
  final _map = <K, V>{};

  _LruCache(this.maxSize);

  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) _map[key] = value; // Move to end (most recent)
    return value;
  }

  void put(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    while (_map.length > maxSize) {
      _map.remove(_map.keys.first); // Evict oldest
    }
  }
}

class AppListScreen extends StatefulWidget {
  const AppListScreen({super.key});

  @override
  State<AppListScreen> createState() => _AppListScreenState();
}

class _AppListScreenState extends State<AppListScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final onboarded = prefs.getBool('onboardingComplete') ?? false;
      if (!onboarded && mounted) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
        return;
      }
      if (mounted) {
        context.read<PermissionProvider>().checkAll();
        context.read<AppListProvider>().loadApps();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showTagPicker(InstalledApp app) {
    final appList = context.read<AppListProvider>();
    final currentTag = appList.appTags[app.packageName];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Text(
                'Tag "${app.label}"',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (currentTag != null)
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Remove tag'),
                onTap: () {
                  appList.setAppTag(app.packageName, null);
                  Navigator.of(ctx).pop();
                },
              ),
            ...AppListProvider.availableTags.map((tag) => ListTile(
              leading: Icon(
                tag == currentTag ? Icons.check_circle : Icons.circle_outlined,
                color: tag == currentTag ? Theme.of(ctx).colorScheme.primary : null,
              ),
              title: Text(tag),
              onTap: () {
                appList.setAppTag(app.packageName, tag);
                Navigator.of(ctx).pop();
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _openAppSettings(InstalledApp app) {
    Navigator.of(context).pushNamed(
      '/app-settings',
      arguments: {
        'packageName': app.packageName,
        'appLabel': app.label,
        'appIcon': app.icon,
      },
    ).then((_) {
      context.read<AppListProvider>().refreshSettingsCounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appList = context.watch<AppListProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search apps...',
                  border: InputBorder.none,
                ),
                onChanged: (query) => appList.setSearchQuery(query),
              )
            : const Text('ExpressPass'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  appList.setSearchQuery('');
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Active Settings',
            onPressed: () => Navigator.of(context).pushNamed('/active-settings'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: _buildBody(appList, colorScheme),
    );
  }

  Widget _buildBody(AppListProvider appList, ColorScheme colorScheme) {
    if (appList.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (appList.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(appList.error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => appList.loadApps(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (appList.apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apps_rounded, size: 64,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              appList.searchQuery.isEmpty ? 'No apps found' : 'No matching apps',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    final configured = appList.configuredApps;

    return RefreshIndicator(
      onRefresh: () => appList.loadApps(),
      child: CustomScrollView(
        slivers: [
          // Configured apps section
          if (configured.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Configured Apps',
                icon: Icons.star_rounded,
                colorScheme: colorScheme,
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: configured.length,
                  itemBuilder: (context, index) {
                    return _ConfiguredAppChip(
                      app: configured[index],
                      colorScheme: colorScheme,
                      onTap: () => _openAppSettings(configured[index]),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(
                child: Divider(height: 1, indent: 16, endIndent: 16)),
          ],
          // Tag filter chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: appList.activeTagFilter == null,
                      onSelected: (_) => appList.setTagFilter(null),
                    ),
                  ),
                  ...AppListProvider.availableTags.map((tag) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(tag),
                      selected: appList.activeTagFilter == tag,
                      onSelected: (_) => appList.setTagFilter(
                        appList.activeTagFilter == tag ? null : tag,
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ),
          // All apps section header
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'All Apps',
              icon: Icons.apps_rounded,
              colorScheme: colorScheme,
            ),
          ),
          // All apps grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.88,
                mainAxisSpacing: 0,
                crossAxisSpacing: 0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final app = appList.apps[index];
                  return _AppGridItem(
                    app: app,
                    colorScheme: colorScheme,
                    tag: appList.appTags[app.packageName],
                    onTap: () => _openAppSettings(app),
                    onLongPress: () => _showTagPicker(app),
                  );
                },
                childCount: appList.apps.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final ColorScheme colorScheme;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ConfiguredAppChip extends StatelessWidget {
  final InstalledApp app;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _ConfiguredAppChip({
    required this.app,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'app_icon_${app.packageName}',
                  child: _AppIcon(icon: app.icon, packageName: app.packageName, size: 60, radius: 16, colorScheme: colorScheme),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${app.settingsCount}',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              app.label,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppGridItem extends StatelessWidget {
  final InstalledApp app;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? tag;

  const _AppGridItem({
    required this.app,
    required this.colorScheme,
    required this.onTap,
    this.onLongPress,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AppIcon(icon: app.icon, packageName: app.packageName, size: 48, radius: 12, colorScheme: colorScheme),
            const SizedBox(height: 4),
            Text(
              app.label,
              style: const TextStyle(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (tag != null)
              Text(
                tag!,
                style: TextStyle(fontSize: 9, color: colorScheme.primary),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shared widget for app icons with image caching and downscaled decode.
class _AppIcon extends StatelessWidget {
  final Uint8List? icon;
  final String packageName;
  final double size;
  final double radius;
  final ColorScheme colorScheme;

  const _AppIcon({
    required this.icon,
    required this.packageName,
    required this.size,
    required this.radius,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final pixelSize = (size * MediaQuery.devicePixelRatioOf(context)).toInt();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: icon != null
          ? Image(
              image: ResizeImage(
                _getCachedIcon(icon!, packageName),
                width: pixelSize,
                height: pixelSize,
              ),
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
            )
          : Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Icon(Icons.android, color: colorScheme.onSurfaceVariant),
            ),
    );
  }
}
