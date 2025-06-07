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
        backgroundColor: isDarkMode
            ? const Color(0xFF000000).withAlpha(128)
            : const Color(0xFFFFFFFF).withAlpha(128),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(
            'Settings',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDarkMode ? Colors.white : Colors.black).withAlpha(13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: isDarkMode ? Colors.white : Colors.black,
                size: 18,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          elevation: 0,
          centerTitle: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header section with app info
            Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF6750A4),
                    const Color(0xFF6750A4).withAlpha(204),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6750A4).withAlpha(51),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FuseLauncher',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Customize your experience',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withAlpha(204),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _buildSettingsCategory("Interface", Icons.palette),
            const SizedBox(height: 16),

            _buildSettingsCard(
              icon: Icons.search,
              iconColor: const Color(0xFF2196F3),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Text(
                  'Search Bar Position',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  _currentPosition ? 'Top of screen' : 'Bottom of screen',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: (isDarkMode ? Colors.white : Colors.black)
                        .withAlpha(153),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color:
                      (isDarkMode ? Colors.white : Colors.black).withAlpha(128),
                ),
                onTap: () => _showSearchBarPositionSheet(context),
              ),
            ),

            const SizedBox(height: 16),

            if (_layoutInitialized)
              _buildSettingsCard(
                icon: AppLayoutManager.getLayoutIcon(_currentLayout),
                iconColor: const Color(0xFF9C27B0),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: Text(
                    'App Layout',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    '${AppLayoutManager.layoutToDisplayName(_currentLayout)}${_currentLayout == AppLayoutType.grid ? ' • $_gridColumns columns' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: (isDarkMode ? Colors.white : Colors.black)
                          .withAlpha(153),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: (isDarkMode ? Colors.white : Colors.black)
                        .withAlpha(128),
                  ),
                  onTap: () => _showLayoutSettingsSheet(context),
                ),
              ),

            const SizedBox(height: 16),

            _buildSettingsCard(
              icon: Icons.notifications_active,
              iconColor: const Color(0xFFFF5722),
              child: SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Text(
                  'Notification Badges',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  _showNotificationBadges
                      ? 'Show app notification counts'
                      : 'Hide app notification counts',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: (isDarkMode ? Colors.white : Colors.black)
                        .withAlpha(153),
                  ),
                ),
                value: _showNotificationBadges,
                activeColor: const Color(0xFF6750A4),
                onChanged: _toggleNotificationBadges,
              ),
            ),

            const SizedBox(height: 32),

            _buildSettingsCategory("System", Icons.phone_android),
            const SizedBox(height: 16),

            _buildSettingsCard(
              icon: Icons.wallpaper,
              iconColor: const Color(0xFF4CAF50),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Text(
                  'Change Wallpaper',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  'Set a new wallpaper for your device',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: (isDarkMode ? Colors.white : Colors.black)
                        .withAlpha(153),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color:
                      (isDarkMode ? Colors.white : Colors.black).withAlpha(128),
                ),
                onTap: () => _changeWallpaper(context),
              ),
            ),

            const SizedBox(height: 32),

            _buildSettingsCategory("About", Icons.info),
            const SizedBox(height: 16),

            _buildSettingsCard(
              icon: Icons.info_outline,
              iconColor: const Color(0xFF607D8B),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Text(
                  'About FuseLauncher',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  'Version info and developer details',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: (isDarkMode ? Colors.white : Colors.black)
                        .withAlpha(153),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color:
                      (isDarkMode ? Colors.white : Colors.black).withAlpha(128),
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

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCategory(String title, IconData categoryIcon) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isDarkMode
                      ? const Color(0xFFD0BCFF)
                      : const Color(0xFF6750A4))
                  .withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              categoryIcon,
              size: 16,
              color: isDarkMode
                  ? const Color(0xFFD0BCFF)
                  : const Color(0xFF6750A4),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: isDarkMode
                  ? const Color(0xFFD0BCFF)
                  : const Color(0xFF6750A4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
      {required Widget child,
      required IconData icon,
      required Color iconColor}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withAlpha(51)
                : const Color.fromARGB(13, 0, 0, 0),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(26),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  void _showSearchBarPositionSheet(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor:
          isDarkMode ? const Color(0xFF252525) : Colors.white.withAlpha(242),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom + 16.0,
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
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Search Bar Position',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              RadioListTile(
                title: Text(
                  'Top',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  'Search bar appears at the top',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: (isDarkMode ? Colors.white : Colors.black)
                        .withAlpha(153),
                  ),
                ),
                value: true,
                groupValue: _currentPosition,
                activeColor: const Color(0xFF6750A4),
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
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  'Search bar appears at the bottom',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: (isDarkMode ? Colors.white : Colors.black)
                        .withAlpha(153),
                  ),
                ),
                value: false,
                groupValue: _currentPosition,
                activeColor: const Color(0xFF6750A4),
                onChanged: (value) {
                  setState(() {
                    _currentPosition = false;
                  });
                  widget.onSearchBarPositionChanged(false);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showLayoutSettingsSheet(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor:
          isDarkMode ? const Color(0xFF252525) : Colors.white.withAlpha(242),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewPadding.bottom + 16.0,
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
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'App Layout',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  RadioListTile<AppLayoutType>(
                    title: Text(
                      'List View',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      'Apps displayed in a vertical list',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: (isDarkMode ? Colors.white : Colors.black)
                            .withAlpha(153),
                      ),
                    ),
                    value: AppLayoutType.list,
                    groupValue: _currentLayout,
                    activeColor: const Color(0xFF6750A4),
                    onChanged: (value) async {
                      await AppLayoutManager.saveLayoutPreference(
                          AppLayoutType.list);
                      setSheetState(() {
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
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      'Apps displayed in a grid layout',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: (isDarkMode ? Colors.white : Colors.black)
                            .withAlpha(153),
                      ),
                    ),
                    value: AppLayoutType.grid,
                    groupValue: _currentLayout,
                    activeColor: const Color(0xFF6750A4),
                    onChanged: (value) async {
                      await AppLayoutManager.saveLayoutPreference(
                          AppLayoutType.grid);
                      setSheetState(() {
                        _currentLayout = AppLayoutType.grid;
                      });
                      setState(() {
                        _currentLayout = AppLayoutType.grid;
                      });
                      widget.onLayoutChanged();
                    },
                  ),
                  if (_currentLayout == AppLayoutType.grid) ...[
                    const Divider(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Grid Columns',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6750A4).withAlpha(26),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _gridColumns.toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6750A4),
                              ),
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
                        setSheetState(() {
                          _gridColumns = newColumns;
                        });
                        setState(() {
                          _gridColumns = newColumns;
                        });
                        widget.onLayoutChanged();
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
