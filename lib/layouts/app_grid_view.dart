import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'dart:typed_data';
import '../app_sections.dart';
import 'app_layout_manager.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import '../sort_options.dart';

class AppGridView extends StatefulWidget {
  final List<AppInfo> apps;
  final List<AppInfo> pinnedApps;
  final bool showingHiddenApps;
  final Function(BuildContext, AppInfo, bool) onAppLongPress;
  final bool isSelectingAppsToHide;
  final List<String> hiddenApps;
  final void Function(String) onAppLaunch;
  final Map<String, int> notificationCounts;
  final bool showNotificationBadges;
  final TextEditingController searchController;
  final AppListSortType sortType;

  const AppGridView({
    Key? key,
    required this.apps,
    required this.pinnedApps,
    required this.showingHiddenApps,
    required this.onAppLongPress,
    required this.isSelectingAppsToHide,
    required this.hiddenApps,
    required this.onAppLaunch,
    required this.notificationCounts,
    required this.showNotificationBadges,
    required this.searchController,
    required this.sortType,
  }) : super(key: key);

  @override
  State<AppGridView> createState() => _AppGridViewState();
}

class _AppGridViewState extends State<AppGridView> {
  int _columnCount = 4;
  final Map<String, Uint8List> _iconCache = {};
  final ScrollController _scrollController = ScrollController();
  String? _currentSection;
  bool _isScrolling = false;
  Timer? _scrollEndTimer;

  @override
  void initState() {
    super.initState();
    _loadColumnCount();
    _scrollController.addListener(_scrollListener);
    
    // Add listener to search controller to force rebuild when text changes
    widget.searchController.addListener(_onSearchChanged);
  }
  
  @override
  void didUpdateWidget(AppGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload column count when widget updates
    _loadColumnCount();
    
    // Update search controller listener if the controller has changed
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
    if (_scrollController.hasClients) {
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
      
      // Get all section headers from the screen
      final sections = AppSectionManager.createSections(_filteredApps);
      if (sections.isEmpty) return;
      
      // Approximate check for which section is most visible
      final scrollPosition = _scrollController.position.pixels;
      
      // Calculate the approximate position of each section
      double sectionPosition = 0;
      double itemHeight = 120.0; // Approximate height of a grid item
      double sectionHeaderHeight = 60.0; // Approximate height of a section header
      
      String? visibleSection;
      double pinnedSectionHeight = 0;
      
      // Account for pinned apps section if it exists
      if (!widget.showingHiddenApps && widget.pinnedApps.isNotEmpty && widget.searchController.text.isEmpty) {
        int pinnedRowCount = (widget.pinnedApps.length / _columnCount).ceil();
        pinnedSectionHeight = 40.0 + (pinnedRowCount * itemHeight) + 20.0; // Header + items + divider
        sectionPosition += pinnedSectionHeight;
      }
      
      // Find which section is most visible
      for (var i = 0; i < sections.length; i++) {
        final section = sections[i];
        final sectionStart = sectionPosition;
        int rowCount = (section.apps.length / _columnCount).ceil();
        final sectionHeight = sectionHeaderHeight + (rowCount * itemHeight);
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

  void _onSearchChanged() {
    if (mounted) {
      setState(() {
        // Just force a rebuild when search text changes
      });
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
      
      // Apply sort type
      switch (widget.sortType) {
        case AppListSortType.alphabeticalAsc:
          apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          break;
        case AppListSortType.alphabeticalDesc:
          apps.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
          break;
        case AppListSortType.usage:
          // Leave as is, will be sorted by usage later
          break;
      }
      
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
      final app = widget.apps.firstWhere((app) => app.packageName == packageName);
      if (app.icon != null) {
        // Manage cache size
        if (_iconCache.length >= 50) { // Max cache size
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // For selection mode, we'll use a simple grid
    if (widget.isSelectingAppsToHide) {
      return Scrollbar(
        thumbVisibility: _isScrolling,
        interactive: true,
        thickness: 6.0,
        radius: const Radius.circular(10.0),
        child: ScrollConfiguration(
          behavior: AppScrollBehavior().copyWith(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          ),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            controller: _scrollController,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columnCount,
              childAspectRatio: 1.0,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _filteredApps.length,
            itemBuilder: (context, index) {
              final app = _filteredApps[index];
              final isHidden = widget.hiddenApps.contains(app.packageName);
              
              return InkWell(
                onTap: () {
                  // Toggle hidden status
                  if (isHidden) {
                    if (widget.hiddenApps.contains(app.packageName)) {
                      widget.hiddenApps.remove(app.packageName);
                    }
                  } else {
                    if (!widget.hiddenApps.contains(app.packageName)) {
                      widget.hiddenApps.add(app.packageName);
                    }
                  }
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: double.infinity,
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    child: Stack(
                      children: [
                        SizedBox(
                          height: 88, // Reduced from 90
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: _getIconSize(),
                                height: _getIconSize(),
                                decoration: BoxDecoration(
                                  color: (isDarkMode ? Colors.white : Colors.black).withAlpha(26),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color.fromARGB(26, 0, 0, 0),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: app.icon != null
                                      ? Image.memory(app.icon!)
                                      : Icon(
                                          Icons.android,
                                          color: isDarkMode ? Colors.white : Colors.black54,
                                          size: 20,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 1), // Reduced from 2
                              SizedBox(
                                height: 28, // Reduced from 30
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2), // Reduced from 3
                                  child: Text(
                                    _formatAppName(app.name),
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.white : Colors.black,
                                      fontSize: 10.5, // Reduced from 11
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 2,
                          child: Icon(
                            isHidden ? Icons.check_circle : Icons.check_circle_outline,
                            color: isHidden ? Colors.red : Colors.grey.withAlpha(150),
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    
    // Regular grid view with sections
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
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _columnCount,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final app = widget.pinnedApps[index];
                        return _buildAppGridItem(app, true);
                      },
                      childCount: widget.pinnedApps.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: Colors.white24),
                  ),
                ),
              ],
              
              // Regular apps
              ...AppSectionManager.createSections(
                _filteredApps,
                sortType: widget.sortType,
              ).expand((section) => [
                SliverToBoxAdapter(
                  child: _buildSectionHeader(section.letter),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _columnCount,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final app = section.apps[index];
                        return _buildAppGridItem(app, false);
                      },
                      childCount: section.apps.length,
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppGridItem(AppInfo app, bool isPinned) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hasNotifications = widget.showNotificationBadges && 
                            widget.notificationCounts.containsKey(app.packageName) && 
                            widget.notificationCounts[app.packageName]! > 0;
                            
    return InkWell(
      onTap: () async {
        HapticFeedback.selectionClick();
        await InstalledApps.startApp(app.packageName);
        widget.onAppLaunch(app.packageName);
      },
      onLongPress: () {
        widget.onAppLongPress(context, app, isPinned);
      },
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Container(
          margin: const EdgeInsets.all(1),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 88, // Reduced from 90
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: _getIconSize(),
                      height: _getIconSize(),
                      decoration: BoxDecoration(
                        color: (isDarkMode ? Colors.white : Colors.black).withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(26, 0, 0, 0),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FutureBuilder<Uint8List?>(
                          future: _loadAppIcon(app.packageName),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Padding(
                                padding: EdgeInsets.all(_getIconPadding()),
                                child: Image.memory(
                                  snapshot.data!,
                                  width: _getIconSize() - (_getIconPadding() * 2),
                                  height: _getIconSize() - (_getIconPadding() * 2),
                                  fit: BoxFit.contain,
                                ),
                              );
                            }
                            return Icon(
                              Icons.android,
                              color: isDarkMode ? Colors.white70 : Colors.black54,
                              size: 24,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 1), // Reduced from 2
                    SizedBox(
                      height: 28, // Reduced from 30
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2), // Reduced from 3
                        child: Text(
                          _formatAppName(app.name),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontSize: 10.5, // Reduced from 11
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasNotifications)
                Positioned(
                  top: _getNotificationBadgeHeight(),
                  right: _getNotificationBadgePosition(),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(_getNotificationBadgePadding()),
                    child: Text(
                      widget.notificationCounts[app.packageName].toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _getNotificationBadgeFontSize(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAppName(String name) {
    // If name is already short enough, return it as is
    if (name.length <= 12) {
      return name;
    }
    
    // Check if the name contains spaces to determine where to split
    final words = name.split(' ');
    
    // If it's a single long word or very few words, simply truncate
    if (words.length <= 1 || words.where((w) => w.length > 7).isNotEmpty) {
      return '${name.substring(0, 10)}..';
    }
    
    // For multiple words, try to keep complete words
    String result = '';
    for (var word in words) {
      if ((result + word).length <= 10) {
        result += result.isEmpty ? word : ' $word';
      } else {
        break;
      }
    }
    
    return '$result..';
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

  double _getNotificationBadgePosition() {
    // Adjust badge position based on column count
    switch (_columnCount) {
      case 2:
        return 58.0; // Wider items, badge further right
      case 3:
        return 25.0; // Medium items
      case 5:
        return 14.0; // Narrower items
      case 6:
        return 12.0; // Very narrow items
      case 4:
      default:
        return 18.0; // Default for 4 columns
    }
  }

  double _getNotificationBadgeHeight() {    
    // Adjust badge position based on column count
    switch (_columnCount) {
      case 2:
        return 38.0; // Wider items, badge further right
      case 3:
        return 8.0; // Medium items
      case 5:
        return -1.0; // Narrower items
      case 6:
        return 0.0; // Very narrow items
      case 4:
      default:
        return 0.0; // Default for 4 columns
    }
  }

  double _getNotificationBadgePadding() {
    // Adjust padding based on column count
    switch (_columnCount) {
      case 2:
        return 4.0; // Wider items, more padding
      case 3:
        return 3.5; // Medium items
      case 5:
        return 2.5; // Narrower items
      case 6:
        return 2.0; // Very narrow items
      case 4:
      default:
        return 3.0; // Default for 4 columns
    }
  }

  double _getNotificationBadgeFontSize() {
    // Adjust font size based on column count
    switch (_columnCount) {
      case 2:
        return 12.0; // Wider items, larger font
      case 3:
        return 11.0; // Medium items
      case 5:
        return 9.5; // Narrower items
      case 6:
        return 8.0; // Very narrow items
      case 4:
      default:
        return 10.0; // Default for 4 columns
    }
  }

  double _getIconSize() {
    // Adjust icon size based on column count
    switch (_columnCount) {
      case 2:
        return 59.0; // Wider items, larger icon
      case 3:
        return 59.0; // Medium items
      case 5:
        return 31.0; // Narrower items
      case 6:
        return 18.0; // Very narrow items
      case 4:
      default:
        return 50.0; // Default for 4 columns
    }
  }

  double _getIconPadding() {
    // Adjust icon padding based on column count
    switch (_columnCount) {
      case 2:
        return 2.0; // Wider items, more padding
      case 3:
        return 1.5; // Medium items
      case 5:
        return 1.0; // Narrower items
      case 6:
        return 0.5; // Very narrow items
      case 4:
      default:
        return 2.0; // Default for 4 columns
    }
  }
} 