import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/folder.dart';

class FolderWidget extends StatelessWidget {
  final Folder folder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const FolderWidget({
    super.key,
    required this.folder,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appCount = folder.apps.length;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container with simple background
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(26),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.folder_rounded,
              size: 32,
              color: Colors.amber,
            ),
          ),

          const SizedBox(height: 12),

          // Folder name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              folder.name,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 4),

          // App count badge
          if (appCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6750A4).withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$appCount app${appCount != 1 ? 's' : ''}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6750A4),
                ),
              ),
            )
          else
            Text(
              'Empty',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color:
                    (isDarkMode ? Colors.white : Colors.black).withAlpha(128),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
