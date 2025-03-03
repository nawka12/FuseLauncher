import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'widget_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_usage_tracker.dart';
import 'sort_options.dart';
import 'app_sections.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Platform;
import 'notification_service.dart';
import 'settings_page.dart';
import 'auth_service.dart';
import 'navigation_state.dart';
import 'hidden_apps_manager.dart';
import 'dart:convert' show base64Decode;
import 'live_widget_preview.dart';
import 'database/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Print out all BuiltWith enum values to debug
  print('BuiltWith enum values:');
  for (var value in BuiltWith.values) {
    print(' - $value');
  }
  
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) async {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      return;
    });
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FLauncher',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late final ScrollController _scrollController = ScrollController()
    ..addListener(_smoothScrollListener);
  final ScrollController _widgetsScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _hiddenAppsSearchController = TextEditingController();
  final List<String> _tabs = ['Apps', 'Widgets'];
  int _selectedIndex = 0;
  List<AppInfo> _apps = [];
  List<WidgetInfo> _addedWidgets = [];
  bool _isLoading = true;
  DateTime? _lastRefresh;
  bool _isBackgroundLoading = false;
  List<AppInfo> _pinnedApps = [];
  bool _isReorderingWidgets = false;
  AppListSortType _appListSortType = AppListSortType.alphabeticalAsc;
  List<AppSection> _appSections = [];
  String _currentSection = '';
  final Map<String, Uint8List> _iconCache = {};
  final int _maxCacheSize = 50; // Adjust based on your needs
  final FocusNode _searchFocusNode = FocusNode();
  final Map<String, int> _notificationCounts = {};
  bool _isSearchBarAtTop = true;
  bool _showNotificationBadges = true;
  final List<String> _hiddenApps = [];
  bool _showingHiddenApps = false;
  double _horizontalDragStart = 0;
  bool _isSwipeInProgress = false;
  bool _hasCompletedFirstSwipe = false;
  DateTime? _lastSwipeTime;
  final Set<String> _pinnedAppsBackup = {};
  bool _isSelectingAppsToHide = false;
  final Map<int, Uint8List> _widgetPreviewCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedIndex = _tabController.index;
        _unfocusSearch();
      });
    });
    
    _isLoading = false;
    if (_apps.isEmpty) {
      _loadApps();
    }
    _loadAddedWidgets();
    _loadSortTypes();
    NotificationService.initialize();
    NotificationService.notificationStream.listen((counts) {
      setState(() {
        _notificationCounts.clear();
        _notificationCounts.addAll(counts);
      });
    });
    _loadSearchBarPosition();
    _loadSettings();
    _loadHiddenApps();
    _loadPinnedAppsBackup();
    
    const systemChannel = MethodChannel('com.kayfahaarukku.flauncher/system');
    systemChannel.setMethodCallHandler((call) async {
      if (call.method == 'getNavigationState') {
        return NavigationState.currentScreen;
      }
      if (call.method == 'onBackPressed') {
        if (_searchController.text.isNotEmpty) {
          setState(() {
            _searchController.clear();
          });
          return true;
        }
        if (_showingHiddenApps) {
          setState(() {
            _showingHiddenApps = false;
            _isSelectingAppsToHide = false;
            _searchController.clear();
            _hiddenAppsSearchController.clear();
          });
          return true;
        }
        if (_selectedIndex == 1) {
          _tabController.animateTo(0);
          setState(() {
            _selectedIndex = 0;
          });
          return true;
        }
        return false;
      }
      return null;
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showNotificationBadges = prefs.getBool('show_notification_badges') ?? true;
    });
  }

  Future<void> _loadSearchBarPosition() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSearchBarAtTop = prefs.getBool('isSearchBarAtTop') ?? true;
    });
  }

  Future<void> _updateSearchBarPosition(bool isTop) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSearchBarAtTop', isTop);
    setState(() {
      _isSearchBarAtTop = isTop;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _scrollController.removeListener(_smoothScrollListener);
    _scrollController.dispose();
    _widgetsScrollController.dispose();
    _searchController.dispose();
    _hiddenAppsSearchController.dispose();
    _iconCache.clear();
    _searchFocusNode.dispose();
    NotificationService.dispose();
    super.dispose();
  }

  Future<void> _loadApps({bool background = false}) async {
    if ((_isLoading && !background) || (_isBackgroundLoading && background)) return;
    
    if (background) {
      _isBackgroundLoading = true;
    } else {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      // First try to load from cache
      if (!background) {
        final cachedApps = await AppDatabase.getCachedApps();
        if (cachedApps.isNotEmpty) {
          if (mounted) {
            setState(() {
              _apps = cachedApps;
              _isLoading = false;
            });
            await AppUsageTracker.sortAppList(_apps, _appListSortType);
            await _loadPinnedApps();
            if (mounted) {
              setState(() {
                _appSections = AppSectionManager.createSections(_apps, sortType: _appListSortType);
              });
            }
          }
        }
      }
      
      // Then load fresh data in the background
      final lastUpdate = await AppDatabase.getLastUpdateTime();
      final shouldRefresh = lastUpdate == null || 
          DateTime.now().difference(lastUpdate) > const Duration(hours: 1);
      
      if (shouldRefresh) {
        final freshApps = await InstalledApps.getInstalledApps(false, true, true);
        
        // Cache the fresh data
        await AppDatabase.cacheApps(freshApps);
        
        if (mounted) {
          setState(() {
            _apps = freshApps;
          });
          await AppUsageTracker.sortAppList(_apps, _appListSortType);
          await _loadPinnedApps();
          
          if (mounted) {
            setState(() {
              _appSections = AppSectionManager.createSections(_apps, sortType: _appListSortType);
              if (!background) {
                _isLoading = false;
              }
              _isBackgroundLoading = false;
            });
          }
        }
        
        // Clear old cache entries
        await AppDatabase.clearOldCache(const Duration(days: 7));
      } else {
        _isBackgroundLoading = false;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!background) {
            _isLoading = false;
          }
          _isBackgroundLoading = false;
        });
      }
      debugPrint('Error loading apps: $e');
    }
  }

  List<AppInfo> get _filteredApps {
    List<AppInfo> apps;
    
    if (_isSelectingAppsToHide) {
      // When selecting apps to hide, show all apps except system apps
      apps = List<AppInfo>.from(_apps)
        ..sort((a, b) => (a.name).toLowerCase().compareTo((b.name).toLowerCase()));
      
      // Apply search filter if query exists
      final query = _hiddenAppsSearchController.text.toLowerCase();
      if (query.isNotEmpty) {
        apps = apps.where((app) => 
          (app.name.toLowerCase().contains(query))
        ).toList();
      }
      return apps;
    } else {
      // Normal app list filtering
      apps = _showingHiddenApps 
          ? _apps.where((app) => _hiddenApps.contains(app.packageName)).toList()
          : _apps.where((app) => !_hiddenApps.contains(app.packageName)).toList();
      
      final query = _searchController.text.toLowerCase();
      if (query.isEmpty) return apps;
      
      return apps.where((app) => 
        (app.name.toLowerCase().contains(query))
      ).toList();
    }
  }

  Future<bool> _onWillPop() async {
    if (_searchController.text.isNotEmpty || _hiddenAppsSearchController.text.isNotEmpty) {
      setState(() {
        _searchController.clear();
        _hiddenAppsSearchController.clear();
      });
      return false;
    }
    if (_showingHiddenApps) {
      setState(() {
        _showingHiddenApps = false;
        _isSelectingAppsToHide = false;
        _searchController.clear();
        _hiddenAppsSearchController.clear();
      });
      return false;
    }
    if (_selectedIndex == 1) {
      _tabController.animateTo(0);
      setState(() {
        _selectedIndex = 0;
      });
      return false;
    }
    return false; // Never allow exiting the app with back button
  }

  void _showAppOptions(BuildContext context, AppInfo application, bool isPinned) async {
    bool? isSystemAppResult = await InstalledApps.isSystemApp(application.packageName);
    bool isSystemApp = isSystemAppResult ?? true;
    bool isHidden = _hiddenApps.contains(application.packageName);

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.grey[900],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        isScrollControlled: true,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: _getBottomSheetPadding(context),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: application.icon != null
                                    ? Image.memory(
                                        application.icon!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(
                                            Icons.android,
                                            color: Colors.white,
                                          );
                                        },
                                      )
                                    : const Icon(
                                        Icons.android,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    application.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    application.packageName,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isHidden)
                        ListTile(
                          leading: const Icon(Icons.visibility, color: Colors.white),
                          title: const Text(
                            'Unhide App',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            setState(() {
                              _hiddenApps.remove(application.packageName);
                              _searchController.clear();
                              _hiddenAppsSearchController.clear();
                              // Restore pinned status if it was previously pinned
                              if (_pinnedAppsBackup.contains(application.packageName)) {
                                _pinnedApps.add(application);
                                _pinnedAppsBackup.remove(application.packageName);
                              }
                            });
                            await _saveHiddenApps();
                            await _savePinnedApps();
                            await _savePinnedAppsBackup();
                          },
                        ),
                      ListTile(
                        leading: Icon(
                          isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                          color: Colors.white,
                        ),
                        title: Text(
                          isPinned ? 'Unpin' : 'Pin to Top',
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          setState(() {
                            if (isPinned) {
                              _pinnedApps.removeWhere(
                                (pinnedApp) => pinnedApp.packageName == application.packageName
                              );
                            } else {
                              if (!_pinnedApps.any((app) => app.packageName == application.packageName)) {
                                if (_pinnedApps.length < 10) {
                                  _pinnedApps.add(application);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Maximum 10 apps can be pinned'),
                                    ),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${application.name} is already pinned'),
                                  ),
                                );
                              }
                            }
                          });
                          await _savePinnedApps();
                        },
                      ),
                      if (!isSystemApp)
                        ListTile(
                          leading: const Icon(Icons.delete, color: Colors.red),
                          title: const Text(
                            'Uninstall',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            await InstalledApps.uninstallApp(application.packageName);
                          },
                        ),
                      ListTile(
                        leading: const Icon(Icons.info_outline, color: Colors.white),
                        title: const Text(
                          'App Info',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          InstalledApps.openSettings(application.packageName);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }



  Future<void> _loadAddedWidgets() async {
    if (mounted) {
      setState(() {
        _addedWidgets = []; // Clear the list while loading
      });
    }
    
    final widgets = await WidgetManager.getAddedWidgets();
    final prefs = await SharedPreferences.getInstance();
    
    // Load saved widget order
    final savedOrder = prefs.getStringList('widget_order') ?? [];
    final orderedWidgets = <WidgetInfo>[];
    final unorderedWidgets = List<WidgetInfo>.from(widgets);
    
    // First add widgets in the saved order
    for (var widgetId in savedOrder) {
      final index = unorderedWidgets.indexWhere(
        (w) => w.widgetId?.toString() == widgetId
      );
      if (index != -1) {
        orderedWidgets.add(unorderedWidgets[index]);
        unorderedWidgets.removeAt(index);
      }
    }
    
    // Add any remaining widgets at the end
    orderedWidgets.addAll(unorderedWidgets);
    
    // Load saved sizes
    final savedSizesString = prefs.getString('widget_sizes');
    if (savedSizesString != null) {
      final savedSizes = jsonDecode(savedSizesString) as List;
      for (var widget in orderedWidgets) {
        final savedSize = savedSizes.firstWhere(
          (size) => size['widgetId'] == widget.widgetId,
          orElse: () => null,
        );
        if (savedSize != null) {
          widget.currentWidth = savedSize['width'];
          widget.currentHeight = savedSize['height'];
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _addedWidgets = orderedWidgets;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: GestureDetector(
        onTap: _unfocusSearch,
        child: Scaffold(
          backgroundColor: (isDarkMode ? Colors.black : Colors.white).withOpacity(0.5),
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                if (_isSelectingAppsToHide)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Select apps to hide',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final authenticated = await AuthService.authenticateUser();
                            if (authenticated) {
                              // Save all states first
                              await _saveHiddenApps();
                              await _savePinnedApps();
                              await _savePinnedAppsBackup();
                              
                              // Clear search bar and update UI state in a single setState
                              setState(() {
                                _searchController.clear();
                                _hiddenAppsSearchController.clear();
                                _isSelectingAppsToHide = false;
                                _showingHiddenApps = true;
                              });
                            }
                          },
                          child: Text(
                            'Done',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorColor: Colors.transparent,
                        dividerColor: Colors.transparent,
                        labelColor: isDarkMode ? Colors.white : Colors.black,
                        unselectedLabelColor: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.5),
                        indicator: BoxDecoration(
                          color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _isSelectingAppsToHide
                      ? _buildAppListContent()
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildAppsList(),
                            _buildWidgetsList(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildAppsList() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onHorizontalDragStart: (_selectedIndex == 0) ? (details) {
        _horizontalDragStart = details.localPosition.dx;
        _isSwipeInProgress = false;
      } : null,
      onHorizontalDragUpdate: (_selectedIndex == 0) ? (details) async {
        if (_isSwipeInProgress) return;

        final dragDistance = details.localPosition.dx - _horizontalDragStart;
        final screenWidth = MediaQuery.of(context).size.width;
        final now = DateTime.now();
        
        // Handle left-to-right swipe for hidden apps (when not already showing hidden apps)
        if (!_showingHiddenApps && dragDistance > screenWidth * 0.2) {
          _isSwipeInProgress = true;
          
          if (_lastSwipeTime != null && 
              now.difference(_lastSwipeTime!) < const Duration(milliseconds: 500)) {
            // Second swipe within 500ms
            if (_hasCompletedFirstSwipe) {
              final authenticated = await AuthService.authenticateUser();
              if (authenticated) {
                setState(() {
                  _showingHiddenApps = true;
                  _hasCompletedFirstSwipe = false;
                  _searchController.clear();
                  _hiddenAppsSearchController.clear();
                });
              }
            }
          } else {
            // First swipe or swipe after timeout
            _hasCompletedFirstSwipe = true;
          }
          _lastSwipeTime = now;
        }
        // Handle right-to-left swipe for tab switching (works on both normal and hidden app lists)
        else if (dragDistance < -screenWidth * 0.2) {
          _isSwipeInProgress = true;
          _tabController.animateTo(1); // Switch to Widgets tab
        }
      } : null,
      onHorizontalDragEnd: (_selectedIndex == 0) ? (details) {
        _isSwipeInProgress = false;
        // Reset first swipe if too much time has passed
        if (_lastSwipeTime != null && 
            DateTime.now().difference(_lastSwipeTime!) > const Duration(milliseconds: 500)) {
          _hasCompletedFirstSwipe = false;
        }
      } : null,
      child: Column(
        children: [
          if (_isSearchBarAtTop) _buildSearchBar(),
          if (_showingHiddenApps)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_off,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Hidden Apps',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.add,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    onPressed: () async {
                      final authenticated = await AuthService.authenticateUser();
                      if (authenticated) {
                        setState(() {
                          _isSelectingAppsToHide = true;
                          _showingHiddenApps = false;
                          _searchController.clear();
                          _hiddenAppsSearchController.clear();
                        });
                      }
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showingHiddenApps = false;
                        _isSelectingAppsToHide = false;
                        _searchController.clear();
                        _hiddenAppsSearchController.clear();
                      });
                    },
                    child: const Text('Exit'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _buildAppListContent(),
          ),
          if (!_isSearchBarAtTop) _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildWidgetsList() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Stack(
      children: [
        GestureDetector(
          onLongPress: _isReorderingWidgets ? null : () {
            if (_addedWidgets.isNotEmpty) {
              HapticFeedback.heavyImpact();
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.grey[900],
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.reorder, color: Colors.white),
                      title: const Text(
                        'Reorder Widgets',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _isReorderingWidgets = true;
                        });
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_sweep, color: Colors.red),
                      title: const Text(
                        'Remove All Widgets',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.grey[900],
                            title: const Text(
                              'Clear All Widgets',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              'Are you sure you want to remove all widgets?',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  for (var widget in _addedWidgets) {
                                    if (widget.widgetId != null) {
                                      await WidgetManager.removeWidget(widget.widgetId!);
                                    }
                                  }
                                  await _loadAddedWidgets();
                                  setState(() {});
                                },
                                child: const Text(
                                  'Remove All',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            }
          },
          child: Column(
            children: [
              if (_isReorderingWidgets)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Drag widgets to reorder them',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isReorderingWidgets = false;
                          });
                        },
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _addedWidgets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'No widgets added',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _showAddWidgetDialog,
                              child: const Text('Add Widget'),
                            ),
                          ],
                        ),
                      )
                    : Theme(
                        data: Theme.of(context).copyWith(
                          canvasColor: Colors.transparent,
                        ),
                        child: RawScrollbar(
                          controller: _widgetsScrollController,
                          thumbColor: Colors.white.withOpacity(0.3),
                          radius: const Radius.circular(20),
                          thickness: 6,
                          thumbVisibility: true,
                          trackVisibility: false,
                          child: ReorderableListView.builder(
                            scrollController: _widgetsScrollController,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (oldIndex < newIndex) {
                                  newIndex -= 1;
                                }
                                final item = _addedWidgets.removeAt(oldIndex);
                                _addedWidgets.insert(newIndex, item);
                              });
                              _saveWidgetOrder();
                            },
                            onReorderStart: (_) {
                              HapticFeedback.heavyImpact();
                            },
                            itemCount: _addedWidgets.length,
                            itemBuilder: (context, index) => Padding(
                              key: ValueKey(_addedWidgets[index].widgetId),
                              padding: const EdgeInsets.all(16),
                              child: ResizableWidget(
                                isReorderMode: _isReorderingWidgets,
                                onLongPress: () => _showWidgetOptions(
                                  context, 
                                  _addedWidgets[index]
                                ),
                                child: Container(
                                  width: double.infinity,
                                  height: _addedWidgets[index].minHeight.toDouble(),
                                  decoration: BoxDecoration(
                                    color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: LiveWidgetPreview(
                                    widgetId: _addedWidgets[index].widgetId!,
                                    minHeight: _addedWidgets[index].minHeight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _showAddWidgetDialog,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddWidgetDialog() async {
    final widgets = await WidgetManager.getAvailableWidgets();
    
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) {
        final searchController = TextEditingController();
        List<WidgetInfo> filteredWidgets = List.from(widgets);
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                'Add Widget',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search widgets...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          filteredWidgets = widgets.where((widget) => 
                            widget.appName.toLowerCase().contains(value.toLowerCase()) ||
                            widget.label.toLowerCase().contains(value.toLowerCase())
                          ).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _groupWidgetsByApp(filteredWidgets).length,
                        itemBuilder: (context, index) {
                          final entry = _groupWidgetsByApp(filteredWidgets).entries.elementAt(index);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ...entry.value.map((widget) => ListTile(
                                title: Text(
                                  widget.label,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  '${(widget.minWidth / MediaQuery.of(context).devicePixelRatio).round()}x'
                                  '${(widget.minHeight / MediaQuery.of(context).devicePixelRatio).round()} dp',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                ),
                                onTap: () async {
                                  Navigator.pop(context);
                                  final success = await WidgetManager.addWidget(widget);
                                  if (success && mounted) {
                                    await _loadAddedWidgets();
                                    setState(() {}); // Refresh the widget list
                                  }
                                },
                              )),
                              const Divider(color: Colors.white24),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    
    // Refresh widgets list after dialog is closed
    if (mounted) {
      await _loadAddedWidgets();
      setState(() {}); // Refresh the main widget list
    }
  }

  Map<String, List<WidgetInfo>> _groupWidgetsByApp(List<WidgetInfo> widgets) {
    final grouped = <String, List<WidgetInfo>>{};
    for (var widget in widgets) {
      // Skip widgets with invalid dimensions (0 in either width or height)
      if (widget.minWidth <= 0 || widget.minHeight <= 0) {
        continue;
      }
      
      if (!grouped.containsKey(widget.appName)) {
        grouped[widget.appName] = [];
      }
      grouped[widget.appName]!.add(widget);
    }
    // Remove empty app groups
    grouped.removeWhere((key, value) => value.isEmpty);
    
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
  }

  void _showWidgetOptions(BuildContext context, WidgetInfo widget) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      isScrollControlled: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: _getBottomSheetPadding(context),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Row(
                        children: [
                          FutureBuilder<Widget>(
                            future: _getAppIcon(widget.packageName),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: snapshot.data,
                                );
                              }
                              return const SizedBox(width: 40, height: 40);
                            },
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  widget.appName,
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.reorder, color: Colors.white),
                      title: const Text(
                        'Reorder Widgets',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _isReorderingWidgets = true;
                        });
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text(
                        'Remove Widget',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        if (widget.widgetId != null) {
                          await WidgetManager.removeWidget(widget.widgetId!);
                          await _loadAddedWidgets();
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Widget> _getAppIcon(String packageName) async {
    try {
      final app = _apps.firstWhere((app) => app.packageName == packageName);
      if (app.icon != null) {
        return Image.memory(app.icon!);
      }
      return const SizedBox();
    } catch (e) {
      return const SizedBox();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Prevent multiple rapid refreshes
      final now = DateTime.now();
      if (_lastRefresh != null && now.difference(_lastRefresh!) < const Duration(seconds: 2)) {
        return;
      }

      _lastRefresh = now;

      // Refresh both apps and pinned apps
      Future.delayed(const Duration(seconds: 1), () async {
        if (mounted) {
          await _loadApps(background: true);
          await _loadPinnedApps();
          setState(() {
          });
        }
      });
    }
  }

  Future<void> _savePinnedApps() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Keep only valid apps while preserving order
    final validPinnedApps = _pinnedApps.where((app) => 
      _apps.any((a) => a.packageName == app.packageName)
    ).toList();
    
    if (!listEquals(validPinnedApps, _pinnedApps)) {
      setState(() {
        _pinnedApps = validPinnedApps;
      });
    }
    
    // Save both package names and their order
    final pinnedAppData = validPinnedApps.asMap().map((index, app) => 
      MapEntry(app.packageName, index)
    );
    await prefs.setString('pinned_apps_data', jsonEncode(pinnedAppData));
  }

  Future<void> _loadPinnedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('pinned_apps_data');
    
    if (_apps.isEmpty || savedData == null) return;
    
    try {
      final Map<String, dynamic> pinnedData = jsonDecode(savedData);
      final orderedApps = <AppInfo>[];
      
      // Sort by saved index and create list
      final sortedEntries = pinnedData.entries.toList()
        ..sort((a, b) => (a.value as int).compareTo(b.value as int));
      
      for (var entry in sortedEntries) {
        try {
          final app = _apps.firstWhere(
            (app) => app.packageName == entry.key,
          );
          orderedApps.add(app);
        } catch (e) {
          // Skip if app not found
          continue;
        }
      }
      
      setState(() {
        _pinnedApps = orderedApps;
      });
    } catch (e) {
      debugPrint('Error loading pinned apps: $e');
    }
  }

  Future<void> _saveWidgetOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final widgetIds = _addedWidgets
        .where((w) => w.widgetId != null)
        .map((w) => w.widgetId.toString())
        .toList();
    await prefs.setStringList('widget_order', widgetIds);
  }


  void _showAppListSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: _getBottomSheetPadding(context),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.trending_up, color: Colors.white),
                title: const Text('Sort by Usage', style: TextStyle(color: Colors.white)),
                trailing: _appListSortType == AppListSortType.usage
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  await AppUsageTracker.sortAppList(_apps, AppListSortType.usage);
                  setState(() {
                    _appListSortType = AppListSortType.usage;
                    _appSections = AppSectionManager.createSections(_apps, sortType: _appListSortType);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha, color: Colors.white),
                title: const Text('Sort A to Z', style: TextStyle(color: Colors.white)),
                trailing: _appListSortType == AppListSortType.alphabeticalAsc
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  await AppUsageTracker.sortAppList(_apps, AppListSortType.alphabeticalAsc);
                  setState(() {
                    _appListSortType = AppListSortType.alphabeticalAsc;
                    _appSections = AppSectionManager.createSections(_apps, sortType: _appListSortType);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha_rounded, color: Colors.white),
                title: const Text('Sort Z to A', style: TextStyle(color: Colors.white)),
                trailing: _appListSortType == AppListSortType.alphabeticalDesc
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  await AppUsageTracker.sortAppList(_apps, AppListSortType.alphabeticalDesc);
                  setState(() {
                    _appListSortType = AppListSortType.alphabeticalDesc;
                    _appSections = AppSectionManager.createSections(_apps, sortType: _appListSortType);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadSortTypes() async {
    _appListSortType = await AppUsageTracker.getSavedAppListSortType();
    if (mounted) setState(() {});
  }

  void _smoothScrollListener() {
    if (!_scrollController.hasClients) return;
    
    final position = _scrollController.position.pixels;

    // Calculate current section
    double currentPos = 0;
    if (_pinnedApps.isNotEmpty && _searchController.text.isEmpty) {
      currentPos += 48.0 + (_pinnedApps.length * 72.0) + 16.0 + 48.0;
    }
    
    String newSection = '';
    for (var section in _appSections) {
      final sectionHeight = 40.0 + (section.apps.length * 72.0);
      if (position >= currentPos && position < (currentPos + sectionHeight)) {
        newSection = section.letter;
        break;
      }
      currentPos += sectionHeight;
    }
    
    if (newSection != _currentSection) {
      _currentSection = newSection;
      HapticFeedback.selectionClick();
    }
  }

  Widget _buildPinnedAppsHeader() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'Pinned Apps',
        style: TextStyle(
          color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.7),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAppTile(AppInfo app, bool isPinned) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_isSelectingAppsToHide) {
      final isHidden = _hiddenApps.contains(app.packageName);
      return ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: app.icon != null
                ? Image.memory(app.icon!)
                : const Icon(Icons.android, color: Colors.white),
          ),
        ),
        title: Text(
          app.name,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        trailing: Icon(
          isHidden ? Icons.check_box : Icons.check_box_outline_blank,
          color: isHidden ? Colors.red : (isDarkMode ? Colors.white : Colors.black).withOpacity(0.5),
        ),
        onTap: () async {
          setState(() {
            if (!isHidden) {
              _hiddenApps.add(app.packageName);
              // Remove from pinned apps immediately if present
              if (_pinnedApps.any((pinnedApp) => pinnedApp.packageName == app.packageName)) {
                _pinnedAppsBackup.add(app.packageName);
                _pinnedApps.removeWhere((pinnedApp) => pinnedApp.packageName == app.packageName);
                _savePinnedApps(); // Save pinned apps state immediately
              }
            } else {
              _hiddenApps.remove(app.packageName);
              if (_pinnedAppsBackup.contains(app.packageName)) {
                _pinnedApps.add(app);
                _pinnedAppsBackup.remove(app.packageName);
                _savePinnedApps(); // Save pinned apps state immediately
              }
            }
          });
        },
      );
    }

    return Stack(
      children: [
        ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FutureBuilder<Uint8List?>(
                future: _loadAppIcon(app.packageName),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Image.memory(
                      snapshot.data!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
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
              fontSize: 16,
            ),
          ),
          trailing: isPinned
              ? Icon(
                  Icons.push_pin,
                  color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.7),
                  size: 20,
                )
              : null,
          onTap: () async {
            await InstalledApps.startApp(app.packageName);
            await AppUsageTracker.recordAppLaunch(app.packageName);
          },
          onLongPress: () {
            HapticFeedback.heavyImpact();
            _showAppOptions(context, app, isPinned);
          },
        ),
        if (_showNotificationBadges && 
            _notificationCounts.containsKey(app.packageName) && 
            _notificationCounts[app.packageName]! > 0)
          Positioned(
            top: 5,
            left: 48,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Center(
                child: Text(
                  '${_notificationCounts[app.packageName]}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
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
    
    try {
      final app = _apps.firstWhere((app) => app.packageName == packageName);
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



  double _getBottomSheetPadding(BuildContext context) {
    // Get the bottom padding (includes navigation bar height)
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    // Add additional padding for visual spacing
    return bottomPadding + 16.0;
  }

  void _unfocusSearch() {
    _searchFocusNode.unfocus();
    setState(() {
    });
  }


  Widget _buildSearchBar() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final controller = _isSelectingAppsToHide ? _hiddenAppsSearchController : _searchController;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        focusNode: _searchFocusNode,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        decoration: InputDecoration(
          hintText: _isSelectingAppsToHide 
              ? 'Search apps to hide...' 
              : _showingHiddenApps 
                  ? 'Search hidden apps...'
                  : 'Search apps...',
          hintStyle: TextStyle(
            color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.5),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.7),
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: isDarkMode ? Colors.white : Colors.black),
                  onPressed: () {
                    setState(() {
                      controller.clear();
                    });
                  },
                )
              : _isSelectingAppsToHide ? null : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.sort, color: isDarkMode ? Colors.white : Colors.black),
                      onPressed: _showAppListSortOptions,
                    ),
                    IconButton(
                      icon: Icon(Icons.settings, color: isDarkMode ? Colors.white : Colors.black),
                      onPressed: () {
                        NavigationState.currentScreen = 'settings';
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SettingsPage(
                              isSearchBarAtTop: _isSearchBarAtTop,
                              onSearchBarPositionChanged: _updateSearchBarPosition,
                              onNotificationBadgesChanged: (value) {
                                setState(() {
                                  _showNotificationBadges = value;
                                });
                              },
                            ),
                          ),
                        ).then((_) => NavigationState.currentScreen = 'main');
                      },
                    ),
                  ],
                ),
          filled: true,
          fillColor: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Future<void> _loadHiddenApps() async {
    final hiddenApps = await HiddenAppsManager.loadHiddenApps();
    setState(() {
      _hiddenApps.clear();
      _hiddenApps.addAll(hiddenApps);
    });
  }

  Future<void> _saveHiddenApps() async {
    await HiddenAppsManager.saveHiddenApps(_hiddenApps);
  }

  Future<void> _savePinnedAppsBackup() async {
    await HiddenAppsManager.savePinnedAppsBackup(_pinnedAppsBackup);
  }

  Future<void> _loadPinnedAppsBackup() async {
    final backup = await HiddenAppsManager.loadPinnedAppsBackup();
    _pinnedAppsBackup.clear();
    _pinnedAppsBackup.addAll(backup);
  }

  Widget _buildAppListContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // When selecting apps to hide, show filtered apps list
    if (_isSelectingAppsToHide) {
      return Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredApps.length,
              itemBuilder: (context, index) {
                final app = _filteredApps[index];
                return _buildAppTile(app, false);
              },
            ),
          ),
        ],
      );
    }

    return RawScrollbar(
      controller: _scrollController,
      thumbColor: Colors.white.withOpacity(0.3),
      radius: const Radius.circular(20),
      thickness: 6,
      thumbVisibility: true,
      trackVisibility: false,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          if (!_showingHiddenApps && _pinnedApps.isNotEmpty && _searchController.text.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildPinnedAppsHeader(),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildAppTile(_pinnedApps[index], true),
                ),
                childCount: _pinnedApps.length,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.24),
                ),
              ),
            ),
          ],
          ...AppSectionManager.createSections(
            _filteredApps,
            sortType: _appListSortType
          ).expand((section) => [
            if (_appListSortType != AppListSortType.usage) 
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    section.letter,
                    style: TextStyle(
                      color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
    );
  }

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;


  Future<Uint8List?> _loadWidgetPreview(WidgetInfo widget) async {
    // Return null if no preview image is provided
    if (widget.previewImage.isEmpty) return null;
    
    // Use widgetId as key for caching (assumes widgetId is non-null for added widgets)
    if (widget.widgetId != null && _widgetPreviewCache.containsKey(widget.widgetId)) {
      return _widgetPreviewCache[widget.widgetId];
    }
    
    try {
      // Decode the base64-encoded preview image
      final decoded = base64Decode(widget.previewImage);
      if (widget.widgetId != null) {
        _widgetPreviewCache[widget.widgetId!] = decoded;
      }
      return decoded;
    } catch (e) {
      debugPrint('Error decoding widget preview image: $e');
      return null;
    }
  }
}