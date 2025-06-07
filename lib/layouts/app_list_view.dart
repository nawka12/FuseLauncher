import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import '../app_sections.dart';
import '../sort_options.dart';
import 'dart:async';
import 'app_layout_manager.dart';
import '../database/app_database.dart';
import '../models/folder.dart';

class AppListView extends StatefulWidget {
  final List<AppInfo> apps;
  final List<Folder> folders;
  final List<AppInfo> pinnedApps;
  final bool showingHiddenApps;
  final Function(BuildContext, AppInfo, bool, {VoidCallback? onAppRemoved})
      onAppLongPress;
  final bool isSelectingAppsToHide;
  final List<String> hiddenApps;
  final void Function(String) onAppLaunch;
  final VoidCallback onFoldersChanged;
  final AppListSortType sortType;
  final Map<String, int> notificationCounts;
  final bool showNotificationBadges;
  final TextEditingController searchController;

  const AppListView({
    super.key,
    required this.apps,
    required this.folders,
    required this.pinnedApps,
    required this.showingHiddenApps,
    required this.onAppLongPress,
    required this.isSelectingAppsToHide,
    required this.hiddenApps,
    required this.onAppLaunch,
    required this.onFoldersChanged,
    required this.sortType,
    required this.notificationCounts,
    required this.showNotificationBadges,
    required this.searchController,
  });

  @override
  State<AppListView> createState() => _AppListViewState();
}

class _AppListViewState extends State<AppListView> {
  final Map<String, Uint8List> _iconCache = {};
  final int _maxCacheSize = 50;
  final ScrollController _scrollController = ScrollController();
  String? _currentSection;
  bool _isScrolling = false;
  Timer? _scrollEndTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    // Update scrolling state
    if (!_isScrolling) {
      setState(() {
        _isScrolling = true;
      });
    }

    // Reset timer on each scroll event
    _scrollEndTimer?.cancel();
    _scrollEndTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isScrolling = false;
        });
      }
    });

    if (widget.sortType != AppListSortType.usage) {
      final sections = AppSectionManager.createSections(_filteredApps);
      if (sections.isEmpty) return;
      double offset = 0;
      if (!widget.showingHiddenApps &&
          widget.pinnedApps.isNotEmpty &&
          widget.searchController.text.isEmpty) {
        offset += 40.0 + (widget.pinnedApps.length * 60.0) + 20.0;
      }
      if (!widget.showingHiddenApps &&
          widget.folders.isNotEmpty &&
          widget.searchController.text.isEmpty) {
        offset += 40.0 + (widget.folders.length * 60.0) + 20.0;
      }
      for (final section in sections) {
        final sectionHeight = 60.0 + (section.apps.length * 60.0);
        if (_scrollController.offset >= offset &&
            _scrollController.offset < offset + sectionHeight) {
          if (_currentSection != section.letter) {
            setState(() {
              _currentSection = section.letter;
            });
            HapticFeedback.selectionClick();
          }
          break;
        }
        offset += sectionHeight;
      }
    }
  }

  List<AppInfo> get _filteredApps {
    List<AppInfo> apps;
    final allAppsInFolders =
        widget.folders.expand((folder) => folder.appPackageNames).toSet();
    final query = widget.searchController.text.toLowerCase();

    if (widget.isSelectingAppsToHide) {
      // When selecting apps to hide, show all apps except system apps
      apps = List<AppInfo>.from(widget.apps)
        ..sort(
            (a, b) => (a.name).toLowerCase().compareTo((b.name).toLowerCase()));
    } else {
      // Normal app list filtering
      apps = widget.showingHiddenApps
          ? widget.apps
              .where((app) => widget.hiddenApps.contains(app.packageName))
              .toList()
          : widget.apps
              .where((app) =>
                  !widget.hiddenApps.contains(app.packageName) &&
                  (query.isNotEmpty ||
                      !allAppsInFolders.contains(app.packageName)))
              .toList();
    }

    if (widget.sortType == AppListSortType.alphabeticalAsc) {
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (widget.sortType == AppListSortType.alphabeticalDesc) {
      apps.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    }

    if (query.isNotEmpty) {
      apps = apps
          .where((app) => (app.name.toLowerCase().contains(query)))
          .toList();
    }
    return apps;
  }

  Future<Uint8List?> _loadAppIcon(String packageName) async {
    if (_iconCache.containsKey(packageName)) {
      return _iconCache[packageName];
    }

    try {
      // First try to load from database cache
      final iconData = await AppDatabase.loadIconFromCache(packageName);
      if (iconData != null) {
        // Manage cache size
        if (_iconCache.length >= _maxCacheSize) {
          _iconCache.remove(_iconCache.keys.first);
        }
        _iconCache[packageName] = iconData;
        return iconData;
      }

      // Fallback to loading from app if not in cache
      final app =
          widget.apps.firstWhere((app) => app.packageName == packageName);
      if (app.icon != null) {
        // Manage cache size
        if (_iconCache.length >= _maxCacheSize) {
          _iconCache.remove(_iconCache.keys.first);
        }
        _iconCache[packageName] = app.icon!;
        return app.icon;
      }
    } catch (e) {
      debugPrint('Error loading icon: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sections = AppSectionManager.createSections(_filteredApps,
        sortType: widget.sortType);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final showFolders = !widget.showingHiddenApps &&
        widget.folders.isNotEmpty &&
        widget.searchController.text.isEmpty;
    final showPinned = !widget.showingHiddenApps &&
        widget.pinnedApps.isNotEmpty &&
        widget.searchController.text.isEmpty;

    final scrollbarTheme = Theme.of(context).copyWith(
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white.withAlpha(77)),
        radius: const Radius.circular(10.0),
        thickness: WidgetStateProperty.all(6.0),
        interactive: true,
      ),
    );

    if (widget.searchController.text.isNotEmpty) {
      return Theme(
        data: scrollbarTheme,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: _isScrolling,
          interactive: true,
          child: _buildAppSearchList(_filteredApps),
        ),
      );
    }

    return Theme(
      data: scrollbarTheme,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: _isScrolling,
        interactive: true,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            if (showPinned) ...[
              _buildSectionHeader('Pinned Apps', isDarkMode),
              _buildPinnedAppsList(),
              if (showFolders) const SliverToBoxAdapter(child: Divider()),
            ],
            if (showFolders) ...[
              _buildSectionHeader('Folders', isDarkMode),
              _buildFolderList(),
              const SliverToBoxAdapter(child: Divider()),
            ],
            ..._buildAppSections(sections, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDarkMode) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildFolderList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final folder = widget.folders[index];
          return ListTile(
            leading: const Icon(Icons.folder, color: Colors.amber, size: 40),
            title: Text(folder.name),
            onTap: () => _showFolderAppsDialog(folder),
            onLongPress: () => _showFolderOptionsDialog(folder),
          );
        },
        childCount: widget.folders.length,
      ),
    );
  }

  void _showFolderAppsDialog(Folder folder) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(folder.name),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: folder.apps.length,
                itemBuilder: (context, index) {
                  final app = folder.apps[index];
                  final isPinned = false;
                  final hasNotifications = widget.showNotificationBadges &&
                      widget.notificationCounts.containsKey(app.packageName) &&
                      widget.notificationCounts[app.packageName]! > 0;
                  return ListTile(
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        FutureBuilder<Uint8List?>(
                          future: _loadAppIcon(app.packageName),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Image.memory(snapshot.data!,
                                  width: 40, height: 40);
                            }
                            return const SizedBox(
                                width: 40, height: 40, child: Icon(Icons.apps));
                          },
                        ),
                        if (hasNotifications)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                              ),
                              child: Text(
                                widget.notificationCounts[app.packageName]
                                    .toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(app.name),
                    onTap: () {
                      widget.onAppLaunch(app.packageName);
                      InstalledApps.startApp(app.packageName);
                    },
                    onLongPress: () => widget.onAppLongPress(
                        context, app, isPinned, onAppRemoved: () {
                      setState(() {
                        folder.apps.remove(app);
                      });
                    }),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showFolderOptionsDialog(Folder folder) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Folder Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameFolderDialog(folder);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Folder'),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Folder'),
                      content: Text(
                          'Are you sure you want to delete the "${folder.name}" folder? The apps inside will be moved to the main app list.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete',
                                style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await AppDatabase.deleteFolder(folder.id);
                    Navigator.pop(context);
                    widget.onFoldersChanged();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameFolderDialog(Folder folder) {
    final controller = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Folder'),
          content: TextField(controller: controller),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  if (widget.folders.any((f) =>
                      f.id != folder.id &&
                      f.name.toLowerCase() == newName.toLowerCase())) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('A folder with this name already exists.')),
                    );
                    return;
                  }
                  folder.name = newName;
                  await AppDatabase.updateFolder(folder);
                  Navigator.pop(context);
                  widget.onFoldersChanged();
                }
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPinnedAppsList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildAppTile(widget.pinnedApps[index], true),
        childCount: widget.pinnedApps.length,
      ),
    );
  }

  List<Widget> _buildAppSections(List<AppSection> sections, bool isDarkMode) {
    return sections.expand((section) {
      return [
        if (sections.length > 1)
          _buildSectionHeader(section.letter, isDarkMode),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildAppTile(section.apps[index], false),
            childCount: section.apps.length,
          ),
        ),
      ];
    }).toList();
  }

  Widget _buildAppSearchList(List<AppInfo> apps) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: apps.length,
      itemBuilder: (context, index) => _buildAppTile(apps[index], false),
    );
  }

  Widget _buildAppTile(AppInfo application, bool isPinned) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hasNotifications = widget.showNotificationBadges &&
        widget.notificationCounts.containsKey(application.packageName) &&
        widget.notificationCounts[application.packageName]! > 0;
    final isSelectedToHide = widget.isSelectingAppsToHide &&
        widget.hiddenApps.contains(application.packageName);

    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          FutureBuilder<Uint8List?>(
            future: _loadAppIcon(application.packageName),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Image.memory(snapshot.data!, width: 40, height: 40);
              }
              return const SizedBox(
                  width: 40, height: 40, child: Icon(Icons.apps));
            },
          ),
          if (hasNotifications)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
                child: Text(
                  widget.notificationCounts[application.packageName].toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(application.name),
      trailing: isSelectedToHide
          ? Icon(Icons.check_box, color: Theme.of(context).colorScheme.primary)
          : isPinned
              ? Icon(Icons.push_pin,
                  color: isDarkMode ? Colors.white70 : Colors.black54)
              : null,
      onTap: () {
        widget.onAppLaunch(application.packageName);
        if (!widget.isSelectingAppsToHide) {
          InstalledApps.startApp(application.packageName);
        }
      },
      onLongPress: () => widget.onAppLongPress(context, application, isPinned),
    );
  }
}
