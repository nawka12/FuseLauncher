import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(
            'About',
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
        body: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final packageInfo = snapshot.data!;

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: isDarkMode 
                            ? const Color.fromARGB(13, 255, 255, 255) // 0.05 opacity (13/255)
                            : const Color.fromARGB(13, 0, 0, 0), // 0.05 opacity (13/255)
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(26, 0, 0, 0), // 0.1 opacity (26/255)
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/icon/icon.jpeg',
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // App Name
                    Text(
                      'FLauncher',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Version and Build Number
                    Text(
                      'Version ${packageInfo.version}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode 
                            ? const Color.fromARGB(179, 255, 255, 255) // 0.7 opacity (179/255)
                            : const Color.fromARGB(179, 0, 0, 0), // 0.7 opacity (179/255)
                      ),
                    ),
                    Text(
                      'Build ${packageInfo.buildNumber}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDarkMode 
                            ? const Color.fromARGB(128, 255, 255, 255) // 0.5 opacity (128/255)
                            : const Color.fromARGB(128, 0, 0, 0), // 0.5 opacity (128/255)
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Divider
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDarkMode 
                            ? const Color.fromARGB(77, 103, 80, 164) // 0.3 opacity (77/255)
                            : const Color.fromARGB(51, 103, 80, 164), // 0.2 opacity (51/255)
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Creator Info
                    Text(
                      'Created by',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDarkMode 
                            ? const Color.fromARGB(153, 255, 255, 255) // 0.6 opacity (153/255)
                            : const Color.fromARGB(153, 0, 0, 0), // 0.6 opacity (153/255)
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'KayfaHaarukku (nawka12)',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 