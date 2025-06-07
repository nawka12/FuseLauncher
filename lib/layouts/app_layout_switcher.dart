import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'app_layout_manager.dart';
import 'app_list_view.dart';
import 'app_grid_view.dart';
import '../sort_options.dart';
import '../models/folder.dart';

class AppLayoutSwitcher extends StatefulWidget {
  final List<AppInfo> apps;
  final List<Folder> folders;
  final List<AppInfo> pinnedApps;
  final VoidCallback onFoldersChanged;
  final bool showingHiddenApps;
  final Function(BuildContext, AppInfo, bool, {VoidCallback? onAppRemoved})
      onAppLongPress;
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
    super.key,
    required this.apps,
    required this.folders,
    required this.onFoldersChanged,
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
  });

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
                folders: widget.folders,
                onFoldersChanged: widget.onFoldersChanged,
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
                folders: widget.folders,
                onFoldersChanged: widget.onFoldersChanged,
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
                    ? Colors.black.withAlpha(179)
                    : Colors.white.withAlpha(230),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(51),
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
