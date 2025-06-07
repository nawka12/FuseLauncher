import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
            'About',
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
        body: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFF6750A4),
                ),
              );
            }

            final packageInfo = snapshot.data!;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Main app info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF6750A4),
                          const Color(0xFF6750A4).withAlpha(204),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6750A4).withAlpha(51),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // App Logo
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            color: Colors.white.withAlpha(26),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(51),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.asset(
                              'assets/icon/icon.jpeg',
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // App Name
                        Text(
                          'FuseLauncher',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Tagline
                        Text(
                          'A modern Android launcher',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white.withAlpha(204),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Version info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color:
                          isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withAlpha(26),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: Color(0xFF2196F3),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Version Information',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Version ${packageInfo.version} (Build ${packageInfo.buildNumber})',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color:
                                      (isDarkMode ? Colors.white : Colors.black)
                                          .withAlpha(153),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Developer info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color:
                          isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9C27B0).withAlpha(26),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            color: Color(0xFF9C27B0),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Developer',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'KayfaHaarukku (nawka12)',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color:
                                      (isDarkMode ? Colors.white : Colors.black)
                                          .withAlpha(153),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Features card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color:
                          isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withAlpha(26),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.star_outline,
                                color: Color(0xFF4CAF50),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Key Features',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureItem(
                            'Clean and modern interface', isDarkMode),
                        _buildFeatureItem(
                            'Customizable app layout', isDarkMode),
                        _buildFeatureItem('Smart app organization', isDarkMode),
                        _buildFeatureItem('Widget support', isDarkMode),
                        _buildFeatureItem('Notification badges', isDarkMode),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String feature, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFF6750A4),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            feature,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: (isDarkMode ? Colors.white : Colors.black).withAlpha(153),
            ),
          ),
        ],
      ),
    );
  }
}
