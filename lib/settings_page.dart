import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'about_page.dart';
import 'navigation_state.dart';

class SettingsPage extends StatefulWidget {
  final bool isSearchBarAtTop;
  final Function(bool) onSearchBarPositionChanged;
  final Function(bool) onNotificationBadgesChanged;

  const SettingsPage({
    super.key,
    required this.isSearchBarAtTop,
    required this.onSearchBarPositionChanged,
    required this.onNotificationBadgesChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _currentPosition;
  late bool _showNotificationBadges;
  String _currentScreen = 'settings';

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.isSearchBarAtTop;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showNotificationBadges = prefs.getBool('show_notification_badges') ?? true;
    });
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
      const platform = MethodChannel('com.kayfahaarukku.flauncher/system');
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
    
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: isDarkMode 
            ? Colors.black 
            : Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(
            'Settings',
            style: TextStyle(
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
        ),
        body: ListView(
          children: [
            ListTile(
              leading: Icon(
                Icons.search, 
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              title: Text(
                'Search Bar Position',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                _currentPosition ? 'Top' : 'Bottom',
                style: TextStyle(
                  color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.7),
                ),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
                    title: Text(
                      'Search Bar Position',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile(
                          title: Text(
                            'Top',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          value: true,
                          groupValue: _currentPosition,
                          onChanged: (value) {
                            widget.onSearchBarPositionChanged(true);
                            setState(() {
                              _currentPosition = true;
                            });
                            Navigator.pop(context);
                          },
                        ),
                        RadioListTile(
                          title: Text(
                            'Bottom',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          value: false,
                          groupValue: _currentPosition,
                          onChanged: (value) {
                            widget.onSearchBarPositionChanged(false);
                            setState(() {
                              _currentPosition = false;
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.wallpaper, 
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              title: Text(
                'Change Wallpaper',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              onTap: () => _changeWallpaper(context),
            ),
            ListTile(
              leading: Icon(
                Icons.notification_important,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              title: Text(
                'Notification Badges',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                _showNotificationBadges ? 'Shown' : 'Hidden',
                style: TextStyle(
                  color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.7),
                ),
              ),
              trailing: Switch(
                value: _showNotificationBadges,
                onChanged: _toggleNotificationBadges,
              ),
            ),
            Divider(
              color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.1),
            ),
            ListTile(
              leading: Icon(
                Icons.info_outline,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              title: Text(
                'About',
                style: TextStyle(
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
          ],
        ),
      ),
    );
  }
} 