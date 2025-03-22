import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'app_layout_manager.dart';
import 'app_list_view.dart';
import 'app_grid_view.dart';
import '../app_usage_tracker.dart';
import '../sort_options.dart';

class AppLayoutSwitcher extends StatefulWidget {
  final List<AppInfo> apps;
  final List<AppInfo> pinnedApps;
  final bool showingHiddenApps;
  final Function(BuildContext, AppInfo, bool) onAppLongPress;
  final bool isSelectingAppsToHide;
  final List<String> hiddenApps;
  final void Function(String) onAppLaunch;
  final AppListSortType sortType;
  final Map<String, int> notificationCounts;
  final bool showNotificationBadges;
  final TextEditingController searchController;
  final ScrollController? scrollController;
  final bool isBackgroundLoading;

  const AppLayoutSwitcher({
    Key? key,
    required this.apps,
    required this.pinnedApps,
    required this.showingHiddenApps,
    required this.onAppLongPress,
    required this.isSelectingAppsToHide,
    required this.hiddenApps,
    required this.onAppLaunch,
    required this.sortType,
    required this.notificationCounts,
    required this.showNotificationBadges,
    required this.searchController,
    this.scrollController,
    this.isBackgroundLoading = false,
  }) : super(key: key);

  @override
  State<AppLayoutSwitcher> createState() => _AppLayoutSwitcherState();
}

class _AppLayoutSwitcherState extends State<AppLayoutSwitcher> {
  AppLayoutType _currentLayout = AppLayoutType.list;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadLayoutPreference();
    
    // Add listener to search controller to force rebuild when text changes
    widget.searchController.addListener(_forceRebuild);
  }
  
  @override
  void dispose() {
    // Remove the listener when disposing
    widget.searchController.removeListener(_forceRebuild);
    super.dispose();
  }
  
  @override
  void didUpdateWidget(AppLayoutSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle search controller changes
    if (widget.searchController != oldWidget.searchController) {
      oldWidget.searchController.removeListener(_forceRebuild);
      widget.searchController.addListener(_forceRebuild);
    }
  }
  
  void _forceRebuild() {
    if (mounted) {
      setState(() {
        // Just calling setState is enough to force a rebuild
      });
    }
  }

  Future<void> _loadLayoutPreference() async {
    final layout = await AppLayoutManager.getCurrentLayout();
    if (mounted) {
      setState(() {
        _currentLayout = layout;
        _isInitialized = true;
      });
    }
  }

  Future<void> _toggleLayout() async {
    final newLayout = _currentLayout == AppLayoutType.list
        ? AppLayoutType.grid
        : AppLayoutType.list;
    
    await AppLayoutManager.saveLayoutPreference(newLayout);
    
    if (mounted) {
      setState(() {
        _currentLayout = newLayout;
      });
    }
  }

  Future<void> _showLayoutSettingsDialog() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF212121) : const Color(0xFFF5F5F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.view_list),
                    title: const Text('List View'),
                    trailing: Radio<AppLayoutType>(
                      value: AppLayoutType.list,
                      groupValue: _currentLayout,
                      onChanged: (value) async {
                        await AppLayoutManager.saveLayoutPreference(AppLayoutType.list);
                        setModalState(() {
                          _currentLayout = AppLayoutType.list;
                        });
                        setState(() {
                          _currentLayout = AppLayoutType.list;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.grid_view),
                    title: const Text('Grid View'),
                    trailing: Radio<AppLayoutType>(
                      value: AppLayoutType.grid,
                      groupValue: _currentLayout,
                      onChanged: (value) async {
                        await AppLayoutManager.saveLayoutPreference(AppLayoutType.grid);
                        setModalState(() {
                          _currentLayout = AppLayoutType.grid;
                        });
                        setState(() {
                          _currentLayout = AppLayoutType.grid;
                        });
                      },
                    ),
                  ),
                  if (_currentLayout == AppLayoutType.grid) ...[
                    const Divider(),
                    StatefulBuilder(
                      builder: (context, setColumnState) {
                        return FutureBuilder<int>(
                          future: AppLayoutManager.getGridColumns(),
                          builder: (context, snapshot) {
                            final columns = snapshot.data ?? 4;
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Row(
                                    children: [
                                      const Text('Grid Columns: '),
                                      Text(
                                        columns.toString(),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                Slider(
                                  value: columns.toDouble(),
                                  min: 2,
                                  max: 6,
                                  divisions: 4,
                                  label: columns.toString(),
                                  onChanged: (value) async {
                                    final newColumns = value.round();
                                    await AppLayoutManager.saveGridColumns(newColumns);
                                    setColumnState(() {});
                                    setState(() {});
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // Show loading while we determine the layout
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        _currentLayout == AppLayoutType.list
            ? AppListView(
                apps: widget.apps,
                pinnedApps: widget.pinnedApps,
                showingHiddenApps: widget.showingHiddenApps,
                onAppLongPress: widget.onAppLongPress,
                isSelectingAppsToHide: widget.isSelectingAppsToHide,
                hiddenApps: widget.hiddenApps,
                onAppLaunch: widget.onAppLaunch,
                sortType: widget.sortType,
                notificationCounts: widget.notificationCounts,
                showNotificationBadges: widget.showNotificationBadges,
                searchController: widget.searchController,
              )
            : AppGridView(
                apps: widget.apps,
                pinnedApps: widget.pinnedApps,
                showingHiddenApps: widget.showingHiddenApps,
                onAppLongPress: widget.onAppLongPress,
                isSelectingAppsToHide: widget.isSelectingAppsToHide,
                hiddenApps: widget.hiddenApps,
                onAppLaunch: widget.onAppLaunch,
                notificationCounts: widget.notificationCounts,
                showNotificationBadges: widget.showNotificationBadges,
                searchController: widget.searchController,
                sortType: widget.sortType,
              ),
        if (widget.isBackgroundLoading)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.black.withOpacity(0.7) 
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Updating...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
} 