// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print, use_key_in_widget_constructors

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:url_launcher/url_launcher.dart';

// --- PLATFORM IMPORTS ---
import 'package:flutter/foundation.dart'; // For kIsWeb and defaultTargetPlatform
import 'package:flutter/cupertino.dart'; // For Cupertino widgets

// --- PLATFORM UTILITIES ---
// This logic now checks the OS, even on the web.
bool get isIOSPlatform {
  // Checks for iOS or macOS (which iPads/Macs report in browsers)
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

// This logic now checks the OS, even on the web.
bool get isAndroidPlatform {
  // Checks for Android, Linux, or Fuchsia to default to Material style.
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}
// ------------------------

class UpcomingEventsCard extends StatelessWidget {
  final String date;
  final String eventMonth;
  final String eventTitle;
  final String eventDescription;
  final Color? highlightColor;
  final String? posterUrl;

  const UpcomingEventsCard({
    super.key,
    required this.date,
    required this.eventTitle,
    required this.eventDescription,
    required this.eventMonth,
    this.posterUrl,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Column(
      children: [
        Stack(
          children: [
            Row(
              children: [
                Card(
                  elevation: 10,
                  color: Colors.transparent,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: color.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: color.primaryColor, width: 2),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                date,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: color.primaryColor,
                                ),
                              ),
                            ),
                            Text(
                              eventMonth,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: color.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 5),

                Expanded(
                  child: Card(
                    elevation: 10,
                    color: Colors.transparent,
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        color: color.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: color.primaryColor,
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eventTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: color.primaryColor.withOpacity(0.8),
                              ),
                            ),
                            SizedBox(height: 5),
                            Expanded(
                              child: Text(
                                eventDescription,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w300,
                                  fontStyle: FontStyle.italic,
                                  color: color.primaryColor.withOpacity(0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                if (posterUrl != null)
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.primaryColor, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          posterUrl!,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 70,
                              height: 70,
                              color: Colors.grey[300],
                              // --- PLATFORM AWARE ICON ---
                              child: Icon(
                                isIOSPlatform
                                    ? CupertinoIcons.exclamationmark_circle
                                    : Icons.error,
                                color: Colors.grey,
                              ),
                              // --- END PLATFORM AWARE ICON ---
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Draw diagonal line if highlightColor is provided
            if (highlightColor != null)
              Positioned.fill(
                bottom: 40,
                top: 40,
                child: CustomPaint(
                  size: Size(2, 40),
                  painter: _DiagonalLinePainter(highlightColor!),
                  child: Text('Past'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DiagonalLinePainter extends CustomPainter {
  final Color color;
  _DiagonalLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 20.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
