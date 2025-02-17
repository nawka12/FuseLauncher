import 'package:installed_apps/app_info.dart';
import 'sort_options.dart';

class AppSection {
  final String letter;
  final List<AppInfo> apps;

  AppSection(this.letter, this.apps);
}

class AppSectionManager {
  static List<AppSection> createSections(List<AppInfo> apps, {AppListSortType sortType = AppListSortType.alphabeticalAsc}) {
    // Sort apps according to the specified sort type
    final sortedApps = List<AppInfo>.from(apps);
    
    if (sortType == AppListSortType.usage) {
      // For usage sort, return a single section with all apps
      return [AppSection('', sortedApps)];
    }
    
    // For alphabetical sorts, continue with the existing logic
    switch (sortType) {
      case AppListSortType.alphabeticalAsc:
        sortedApps.sort((a, b) => 
          (a.name).toLowerCase().compareTo((b.name).toLowerCase())
        );
      case AppListSortType.alphabeticalDesc:
        sortedApps.sort((a, b) => 
          (b.name).toLowerCase().compareTo((a.name).toLowerCase())
        );
      case AppListSortType.usage:
        // Already handled above
        break;
    }

    // Group apps by first letter
    final sections = <AppSection>[];
    String? currentLetter;
    List<AppInfo> currentApps = [];

    for (var app in sortedApps) {
      final firstLetter = (app.name).isNotEmpty
          ? (app.name)[0].toUpperCase()
          : '#';

      if (currentLetter != firstLetter) {
        if (currentLetter != null) {
          sections.add(AppSection(currentLetter, List.from(currentApps)));
        }
        currentLetter = firstLetter;
        currentApps.clear();
      }
      currentApps.add(app);
    }

    // Add the last section
    if (currentLetter != null && currentApps.isNotEmpty) {
      sections.add(AppSection(currentLetter, List.from(currentApps)));
    }

    return sections;
  }
} 