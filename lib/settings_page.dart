import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'about_page.dart';
import 'navigation_state.dart';
import 'package:google_fonts/google_fonts.dart';
import 'layouts/app_layout_manager.dart';

class SettingsPage extends StatefulWidget {
  final bool isSearchBarAtTop;
  final Function(bool) onSearchBarPositionChanged;
  final bool showNotificationBadges;
  final Function(bool) onNotificationBadgesChanged;
  final VoidCallback onLayoutChanged;

  const SettingsPage({
    super.key,
    required this.isSearchBarAtTop,
    required this.onSearchBarPositionChanged,
    required this.showNotificationBadges,
    required this.onNotificationBadgesChanged,
    required this.onLayoutChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _currentPosition;
  late bool _showNotificationBadges;
  late AppLayoutType _currentLayout;
  late int _gridColumns;
  bool _layoutInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.isSearchBarAtTop;
    _showNotificationBadges = widget.showNotificationBadges;
    _loadLayoutSettings();
  }

  Future<void> _loadLayoutSettings() async {
    final layout = await AppLayoutManager.getCurrentLayout();
    final columns = await AppLayoutManager.getGridColumns();
    if (mounted) {
      setState(() {
        _currentLayout = layout;
        _gridColumns = columns;
        _layoutInitialized = true;
      });
    }
  }

  Future<void> _toggleNotificationBadges(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_notification_badges', value);
    setState(() {
      _showNotificationBadges = value;
    });
    widget.onNotificationBadgesChanged(value);
  }

  Future<void> _changeWallpaper(BuildContext context) async {
    try {
      const platform = MethodChannel('com.kayfahaarukku.fuselauncher/system');
      await platform.invokeMethod('changeWallpaper');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to change wallpaper')),
        );
      }
    }
  }

  void _showLayoutSettingsDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'App Layout',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioListTile<AppLayoutType>(
                    title: Text(
                      'List View',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    value: AppLayoutType.list,
                    groupValue: _currentLayout,
                    onChanged: (value) async {
                      await AppLayoutManager.saveLayoutPreference(
                          AppLayoutType.list);
                      setDialogState(() {
                        _currentLayout = AppLayoutType.list;
                      });
                      setState(() {
                        _currentLayout = AppLayoutType.list;
                      });
                      widget.onLayoutChanged();
                    },
                  ),
                  RadioListTile<AppLayoutType>(
                    title: Text(
                      'Grid View',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    value: AppLayoutType.grid,
                    groupValue: _currentLayout,
                    onChanged: (value) async {
                      await AppLayoutManager.saveLayoutPreference(
                          AppLayoutType.grid);
                      setDialogState(() {
                        _currentLayout = AppLayoutType.grid;
                      });
                      setState(() {
                        _currentLayout = AppLayoutType.grid;
                      });
                      widget.onLayoutChanged();
                    },
                  ),
                  if (_currentLayout == AppLayoutType.grid) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Grid Columns:',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            _gridColumns.toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Slider(
                      value: _gridColumns.toDouble(),
                      min: 2,
                      max: 6,
                      divisions: 4,
                      label: _gridColumns.toString(),
                      activeColor: const Color(0xFF6750A4),
                      onChanged: (value) async {
                        final newColumns = value.round();
                        await AppLayoutManager.saveGridColumns(newColumns);
                        setDialogState(() {
                          _gridColumns = newColumns;
                        });
                        setState(() {
                          _gridColumns = newColumns;
                        });
                        widget.onLayoutChanged();
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6750A4),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor:
            isDarkMode ? const Color(0xFF121212) : Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(
            'Settings',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          children: [
            _buildSettingsCategory("Interface"),
            const SizedBox(height: 8),
            _buildSettingsCard(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.search,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 22,
                  ),
                ),
                title: Text(
                  'Search Bar Position',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  _currentPosition ? 'Top' : 'Bottom',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: (isDarkMode ? Colors.white : Colors.black)
                        .withAlpha(179),
                  ),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor:
                          isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        'Search Bar Position',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RadioListTile(
                            title: Text(
                              'Top',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            value: true,
                            groupValue: _currentPosition,
                            onChanged: (value) {
                              setState(() {
                                _currentPosition = true;
                              });
                              widget.onSearchBarPositionChanged(true);
                              Navigator.pop(context);
                            },
                          ),
                          RadioListTile(
                            title: Text(
                              'Bottom',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            value: false,
                            groupValue: _currentPosition,
                            onChanged: (value) {
                              setState(() {
                                _currentPosition = false;
                              });
                              widget.onSearchBarPositionChanged(false);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (_layoutInitialized)
              _buildSettingsCard(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      AppLayoutManager.getLayoutIcon(_currentLayout),
                      color: isDarkMode ? Colors.white : Colors.black,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'App Layout',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    AppLayoutManager.layoutToDisplayName(_currentLayout),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: (isDarkMode ? Colors.white : Colors.black)
                          .withAlpha(179),
                    ),
                  ),
                  onTap: () {
                    _showLayoutSettingsDialog(context);
                  },
                ),
              ),
            const SizedBox(height: 12),
            _buildSettingsCard(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.wallpaper,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 22,
                  ),
                ),
                title: Text(
                  'Change Wallpaper',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () => _changeWallpaper(context),
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingsCard(
              child: SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.notification_important,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 22,
                  ),
                ),
                title: Text(
                  'Notification Badges',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  _showNotificationBadges ? 'Shown' : 'Hidden',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: (isDarkMode ? Colors.white : Colors.black)
                        .withAlpha(179),
                  ),
                ),
                value: _showNotificationBadges,
                activeColor: const Color(0xFF6750A4),
                onChanged: _toggleNotificationBadges,
              ),
            ),
            const SizedBox(height: 24),
            _buildSettingsCategory("About"),
            const SizedBox(height: 8),
            _buildSettingsCard(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 22,
                  ),
                ),
                title: Text(
                  'About FuseLauncher',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  NavigationState.currentScreen = 'about';
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AboutPage()),
                  ).then((_) {
                    NavigationState.currentScreen = 'settings';
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCategory(String title) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: isDarkMode ? const Color(0xFFD0BCFF) : const Color(0xFF6750A4),
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required Widget child}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(13, 0, 0, 0), // 0.05 opacity (13/255)
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
