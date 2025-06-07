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
import 'live_widget_preview.dart';
import 'database/app_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'layouts/app_layout_switcher.dart';
import 'layouts/app_layout_manager.dart';
import 'dart:async';
import 'app_package_manager.dart';
import 'models/folder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      title: 'FuseLauncher',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4), // Primary purple color
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.light().textTheme,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Color(0xFF6750A4)),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6750A4),
          ),
        ),
        dialogTheme: DialogTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF), // Lighter purple for dark mode
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.dark().textTheme,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: const Color(0xFF2D2D2D),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Color(0xFFD0BCFF)),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFD0BCFF),
          ),
        ),
        dialogTheme: DialogTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: const Color(0xFF1E1E1E),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: const Color(0xFF2D2D2D),
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
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

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late final ScrollController _scrollController = ScrollController();
  final ScrollController _widgetsScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _hiddenAppsSearchController =
      TextEditingController();
  final List<String> _tabs = ['Apps', 'Widgets'];
  int _selectedIndex = 0;
  List<AppInfo> _apps = [];
  List<Folder> _folders = [];
  List<WidgetInfo> _addedWidgets = [];
  bool _isLoading = true;
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
  final Map<String, int> _hiddenAppFolderMap = {};
  bool _isSelectingAppsToHide = false;
  Key _appLayoutKey = UniqueKey();
  bool _isWidgetsScrolling = false;
  Timer? _widgetsScrollEndTimer;
  bool _isAppsScrolling = false;
  Timer? _appsScrollEndTimer;

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

    // Clean up database on startup
    _performDatabaseCleanup();

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
    _loadHiddenAppFolderMap();

    const systemChannel =
        MethodChannel('com.kayfahaarukku.fuselauncher/system');
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
    _widgetsScrollController.addListener(_widgetsScrollListener);
    _scrollController.addListener(_appsScrollListener);
  }

  Future<void> _loadFolders() async {
    final folders = await AppDatabase.getFolders();
    for (var folder in folders) {
      folder.apps = folder.appPackageNames
          .map((packageName) {
            try {
              return _apps.firstWhere((app) => app.packageName == packageName);
            } catch (e) {
              return null;
            }
          })
          .whereType<AppInfo>()
          .toList();
    }

    // Sort folders based on current sort type
    _sortFolders(folders, _appListSortType);

    if (mounted) {
      setState(() {
        _folders = folders;
      });
    }
  }

  void _sortFolders(List<Folder> folders, AppListSortType sortType) {
    switch (sortType) {
      case AppListSortType.alphabeticalAsc:
        folders.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case AppListSortType.alphabeticalDesc:
        folders.sort(
            (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case AppListSortType.usage:
        // For usage-based sorting, sort by the highest priority app in each folder
        folders.sort((a, b) {
          // Find the highest priority (lowest index) app in each folder
          int getHighestPriorityIndex(Folder folder) {
            if (folder.apps.isEmpty) return 999999;

            int highestPriority = 999999;
            for (var app in folder.apps) {
              final index =
                  _apps.indexWhere((a) => a.packageName == app.packageName);
              if (index != -1 && index < highestPriority) {
                highestPriority = index;
              }
            }
            return highestPriority;
          }

          final aPriority = getHighestPriorityIndex(a);
          final bPriority = getHighestPriorityIndex(b);

          // If both folders have no valid apps, sort alphabetically
          if (aPriority == 999999 && bPriority == 999999) {
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }

          return aPriority.compareTo(bPriority);
        });
        break;
    }
  }

  /// Clean up the database to ensure it's in sync with installed apps
  Future<void> _performDatabaseCleanup() async {
    try {
      // Get all installed package names directly from device
      final validPackages = await AppPackageManager.getInstalledPackageNames();

      // Clean up the database, removing any apps that aren't installed
      await AppDatabase.cleanupInvalidApps(validPackages);
      debugPrint('Database cleanup complete');
    } catch (e) {
      debugPrint('Error during database cleanup: $e');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showNotificationBadges =
          prefs.getBool('show_notification_badges') ?? true;
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
    _scrollController.removeListener(_appsScrollListener);
    _scrollController.dispose();
    _widgetsScrollController.dispose();
    _searchController.dispose();
    _hiddenAppsSearchController.dispose();
    _iconCache.clear();
    _searchFocusNode.dispose();
    NotificationService.dispose();
    _appsScrollEndTimer?.cancel();
    _widgetsScrollEndTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadApps(
      {bool background = false, bool forceRefresh = false}) async {
    if ((_isLoading && !background) || (_isBackgroundLoading && background)) {
      debugPrint('Loading already in progress, skipping');
      return;
    }

    try {
      if (background) {
        setState(() {
          _isBackgroundLoading = true;
        });
      } else {
        setState(() {
          _isLoading = true;
        });
      }

      // First try to load from cache - but only if not forcing refresh
      if (!background && !forceRefresh) {
        await _loadCachedApps();
      }

      // Then check if we need to refresh from the system
      final lastUpdate = await AppDatabase.getLastUpdateTime();
      final now = DateTime.now();
      final shouldRefresh = forceRefresh ||
          lastUpdate == null ||
          now.difference(lastUpdate) > const Duration(minutes: 10);

      if (shouldRefresh || background) {
        // If we need to update, do it in the background
        await _refreshAppsInBackground();
      }

      // Always reset loading state when done
      if (mounted) {
        setState(() {
          if (background) {
            _isBackgroundLoading = false;
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading apps: $e');
      if (mounted) {
        setState(() {
          if (!background) {
            _isLoading = false;
          }
          _isBackgroundLoading = false;
        });
      }
    }
  }

  Future<void> _loadCachedApps() async {
    final cachedApps = await AppDatabase.getCachedApps();
    if (cachedApps.isNotEmpty && mounted) {
      setState(() {
        _apps = cachedApps;
        _isLoading = false;
      });
      await AppUsageTracker.sortAppList(_apps, _appListSortType);
      await _loadPinnedApps();
      await _loadFolders();
      if (mounted) {
        setState(() {
          _appSections = AppSectionManager.createSections(_apps,
              sortType: _appListSortType);
        });
      }
    }
  }

  Future<void> _refreshAppsInBackground() async {
    try {
      // Fetch all apps directly from the system
      List<AppInfo> freshApps = [];
      try {
        freshApps = await InstalledApps.getInstalledApps(false, true, true);
      } catch (e) {
        // If we get an exception fetching all apps, try a safer approach
        debugPrint('Error fetching all apps: $e');
        freshApps = await _getSafeInstalledApps();
      }

      if (freshApps.isEmpty) {
        // If we still couldn't get apps, don't proceed with updates
        debugPrint('Could not get app list - skipping update');
        return;
      }

      // Clean up any invalid apps from the database
      final validPackageNames =
          freshApps.map((app) => app.packageName).toList();
      await AppDatabase.cleanupInvalidApps(validPackageNames);

      // Track changes between old and new app lists
      final Set<String> oldPackageNames =
          _apps.map((app) => app.packageName).toSet();
      final Set<String> newPackageNames =
          freshApps.map((app) => app.packageName).toSet();

      // Find apps that were removed and added
      final Set<String> removedApps =
          oldPackageNames.difference(newPackageNames);
      final Set<String> addedApps = newPackageNames.difference(oldPackageNames);

      // Log changes for debugging
      if (removedApps.isNotEmpty) {
        debugPrint('Detected removed apps: ${removedApps.join(', ')}');
      }

      if (addedApps.isNotEmpty) {
        debugPrint('Detected new apps: ${addedApps.join(', ')}');
      }

      // Handle changes to pinned apps if necessary
      if (removedApps.isNotEmpty) {
        for (final packageName in removedApps) {
          // Remove from database
          await AppDatabase.removeApp(packageName);

          // Remove from pinned apps list
          _pinnedApps.removeWhere((app) => app.packageName == packageName);
        }
        await _savePinnedApps();
      }

      // Cache the fresh data in the database
      await AppDatabase.cacheApps(freshApps);

      if (mounted) {
        // Update the app list with the fresh data
        setState(() {
          _apps = freshApps;
        });

        // Sort the app list
        await AppUsageTracker.sortAppList(_apps, _appListSortType);

        // Refresh pinned apps to ensure consistency
        await _loadPinnedApps();

        await _loadFolders();

        if (mounted) {
          setState(() {
            _appSections = AppSectionManager.createSections(_apps,
                sortType: _appListSortType);
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing apps: $e');
      rethrow; // Let the calling method handle the loading state
    }
  }

  // Safely get installed apps with error handling for individual apps
  Future<List<AppInfo>> _getSafeInstalledApps() async {
    return AppPackageManager.getInstalledAppsSafely(
        excludeSystemApps: false, withIcon: true, includeAppSize: false);
  }

  Future<bool> _onWillPop() async {
    if (_searchController.text.isNotEmpty ||
        _hiddenAppsSearchController.text.isNotEmpty) {
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

  void _showAppOptions(BuildContext context, AppInfo application, bool isPinned,
      {VoidCallback? onAppRemoved}) async {
    bool? isSystemAppResult =
        await InstalledApps.isSystemApp(application.packageName);
    bool isSystemApp = isSystemAppResult ?? true;
    bool isHidden = _hiddenApps.contains(application.packageName);
    Folder? parentFolder;
    try {
      parentFolder = _folders.firstWhere(
          (f) => f.appPackageNames.contains(application.packageName));
    } catch (e) {
      parentFolder = null;
    }

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor:
            isDarkMode ? const Color(0xFF252525) : Colors.white.withAlpha(242),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        isScrollControlled: true,
        builder: (context) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF757575)
                      : const Color(0xFFBDBDBD),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 20),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? const Color(0xFF424242)
                                      : const Color(0xFFE0E0E0),
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
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Icon(
                                              Icons.android,
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : Colors.black54,
                                            );
                                          },
                                        )
                                      : Icon(
                                          Icons.android,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black54,
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
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      application.packageName,
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black54,
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
                            leading: Icon(Icons.visibility,
                                color:
                                    isDarkMode ? Colors.white : Colors.black),
                            title: Text(
                              'Unhide App',
                              style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.black),
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              await _restoreAppToFolder(
                                  application.packageName);
                              setState(() {
                                _hiddenApps.remove(application.packageName);
                                _searchController.clear();
                                _hiddenAppsSearchController.clear();
                                // Don't restore pinned status - require user to pin again
                                if (_pinnedAppsBackup
                                    .contains(application.packageName)) {
                                  // Don't add back to _pinnedApps
                                  _pinnedAppsBackup
                                      .remove(application.packageName);
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
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          title: Text(
                            isPinned ? 'Unpin' : 'Pin to Top',
                            style: TextStyle(
                                color:
                                    isDarkMode ? Colors.white : Colors.black),
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            // Check if app is hidden - if so, don't allow pinning
                            if (!isPinned &&
                                _hiddenApps.contains(application.packageName)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Hidden apps cannot be pinned'),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              if (isPinned) {
                                _pinnedApps.removeWhere((pinnedApp) =>
                                    pinnedApp.packageName ==
                                    application.packageName);
                              } else {
                                if (!_pinnedApps.any((app) =>
                                    app.packageName ==
                                    application.packageName)) {
                                  if (_pinnedApps.length < 10) {
                                    _pinnedApps.add(application);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Maximum 10 apps can be pinned'),
                                      ),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${application.name} is already pinned'),
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
                            leading:
                                const Icon(Icons.delete, color: Colors.red),
                            title: Text(
                              'Uninstall',
                              style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.black),
                            ),
                            onTap: () async {
                              Navigator.pop(context);

                              try {
                                // Start the uninstallation process
                                await InstalledApps.uninstallApp(
                                    application.packageName);

                                // Remove from any folder
                                for (var folder in _folders) {
                                  if (folder.appPackageNames
                                      .contains(application.packageName)) {
                                    folder.appPackageNames
                                        .remove(application.packageName);
                                    await AppDatabase.updateFolder(folder);
                                  }
                                }

                                // Immediately remove from our database
                                await AppDatabase.removeApp(
                                    application.packageName);

                                // Remove the app from the current list directly
                                if (mounted) {
                                  setState(() {
                                    _apps.removeWhere((app) =>
                                        app.packageName ==
                                        application.packageName);
                                    _pinnedApps.removeWhere((app) =>
                                        app.packageName ==
                                        application.packageName);
                                    _appSections =
                                        AppSectionManager.createSections(_apps,
                                            sortType: _appListSortType);
                                    // Reset loading indicators to prevent stuck state
                                    _isBackgroundLoading = false;
                                    _isLoading = false;
                                  });
                                }

                                // Force refresh app list after uninstall
                                if (mounted) {
                                  _loadApps(
                                      background: true, forceRefresh: true);
                                }
                              } catch (e) {
                                // If any error occurs, ensure loading states are reset
                                if (mounted) {
                                  setState(() {
                                    _isBackgroundLoading = false;
                                    _isLoading = false;
                                  });
                                }
                                debugPrint('Error during uninstall: $e');
                              }
                            },
                          ),
                        ListTile(
                          leading: Icon(Icons.info_outline,
                              color: isDarkMode ? Colors.white : Colors.black),
                          title: Text(
                            'App Info',
                            style: TextStyle(
                                color:
                                    isDarkMode ? Colors.white : Colors.black),
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            await InstalledApps.openSettings(
                                application.packageName);

                            // When returning from app settings, force refresh the app list
                            // as the user might have uninstalled or updated the app
                            if (mounted) {
                              _loadApps(background: true, forceRefresh: true);
                            }
                          },
                        ),
                        if (parentFolder != null)
                          ListTile(
                            leading: Icon(Icons.folder_off_outlined,
                                color:
                                    isDarkMode ? Colors.white : Colors.black),
                            title: Text(
                              'Remove from Folder',
                              style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.black),
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              parentFolder!.appPackageNames
                                  .remove(application.packageName);
                              await AppDatabase.updateFolder(parentFolder);
                              await _loadFolders();
                              onAppRemoved?.call();
                            },
                          )
                        else if (!isHidden)
                          ListTile(
                            leading: Icon(
                              Icons.folder_open,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            title: Text(
                              'Move to Folder',
                              style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.black),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _showMoveToFolderDialog(application);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  void _showMoveToFolderDialog(AppInfo app) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Move ${app.name} to...'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _folders.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const Icon(Icons.create_new_folder),
                    title: const Text('Create new folder'),
                    onTap: () {
                      Navigator.pop(context);
                      _showCreateFolderDialog(app);
                    },
                  );
                }
                final folder = _folders[index - 1];
                return ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(folder.name),
                  onTap: () async {
                    Navigator.pop(context);
                    await _addAppToFolder(app, folder);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showCreateFolderDialog(AppInfo app) {
    final folderNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Folder'),
          content: TextField(
            controller: folderNameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Folder name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final folderName = folderNameController.text.trim();
                if (folderName.isNotEmpty) {
                  if (_folders.any((f) =>
                      f.name.toLowerCase() == folderName.toLowerCase())) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('A folder with this name already exists.')),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  // Remove from any existing folder first
                  int? sourceFolderId;
                  for (var f in _folders) {
                    if (f.appPackageNames.contains(app.packageName)) {
                      sourceFolderId = f.id;
                      break;
                    }
                  }
                  if (sourceFolderId != null) {
                    final sourceFolder =
                        _folders.firstWhere((f) => f.id == sourceFolderId);
                    sourceFolder.appPackageNames.remove(app.packageName);
                    await AppDatabase.updateFolder(sourceFolder);
                  }

                  await AppDatabase.createFolder(folderName, [app.packageName]);
                  await _loadFolders();
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addAppToFolder(AppInfo app, Folder folder) async {
    int? sourceFolderId;
    // Find which folder the app is in, if any
    for (var f in _folders) {
      if (f.appPackageNames.contains(app.packageName)) {
        sourceFolderId = f.id;
        break;
      }
    }

    // If it's already in the target folder, do nothing.
    if (sourceFolderId != null && sourceFolderId == folder.id) {
      return;
    }

    // If it's in another folder, remove it from there.
    if (sourceFolderId != null) {
      final sourceFolder = _folders.firstWhere((f) => f.id == sourceFolderId);
      sourceFolder.appPackageNames.remove(app.packageName);
      await AppDatabase.updateFolder(sourceFolder);
    }

    // Add it to the new folder.
    folder.appPackageNames.add(app.packageName);
    await AppDatabase.updateFolder(folder);

    await _loadFolders();
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
      final index = unorderedWidgets
          .indexWhere((w) => w.widgetId?.toString() == widgetId);
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        // Since canPop is false, didPop will be false when this is invoked
        // due to a pop attempt that PopScope is intercepting.
        // So, we effectively always call _onWillPop.
        await _onWillPop();
      },
      child: GestureDetector(
        onTap: _unfocusSearch,
        child: Scaffold(
          backgroundColor:
              (isDarkMode ? Colors.black : Colors.white).withAlpha(128),
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                if (_isSelectingAppsToHide)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Select apps to hide',
                                style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final authenticated =
                                    await AuthService.authenticateUser();
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
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Search bar for the "select apps to hide" view
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(13, 0, 0, 0),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _hiddenAppsSearchController,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              hintText: 'Search apps to hide...',
                              hintStyle: TextStyle(
                                color:
                                    (isDarkMode ? Colors.white : Colors.black)
                                        .withAlpha(128),
                                fontSize: 16,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color:
                                    (isDarkMode ? Colors.white : Colors.black)
                                        .withAlpha(179),
                                size: 22,
                              ),
                              suffixIcon:
                                  _hiddenAppsSearchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.clear,
                                            color: (isDarkMode
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withAlpha(179),
                                            size: 22,
                                          ),
                                          onPressed: () {
                                            _hiddenAppsSearchController.clear();
                                            setState(() {
                                              // Force rebuild to update the filtered apps
                                            });
                                          },
                                        )
                                      : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: isDarkMode
                                  ? const Color(0xFF2D2D2D)
                                  : Colors.white,
                            ),
                            onChanged: (_) {
                              setState(() {
                                // Force rebuild when search text changes
                              });
                            },
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
                        color: (isDarkMode ? Colors.white : Colors.black)
                            .withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorColor: Colors.transparent,
                        dividerColor: Colors.transparent,
                        labelColor: isDarkMode ? Colors.white : Colors.black,
                        unselectedLabelColor:
                            (isDarkMode ? Colors.white : Colors.black)
                                .withAlpha(128),
                        indicator: BoxDecoration(
                          color: (isDarkMode ? Colors.white : Colors.black)
                              .withAlpha(51),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _isSelectingAppsToHide
                      ? Theme(
                          data: Theme.of(context).copyWith(
                            canvasColor: Colors.transparent,
                            scrollbarTheme: ScrollbarThemeData(
                              thumbColor: WidgetStateProperty.all(
                                  Colors.white.withAlpha(77)),
                              radius: const Radius.circular(20),
                              thickness: WidgetStateProperty.all(6.0),
                              interactive: true,
                            ),
                          ),
                          child: Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: _isAppsScrolling,
                            interactive: true,
                            child: ScrollConfiguration(
                              behavior: AppScrollBehavior().copyWith(
                                physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics()),
                              ),
                              child: AppLayoutSwitcher(
                                key: _appLayoutKey,
                                apps: _apps,
                                folders: const [],
                                onFoldersChanged: _loadFolders,
                                pinnedApps: const [],
                                showingHiddenApps: _showingHiddenApps,
                                onAppLongPress: (context, app, isPinned,
                                        {onAppRemoved}) =>
                                    _showAppOptions(context, app, isPinned,
                                        onAppRemoved: onAppRemoved),
                                isSelectingAppsToHide: _isSelectingAppsToHide,
                                hiddenApps: _hiddenApps,
                                onAppLaunch: (packageName) async {
                                  if (_hiddenApps.contains(packageName)) {
                                    await _restoreAppToFolder(packageName);
                                    setState(() {
                                      _hiddenApps.remove(packageName);
                                    });
                                  } else {
                                    await _removeAppFromFolderIfHidden(
                                        packageName);
                                    setState(() {
                                      _hiddenApps.add(packageName);
                                    });
                                  }
                                },
                                sortType: _appListSortType,
                                notificationCounts: _notificationCounts,
                                showNotificationBadges: _showNotificationBadges,
                                searchController:
                                    _showingHiddenApps || _isSelectingAppsToHide
                                        ? _hiddenAppsSearchController
                                        : _searchController,
                                isBackgroundLoading: _isBackgroundLoading,
                              ),
                            ),
                          ),
                        )
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
      onHorizontalDragStart: (_selectedIndex == 0)
          ? (details) {
              _horizontalDragStart = details.localPosition.dx;
              _isSwipeInProgress = false;
            }
          : null,
      onHorizontalDragUpdate: (_selectedIndex == 0)
          ? (details) async {
              if (_isSwipeInProgress) return;

              final dragDistance =
                  details.localPosition.dx - _horizontalDragStart;
              final screenWidth = MediaQuery.of(context).size.width;
              final now = DateTime.now();

              // Handle left-to-right swipe for hidden apps (when not already showing hidden apps)
              if (!_showingHiddenApps && dragDistance > screenWidth * 0.2) {
                _isSwipeInProgress = true;

                if (_lastSwipeTime != null &&
                    now.difference(_lastSwipeTime!) <
                        const Duration(milliseconds: 500)) {
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
            }
          : null,
      onHorizontalDragEnd: (_selectedIndex == 0)
          ? (details) {
              _isSwipeInProgress = false;
              // Reset first swipe if too much time has passed
              if (_lastSwipeTime != null &&
                  DateTime.now().difference(_lastSwipeTime!) >
                      const Duration(milliseconds: 500)) {
                _hasCompletedFirstSwipe = false;
              }
            }
          : null,
      child: Column(
        children: [
          if (_isSearchBarAtTop) _buildSearchBar(),
          if (_showingHiddenApps)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red.withAlpha(26),
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
                      final authenticated =
                          await AuthService.authenticateUser();
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
            child: Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Colors.transparent,
                scrollbarTheme: ScrollbarThemeData(
                  thumbColor:
                      WidgetStateProperty.all(Colors.white.withAlpha(77)),
                  radius: const Radius.circular(20),
                  thickness: WidgetStateProperty.all(6.0),
                  interactive: true,
                ),
              ),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: _isAppsScrolling,
                interactive: true,
                child: ScrollConfiguration(
                  behavior: AppScrollBehavior().copyWith(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                  ),
                  child: AppLayoutSwitcher(
                    key: _appLayoutKey,
                    apps: _apps,
                    folders: _folders,
                    onFoldersChanged: _loadFolders,
                    pinnedApps: _pinnedApps
                        .where((app) => !_hiddenApps.contains(app.packageName))
                        .toList(), // Filter out hidden apps from pinned apps
                    showingHiddenApps: _showingHiddenApps,
                    onAppLongPress: (context, app, isPinned, {onAppRemoved}) =>
                        _showAppOptions(context, app, isPinned,
                            onAppRemoved: onAppRemoved),
                    isSelectingAppsToHide: _isSelectingAppsToHide,
                    hiddenApps: _hiddenApps,
                    onAppLaunch: (packageName) async {
                      await AppUsageTracker.recordAppLaunch(packageName);
                    },
                    sortType: _appListSortType,
                    notificationCounts: _notificationCounts,
                    showNotificationBadges: _showNotificationBadges,
                    searchController:
                        _showingHiddenApps || _isSelectingAppsToHide
                            ? _hiddenAppsSearchController
                            : _searchController,
                    isBackgroundLoading: _isBackgroundLoading,
                  ),
                ),
              ),
            ),
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
          onLongPress: _isReorderingWidgets
              ? null
              : () {
                  if (_addedWidgets.isNotEmpty) {
                    HapticFeedback.heavyImpact();
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: isDarkMode
                          ? const Color(0xFF212121)
                          : const Color(0xFFF5F5F5),
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: Icon(Icons.reorder,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black),
                              title: Text(
                                'Reorder Widgets',
                                style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  _isReorderingWidgets = true;
                                });
                              },
                            ),
                            ListTile(
                              leading:
                                  Icon(Icons.delete_sweep, color: Colors.red),
                              title: Text(
                                'Remove All Widgets',
                                style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: isDarkMode
                                        ? const Color(0xFF212121)
                                        : const Color(0xFFF5F5F5),
                                    title: Text(
                                      'Clear All Widgets',
                                      style: TextStyle(
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black),
                                    ),
                                    content: Text(
                                      'Are you sure you want to remove all widgets?',
                                      style: TextStyle(
                                          color: isDarkMode
                                              ? Colors.white70
                                              : Colors.black54),
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
                                              await WidgetManager.removeWidget(
                                                  widget.widgetId!);
                                            }
                                          }
                                          await _loadAddedWidgets();
                                          setState(() {});
                                        },
                                        child: Text(
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
                        );
                      },
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
                      const Icon(Icons.info_outline,
                          color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Drag widgets to reorder them',
                          style: TextStyle(
                            color: Colors.white.withAlpha(179),
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
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
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
                          scrollbarTheme: ScrollbarThemeData(
                            thumbColor: WidgetStateProperty.all(
                                Colors.white.withAlpha(77)),
                            radius: const Radius.circular(20),
                            thickness: WidgetStateProperty.all(6.0),
                            interactive: true,
                          ),
                        ),
                        child: Scrollbar(
                          controller: _widgetsScrollController,
                          thumbVisibility: _isWidgetsScrolling,
                          interactive: true,
                          child: ScrollConfiguration(
                            behavior: AppScrollBehavior().copyWith(
                              physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics()),
                            ),
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
                                      context, _addedWidgets[index]),
                                  child: Container(
                                    width: double.infinity,
                                    height: _addedWidgets[index]
                                        .minHeight
                                        .toDouble(),
                                    decoration: BoxDecoration(
                                      color: (isDarkMode
                                              ? Colors.white
                                              : Colors.black)
                                          .withAlpha(26),
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
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _showAddWidgetDialog,
            backgroundColor:
                isDarkMode ? const Color(0xFF6750A4) : const Color(0xFF6200EE),
            child: Icon(Icons.add, color: Colors.white),
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
              backgroundColor: isDarkMode
                  ? const Color(0xFF212121)
                  : const Color(0xFFF5F5F5),
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
                        hintStyle: TextStyle(
                            color:
                                isDarkMode ? Colors.white70 : Colors.black54),
                        prefixIcon: Icon(Icons.search,
                            color:
                                isDarkMode ? Colors.white70 : Colors.black54),
                        filled: true,
                        fillColor: isDarkMode
                            ? const Color(0xFF3A3A3A)
                            : const Color(0xFFE0E0E0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          filteredWidgets = widgets
                              .where((widget) =>
                                  widget.appName
                                      .toLowerCase()
                                      .contains(value.toLowerCase()) ||
                                  widget.label
                                      .toLowerCase()
                                      .contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _groupWidgetsByApp(filteredWidgets).length,
                        itemBuilder: (context, index) {
                          final entry = _groupWidgetsByApp(filteredWidgets)
                              .entries
                              .elementAt(index);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(179),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ...entry.value.map((widget) => ListTile(
                                    title: Text(
                                      widget.label,
                                      style: TextStyle(
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black),
                                    ),
                                    subtitle: Text(
                                      '${(widget.minWidth / MediaQuery.of(context).devicePixelRatio).round()}x'
                                      '${(widget.minHeight / MediaQuery.of(context).devicePixelRatio).round()} dp',
                                      style: TextStyle(
                                          color: isDarkMode
                                              ? Colors.white70
                                              : Colors.black54),
                                    ),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      final success =
                                          await WidgetManager.addWidget(widget);
                                      if (success && mounted) {
                                        await _loadAddedWidgets();
                                        setState(
                                            () {}); // Refresh the widget list
                                      }
                                    },
                                  )),
                              Divider(
                                  color: isDarkMode
                                      ? const Color(0x3DFFFFFF)
                                      : const Color(0x3D000000)),
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
        grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  void _showWidgetOptions(BuildContext context, WidgetInfo widget) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor:
          isDarkMode ? const Color(0xFF212121) : const Color(0xFFF5F5F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      isScrollControlled: true,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF757575)
                    : const Color(0xFFBDBDBD),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
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
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    widget.appName,
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
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
                        leading: Icon(Icons.reorder,
                            color: isDarkMode ? Colors.white : Colors.black),
                        title: Text(
                          'Reorder Widgets',
                          style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _isReorderingWidgets = true;
                          });
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text(
                          'Remove Widget',
                          style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black),
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
        );
      },
    );
  }

  Future<Widget> _getAppIcon(String packageName) async {
    try {
      final iconData = await _getAppIconData(packageName);
      if (iconData != null) {
        return Image.memory(iconData);
      }
      return const SizedBox();
    } catch (e) {
      debugPrint('Error creating app icon widget for $packageName: $e');
      return const SizedBox();
    }
  }

  Future<Uint8List?> _getAppIconData(String packageName) async {
    try {
      // First try to get from the loaded apps list
      try {
        final app = _apps.firstWhere((app) => app.packageName == packageName);
        if (app.icon != null) {
          return app.icon;
        }
      } catch (e) {
        // App not found in the list, continue to other methods
        debugPrint(
            'App $packageName not found in current list when loading icon data: $e');
      }

      // If not found or icon is null, try to load icon
      return await _loadAppIcon(packageName);
    } catch (e) {
      debugPrint('Error getting app icon data for $packageName: $e');
      return null;
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        // App is in the foreground
        debugPrint('App resumed - refreshing app list');
        _loadApps(background: true, forceRefresh: true);
        break;
      case AppLifecycleState.inactive:
        // App is partially obscured, may be entering multitasking
        break;
      case AppLifecycleState.paused:
        // App is in the background
        _savePinnedAppsBackup();
        break;
      case AppLifecycleState.detached:
        // App is detached from UI (being killed)
        _savePinnedAppsBackup();
        break;
      case AppLifecycleState.hidden:
        // App is completely hidden (newer Flutter versions)
        break;
    }
  }

  Future<void> _savePinnedApps() async {
    final prefs = await SharedPreferences.getInstance();

    // Keep only valid apps while preserving order
    final validPinnedApps = _pinnedApps
        .where((app) => _apps.any((a) => a.packageName == app.packageName))
        .toList();

    if (!listEquals(validPinnedApps, _pinnedApps)) {
      setState(() {
        _pinnedApps = validPinnedApps;
      });
    }

    // Save both package names and their order
    final pinnedAppData = validPinnedApps
        .asMap()
        .map((index, app) => MapEntry(app.packageName, index));
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
      backgroundColor:
          isDarkMode ? const Color(0xFF212121) : const Color(0xFFF5F5F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return SingleChildScrollView(
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
                    color: isDarkMode
                        ? const Color(0xFF757575)
                        : const Color(0xFFBDBDBD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.trending_up,
                      color: isDarkMode ? Colors.white : Colors.black),
                  title: Text('Sort by Usage',
                      style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black)),
                  trailing: _appListSortType == AppListSortType.usage
                      ? Icon(Icons.check,
                          color: isDarkMode ? Colors.white : Colors.black)
                      : null,
                  onTap: () async {
                    Navigator.pop(context);
                    await AppUsageTracker.sortAppList(
                        _apps, AppListSortType.usage);
                    _sortFolders(_folders, AppListSortType.usage);
                    setState(() {
                      _appListSortType = AppListSortType.usage;
                      _appSections = AppSectionManager.createSections(_apps,
                          sortType: _appListSortType);
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.sort_by_alpha,
                      color: isDarkMode ? Colors.white : Colors.black),
                  title: Text('Sort A to Z',
                      style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black)),
                  trailing: _appListSortType == AppListSortType.alphabeticalAsc
                      ? Icon(Icons.check,
                          color: isDarkMode ? Colors.white : Colors.black)
                      : null,
                  onTap: () async {
                    Navigator.pop(context);
                    await AppUsageTracker.sortAppList(
                        _apps, AppListSortType.alphabeticalAsc);
                    _sortFolders(_folders, AppListSortType.alphabeticalAsc);
                    setState(() {
                      _appListSortType = AppListSortType.alphabeticalAsc;
                      _appSections = AppSectionManager.createSections(_apps,
                          sortType: _appListSortType);
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.sort_by_alpha_rounded,
                      color: isDarkMode ? Colors.white : Colors.black),
                  title: Text('Sort Z to A',
                      style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black)),
                  trailing: _appListSortType == AppListSortType.alphabeticalDesc
                      ? Icon(Icons.check,
                          color: isDarkMode ? Colors.white : Colors.black)
                      : null,
                  onTap: () async {
                    Navigator.pop(context);
                    await AppUsageTracker.sortAppList(
                        _apps, AppListSortType.alphabeticalDesc);
                    _sortFolders(_folders, AppListSortType.alphabeticalDesc);
                    setState(() {
                      _appListSortType = AppListSortType.alphabeticalDesc;
                      _appSections = AppSectionManager.createSections(_apps,
                          sortType: _appListSortType);
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadSortTypes() async {
    _appListSortType = await AppUsageTracker.getSavedAppListSortType();
    if (mounted) setState(() {});
  }

  double _getBottomSheetPadding(BuildContext context) {
    // Get the bottom padding (includes navigation bar height)
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    // Add additional padding for visual spacing
    return bottomPadding + 16.0;
  }

  void _unfocusSearch() {
    _searchFocusNode.unfocus();
    setState(() {});
  }

  Widget _buildSearchBar() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final controller = _showingHiddenApps || _isSelectingAppsToHide
        ? _hiddenAppsSearchController
        : _searchController;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(13, 0, 0, 0), // 0.05 opacity (13/255)
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          focusNode: _searchFocusNode,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            hintText: _showingHiddenApps
                ? 'Search hidden apps...'
                : _isSelectingAppsToHide
                    ? 'Search apps to hide...'
                    : 'Search apps...',
            hintStyle: TextStyle(
              color: (isDarkMode ? Colors.white : Colors.black).withAlpha(128),
              fontSize: 16,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: (isDarkMode ? Colors.white : Colors.black).withAlpha(179),
              size: 22,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: (isDarkMode ? Colors.white : Colors.black)
                          .withAlpha(179),
                      size: 22,
                    ),
                    onPressed: () {
                      controller.clear();
                      setState(() {
                        // Force rebuild to update the filtered apps
                      });
                    },
                  )
                : _isSelectingAppsToHide
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.sort,
                              color: (isDarkMode ? Colors.white : Colors.black)
                                  .withAlpha(179),
                              size: 22,
                            ),
                            onPressed: _showAppListSortOptions,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.settings,
                              color: (isDarkMode ? Colors.white : Colors.black)
                                  .withAlpha(179),
                              size: 22,
                            ),
                            onPressed: () {
                              NavigationState.currentScreen = 'settings';
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SettingsPage(
                                    isSearchBarAtTop: _isSearchBarAtTop,
                                    showNotificationBadges:
                                        _showNotificationBadges,
                                    onSearchBarPositionChanged:
                                        _updateSearchBarPosition,
                                    onNotificationBadgesChanged: (value) {
                                      setState(() {
                                        _showNotificationBadges = value;
                                      });
                                    },
                                    onLayoutChanged: _refreshAppLayout,
                                  ),
                                ),
                              ).then((_) =>
                                  NavigationState.currentScreen = 'main');
                            },
                          ),
                        ],
                      ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
          ),
          onChanged: (_) {
            setState(() {
              // Force rebuild when search text changes
            });
          },
        ),
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

  Future<void> _loadHiddenAppFolderMap() async {
    final map = await HiddenAppsManager.loadHiddenAppFolderMap();
    if (mounted) {
      setState(() {
        _hiddenAppFolderMap.clear();
        _hiddenAppFolderMap.addAll(map);
      });
    }
  }

  Future<void> _saveHiddenAppFolderMap() async {
    await HiddenAppsManager.saveHiddenAppFolderMap(_hiddenAppFolderMap);
  }

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  void _refreshAppLayout() {
    setState(() {
      // Force rebuild of the app layout
      _appLayoutKey = UniqueKey();
    });
  }

  void _widgetsScrollListener() {
    // Update scrolling state
    if (!_isWidgetsScrolling) {
      setState(() {
        _isWidgetsScrolling = true;
      });
    }

    // Reset timer on each scroll event
    _widgetsScrollEndTimer?.cancel();
    _widgetsScrollEndTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isWidgetsScrolling = false;
        });
      }
    });
  }

  void _appsScrollListener() {
    // Update scrolling state
    if (!_isAppsScrolling) {
      setState(() {
        _isAppsScrolling = true;
      });
    }

    // Reset timer on each scroll event
    _appsScrollEndTimer?.cancel();
    _appsScrollEndTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isAppsScrolling = false;
        });
      }
    });

    // Keep the existing smooth scroll listener functionality
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

  Future<void> _restoreAppToFolder(String packageName) async {
    if (_hiddenAppFolderMap.containsKey(packageName)) {
      final int? folderId = _hiddenAppFolderMap[packageName];
      if (folderId == null) {
        _hiddenAppFolderMap.remove(packageName);
        await _saveHiddenAppFolderMap();
        return;
      }
      try {
        final targetFolder = _folders.firstWhere((f) => f.id == folderId);
        if (!targetFolder.appPackageNames.contains(packageName)) {
          targetFolder.appPackageNames.add(packageName);
          await AppDatabase.updateFolder(targetFolder);
        }
        _hiddenAppFolderMap.remove(packageName);
        await _saveHiddenAppFolderMap();
        await _loadFolders();
      } catch (e) {
        _hiddenAppFolderMap.remove(packageName);
        await _saveHiddenAppFolderMap();
        debugPrint("Folder with id $folderId not found for app $packageName");
      }
    }
  }

  Future<void> _removeAppFromFolderIfHidden(String packageName) async {
    Folder? parentFolder;
    try {
      parentFolder = _folders.firstWhere(
        (f) => f.appPackageNames.contains(packageName),
      );
    } catch (e) {
      parentFolder = null;
    }

    if (parentFolder != null && parentFolder.id != null) {
      _hiddenAppFolderMap[packageName] = parentFolder.id!;
      parentFolder.appPackageNames.remove(packageName);
      await AppDatabase.updateFolder(parentFolder);
      await _saveHiddenAppFolderMap();
      await _loadFolders();
    }
  }
}
