import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'dart:typed_data';
import '../app_sections.dart';
import '../sort_options.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'app_layout_manager.dart';
import '../database/app_database.dart';

class AppListView extends StatefulWidget {
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

  const AppListView({
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
  }) : super(key: key);

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
    
    if (_scrollController.hasClients && widget.sortType != AppListSortType.usage) {
      // Get all section headers from the screen
      final sections = AppSectionManager.createSections(_filteredApps, sortType: widget.sortType);
      if (sections.isEmpty) return;
      
      // Approximate check for which section is most visible
      final scrollPosition = _scrollController.position.pixels;
      final viewportHeight = _scrollController.position.viewportDimension;
      
      // Calculate the total content height and the approximate position of each section
      double sectionPosition = 0;
      double itemHeight = 60.0; // Approximate height of a list item
      double sectionHeaderHeight = 60.0; // Approximate height of a section header
      
      String? visibleSection;
      double pinnedSectionHeight = 0;
      
      // Account for pinned apps section if it exists
      if (!widget.showingHiddenApps && widget.pinnedApps.isNotEmpty && widget.searchController.text.isEmpty) {
        pinnedSectionHeight = 40.0 + (widget.pinnedApps.length * itemHeight) + 20.0; // Header + items + divider
        sectionPosition += pinnedSectionHeight;
      }
      
      // Find which section is most visible
      for (var i = 0; i < sections.length; i++) {
        final section = sections[i];
        final sectionStart = sectionPosition;
        final sectionHeight = sectionHeaderHeight + (section.apps.length * itemHeight);
        sectionPosition += sectionHeight;
        
        // Check if we're in this section's range
        if (scrollPosition >= sectionStart && scrollPosition < sectionPosition) {
          visibleSection = section.letter;
          break;
        }
      }
      
      // Trigger haptic feedback when section changes
      if (visibleSection != null && visibleSection != _currentSection) {
        HapticFeedback.selectionClick();
        _currentSection = visibleSection;
      }
    }
  }
  
  List<AppInfo> get _filteredApps {
    List<AppInfo> apps;
    
    if (widget.isSelectingAppsToHide) {
      // When selecting apps to hide, show all apps except system apps
      apps = List<AppInfo>.from(widget.apps)
        ..sort((a, b) => (a.name).toLowerCase().compareTo((b.name).toLowerCase()));
      
      // Apply search filter if query exists
      final query = widget.searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        apps = apps.where((app) => 
          (app.name.toLowerCase().contains(query))
        ).toList();
      }
      return apps;
    } else {
      // Normal app list filtering
      apps = widget.showingHiddenApps 
          ? widget.apps.where((app) => widget.hiddenApps.contains(app.packageName)).toList()
          : widget.apps.where((app) => !widget.hiddenApps.contains(app.packageName)).toList();
      
      final query = widget.searchController.text.toLowerCase();
      if (query.isEmpty) return apps;
      
      return apps.where((app) => 
        (app.name.toLowerCase().contains(query))
      ).toList();
    }
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
      final app = widget.apps.firstWhere((app) => app.packageName == packageName);
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
    // For selection mode or when showing hidden apps, we'll use a simple ListView
    if (widget.isSelectingAppsToHide) {
      return Theme(
        data: Theme.of(context).copyWith(
          scrollbarTheme: ScrollbarThemeData(
            thumbColor: MaterialStateProperty.all(Colors.white.withAlpha(77)),
            radius: const Radius.circular(10.0),
            thickness: MaterialStateProperty.all(6.0),
            interactive: true,
          ),
        ),
        child: Scrollbar(
          thumbVisibility: _isScrolling,
          interactive: true,
          controller: _scrollController,
          child: ScrollConfiguration(
            behavior: AppScrollBehavior().copyWith(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            ),
            child: ListView.builder(
              itemCount: _filteredApps.length,
              controller: _scrollController,
              itemBuilder: (context, index) {
                final app = _filteredApps[index];
                return _buildAppTile(app, false);
              },
            ),
          ),
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: MaterialStateProperty.all(Colors.white.withAlpha(77)),
          radius: const Radius.circular(10.0),
          thickness: MaterialStateProperty.all(6.0),
          interactive: true,
        ),
      ),
      child: Scrollbar(
        thumbVisibility: _isScrolling,
        interactive: true,
        controller: _scrollController,
        child: ScrollConfiguration(
          behavior: AppScrollBehavior().copyWith(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          ),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Pinned apps section
              if (!widget.showingHiddenApps && widget.pinnedApps.isNotEmpty && widget.searchController.text.isEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildPinnedAppsHeader(),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildAppTile(widget.pinnedApps[index], true),
                    ),
                    childCount: widget.pinnedApps.length,
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(color: Colors.white24),
                  ),
                ),
              ],
              
              // Regular apps with sections
              ...AppSectionManager.createSections(
                _filteredApps,
                sortType: widget.sortType
              ).expand((section) => [
                if (widget.sortType != AppListSortType.usage) 
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(section.letter),
                  ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildAppTile(section.apps[index], false),
                    ),
                    childCount: section.apps.length,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPinnedAppsHeader() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Pinned Apps',
              style: TextStyle(
                color: isDarkMode 
                    ? const Color.fromARGB(230, 255, 255, 255) // 0.9 opacity (230/255)
                    : const Color.fromARGB(204, 0, 0, 0), // 0.8 opacity (204/255)
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String letter) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDarkMode 
                  ? const Color.fromARGB(51, 103, 80, 164) // 0.2 opacity (51/255)
                  : const Color.fromARGB(26, 103, 80, 164), // 0.1 opacity (26/255)
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  color: isDarkMode ? const Color(0xFFD0BCFF) : const Color(0xFF6750A4),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: isDarkMode 
                  ? const Color.fromARGB(26, 255, 255, 255) // 0.1 opacity (26/255)
                  : const Color.fromARGB(13, 0, 0, 0), // 0.05 opacity (13/255)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppTile(AppInfo app, bool isPinned) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (widget.isSelectingAppsToHide) {
      final isHidden = widget.hiddenApps.contains(app.packageName);
      return ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: (isDarkMode ? Colors.white : Colors.black).withAlpha(26),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(26, 0, 0, 0), // 0.1 opacity (26/255)
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: app.icon != null
                ? Image.memory(app.icon!)
                : const Icon(Icons.android, color: Colors.white),
          ),
        ),
        title: Text(
          app.name,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          isHidden ? Icons.check_box : Icons.check_box_outline_blank,
          color: isHidden ? Colors.red : (isDarkMode ? Colors.white : Colors.black).withAlpha(128),
        ),
        onTap: () async {
          setState(() {
            if (!isHidden) {
              widget.hiddenApps.add(app.packageName);
            } else {
              widget.hiddenApps.remove(app.packageName);
            }
          });
        },
      );
    }

    return Stack(
      children: [
        ListTile(
          leading: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: (isDarkMode ? Colors.white : Colors.black).withAlpha(26),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(26, 0, 0, 0), // 0.1 opacity (26/255)
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: FutureBuilder<Uint8List?>(
                future: _loadAppIcon(app.packageName),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Image.memory(
                        snapshot.data!,
                        width: 46,
                        height: 46,
                        fit: BoxFit.contain,
                      ),
                    );
                  }
                  return const Icon(
                    Icons.android,
                    color: Colors.white,
                  );
                },
              ),
            ),
          ),
          title: Text(
            app.name,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: null,
          onTap: () async {
              HapticFeedback.selectionClick();
              await InstalledApps.startApp(app.packageName);
              widget.onAppLaunch(app.packageName);
            },
          onLongPress: () {
              widget.onAppLongPress(context, app, isPinned);
          },
          trailing: isPinned
              ? Icon(
                  Icons.push_pin,
                  color: isDarkMode ? Colors.grey : Colors.black,
                )
              : null,
        ),
        if (widget.showNotificationBadges && 
            widget.notificationCounts.containsKey(app.packageName) && 
            widget.notificationCounts[app.packageName]! > 0)
          Positioned(
            top: 0,
            left: 52,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: Text(
                widget.notificationCounts[app.packageName].toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
} 