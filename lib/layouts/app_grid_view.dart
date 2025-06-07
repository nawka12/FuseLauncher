import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import '../app_sections.dart';
import '../database/app_database.dart';
import '../models/folder.dart';
import '../sort_options.dart';
import '../widgets/folder_widget.dart';
import 'app_layout_manager.dart';

class AppGridView extends StatefulWidget {
  final List<AppInfo> apps;
  final List<Folder> folders;
  final List<AppInfo> pinnedApps;
  final bool showingHiddenApps;
  final Function(BuildContext, AppInfo, bool, {VoidCallback? onAppRemoved})
      onAppLongPress;
  final VoidCallback onFoldersChanged;
  final bool isSelectingAppsToHide;
  final List<String> hiddenApps;
  final void Function(String) onAppLaunch;
  final Map<String, int> notificationCounts;
  final bool showNotificationBadges;
  final TextEditingController searchController;
  final AppListSortType sortType;

  const AppGridView({
    super.key,
    required this.apps,
    required this.folders,
    required this.pinnedApps,
    required this.showingHiddenApps,
    required this.onAppLongPress,
    required this.onFoldersChanged,
    required this.isSelectingAppsToHide,
    required this.hiddenApps,
    required this.onAppLaunch,
    required this.notificationCounts,
    required this.showNotificationBadges,
    required this.searchController,
    required this.sortType,
  });

  @override
  State<AppGridView> createState() => _AppGridViewState();
}

class _AppGridViewState extends State<AppGridView> {
  int _columnCount = 4;
  final Map<String, Uint8List> _iconCache = {};
  final int _maxCacheSize = 50;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolling = false;
  Timer? _scrollEndTimer;
  String? _currentSection;

  @override
  void initState() {
    super.initState();
    _loadColumnCount();
    _scrollController.addListener(_scrollListener);
    widget.searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(AppGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadColumnCount();
    if (widget.searchController != oldWidget.searchController) {
      oldWidget.searchController.removeListener(_onSearchChanged);
      widget.searchController.addListener(_onSearchChanged);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _scrollListener() {
    if (!_isScrolling) {
      setState(() {
        _isScrolling = true;
      });
    }
    _scrollEndTimer?.cancel();
    _scrollEndTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isScrolling = false;
        });
      }
    });

    final sections = AppSectionManager.createSections(_filteredApps);
    if (sections.isEmpty) return;

    double offset = 0;
    if (!widget.showingHiddenApps &&
        widget.pinnedApps.isNotEmpty &&
        widget.searchController.text.isEmpty) {
      final pinnedRowCount = (widget.pinnedApps.length / _columnCount).ceil();
      offset += 40.0 + (pinnedRowCount * 120.0) + 20.0;
    }

    if (!widget.showingHiddenApps &&
        widget.folders.isNotEmpty &&
        widget.searchController.text.isEmpty) {
      final folderRowCount = (widget.folders.length / _columnCount).ceil();
      offset += 40.0 + (folderRowCount * 120.0) + 20.0;
    }

    for (final section in sections) {
      final sectionHeight =
          60.0 + ((section.apps.length / _columnCount).ceil() * 120.0);
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

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadColumnCount() async {
    final columns = await AppLayoutManager.getGridColumns();
    if (mounted) {
      setState(() {
        _columnCount = columns;
      });
    }
  }

  List<AppInfo> get _filteredApps {
    final allAppsInFolders =
        widget.folders.expand((folder) => folder.appPackageNames).toSet();
    final query = widget.searchController.text.toLowerCase();

    List<AppInfo> appsToShow;

    if (widget.isSelectingAppsToHide) {
      appsToShow = widget.apps;
    } else if (widget.showingHiddenApps) {
      appsToShow = widget.apps
          .where((app) => widget.hiddenApps.contains(app.packageName))
          .toList();
    } else {
      appsToShow = widget.apps
          .where((app) =>
              !widget.hiddenApps.contains(app.packageName) &&
              (query.isNotEmpty || !allAppsInFolders.contains(app.packageName)))
          .toList();
    }

    // Apply sort type, except usage which is pre-sorted
    if (widget.sortType == AppListSortType.alphabeticalAsc) {
      appsToShow
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (widget.sortType == AppListSortType.alphabeticalDesc) {
      appsToShow
          .sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    }

    if (query.isNotEmpty) {
      appsToShow = appsToShow
          .where((app) => app.name.toLowerCase().contains(query))
          .toList();
    }
    return appsToShow;
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
              _buildPinnedAppsGrid(),
              if (showFolders) const SliverToBoxAdapter(child: Divider()),
            ],
            if (showFolders) ...[
              _buildSectionHeader('Folders', isDarkMode),
              _buildFolderGrid(),
              const SliverToBoxAdapter(child: Divider()),
            ],
            if (widget.searchController.text.isNotEmpty)
              _buildAppSearchGrid(_filteredApps)
            else
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

  SliverPadding _buildFolderGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columnCount,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final folder = widget.folders[index];
            return FolderWidget(
              folder: folder,
              onTap: () => _showFolderAppsDialog(folder),
              onLongPress: () => _showFolderOptionsDialog(folder),
            );
          },
          childCount: widget.folders.length,
        ),
      ),
    );
  }

  SliverPadding _buildPinnedAppsGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columnCount,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildAppIcon(widget.pinnedApps[index]),
          childCount: widget.pinnedApps.length,
        ),
      ),
    );
  }

  List<Widget> _buildAppSections(List<AppSection> sections, bool isDarkMode) {
    return sections.expand((section) {
      return [
        _buildSectionHeader(section.letter, isDarkMode),
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columnCount,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildAppIcon(section.apps[index]),
              childCount: section.apps.length,
            ),
          ),
        ),
      ];
    }).toList();
  }

  SliverPadding _buildAppSearchGrid(List<AppInfo> apps) {
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columnCount,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildAppIcon(apps[index]),
          childCount: apps.length,
        ),
      ),
    );
  }

  Widget _buildAppIcon(AppInfo application) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isPinned = widget.pinnedApps
        .any((app) => app.packageName == application.packageName);
    final isSelectedToHide = widget.isSelectingAppsToHide &&
        widget.hiddenApps.contains(application.packageName);

    return InkWell(
      onTap: () {
        widget.onAppLaunch(application.packageName);
        if (!widget.isSelectingAppsToHide) {
          InstalledApps.startApp(application.packageName);
        }
      },
      onLongPress: () => widget.onAppLongPress(context, application, isPinned),
      borderRadius: BorderRadius.circular(16.0),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIconWithBadge(application, isDarkMode),
                const SizedBox(height: 8.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    application.name,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (isSelectedToHide)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: const Center(
                child: Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIconWithBadge(AppInfo application, bool isDarkMode) {
    final hasNotifications = widget.showNotificationBadges &&
        widget.notificationCounts.containsKey(application.packageName) &&
        widget.notificationCounts[application.packageName]! > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        FutureBuilder<Uint8List?>(
          future: _loadAppIcon(application.packageName),
          builder: (context, snapshot) {
            return Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                image: (snapshot.data != null)
                    ? DecorationImage(
                        image: MemoryImage(snapshot.data!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (snapshot.data == null)
                  ? const Icon(Icons.apps, size: 30)
                  : null,
            );
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
    );
  }

  Future<Uint8List?> _loadAppIcon(String packageName) async {
    if (_iconCache.containsKey(packageName)) {
      return _iconCache[packageName];
    }
    final iconData = await AppDatabase.loadIconFromCache(packageName);
    if (iconData != null) {
      if (_iconCache.length > _maxCacheSize) {
        _iconCache.remove(_iconCache.keys.first);
      }
      _iconCache[packageName] = iconData;
    }
    return iconData;
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
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columnCount,
                  crossAxisSpacing: 16.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: 0.8,
                ),
                itemCount: folder.apps.length,
                itemBuilder: (context, index) {
                  final app = folder.apps[index];
                  return InkWell(
                    onTap: () {
                      widget.onAppLaunch(app.packageName);
                      InstalledApps.startApp(app.packageName);
                    },
                    onLongPress: () => widget
                        .onAppLongPress(context, app, false, onAppRemoved: () {
                      setState(() {
                        folder.apps.remove(app);
                      });
                    }),
                    borderRadius: BorderRadius.circular(16.0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildIconWithBadge(app,
                              Theme.of(context).brightness == Brightness.dark),
                          const SizedBox(height: 8.0),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Text(
                              app.name,
                              style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
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
}
