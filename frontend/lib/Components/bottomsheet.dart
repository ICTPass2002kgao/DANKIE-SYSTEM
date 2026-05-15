// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/API.dart';
import 'package:url_launcher/url_launcher.dart';

// --- SHARING IMPORTS ---
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// --- PLATFORM IMPORTS ---
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

bool get isAndroidPlatform {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}

void _showPlatformMessage(
  BuildContext context,
  String title,
  String message,
  Color backgroundColor,
) {
  if (isIOSPlatform) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text('OK'),
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title: $message'),
        backgroundColor: backgroundColor,
      ),
    );
  }
}

// ==========================================
// 1. NEUMORPHIC EVENT DETAIL SHEET
// ==========================================
class EventDetailBottomSheet extends StatelessWidget {
  final String date;
  final String eventMonth;
  final String title;
  final String description;
  final String? posterUrl;

  const EventDetailBottomSheet({
    Key? key,
    required this.date,
    required this.eventMonth,
    required this.title,
    required this.description,
    this.posterUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // ⭐️ CALCULATE NEUMORPHIC TINT
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Container(
      color: neumoBaseColor, // Matches the parent page background
      child: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: neumoBaseColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            // Soft top shadow to separate sheet from background
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ⭐️ 1. DRAG HANDLE (PRESSED IN)
              Center(
                child: NeumorphicContainer(
                  color: neumoBaseColor,
                  isPressed: true, // "Dent" look
                  borderRadius: 10, 
                  padding: EdgeInsets.zero,
                  child: SizedBox(),
                ),
              ),
              SizedBox(height: 25),

              // ⭐️ 2. POSTER IMAGE (FRAMED)
              if (posterUrl != null)
                NeumorphicContainer(
                  color: neumoBaseColor,
                  isPressed: false,
                  borderRadius: 20,
                  padding: EdgeInsets.all(8), // The "Frame"
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15.0),
                    child: Image.network(
                      posterUrl!,
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          height: 200,
                          child: Center(child: Icon(Icons.error, color: Colors.grey)),
                        );
                      },
                    ),
                  ),
                ),
              SizedBox(height: 25),

              // ⭐️ 3. TITLE & SHARE BUTTON
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: theme.primaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              color: theme.hintColor,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "$eventMonth $date",
                              style: TextStyle(
                                color: theme.hintColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 15),
                  
                  // Share Button (Neumorphic Circle)
                  GestureDetector(
                    onTap: () => _openShareSheet(context, neumoBaseColor),
                    child: NeumorphicContainer(
                      color: neumoBaseColor,
                      borderRadius: 50,
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        isIOSPlatform ? CupertinoIcons.share : Icons.share,
                        color: theme.primaryColor,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 20),
              Divider(color: theme.hintColor.withOpacity(0.1)),
              SizedBox(height: 15),

              Text(
                description,
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 30),

              // ⭐️ 4. JOIN BUTTON (LARGE NEUMORPHIC)
              GestureDetector(
                onTap: () async {
                  final url = Uri.parse('');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.inAppBrowserView);
                  } else {
                    _showPlatformMessage(
                      context,
                      "Coming Soon",
                      'Not live yet. Counting down!',
                      Colors.orange,
                    );
                  }
                },
                child: NeumorphicContainer(
                  color: theme.primaryColor, // Accent Color
                  borderRadius: 20,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      'JOIN LIVE EVENT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _openShareSheet(BuildContext context, Color baseColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Important for Neumorphic shape
      isScrollControlled: true,
      builder: (context) => EventShareSheet(
        title: title,
        dateString: "$eventMonth $date",
        posterUrl: posterUrl,
        theme: Theme.of(context),
        neumoBaseColor: baseColor,
      ),
    );
  }
}

// ==========================================
// 2. NEUMORPHIC SHARE SHEET
// ==========================================
class EventShareSheet extends StatefulWidget {
  final String title;
  final String dateString;
  final String? posterUrl;
  final ThemeData theme;
  final Color neumoBaseColor;

  const EventShareSheet({
    Key? key,
    required this.title,
    required this.dateString,
    required this.posterUrl,
    required this.theme,
    required this.neumoBaseColor,
  }) : super(key: key);

  @override
  State<EventShareSheet> createState() => _EventShareSheetState();
}

class _EventShareSheetState extends State<EventShareSheet> {
  bool _isGenerating = false;
  final String _appDomain = "https://tact-3c612.web.app";
  late final ScreenshotController _screenshotController;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _screenshotController = ScreenshotController();
    }
  }

  Future<void> _generateAndShare(bool isStatus) async {
    setState(() => _isGenerating = true);
    String appLink = "$_appDomain/event?title=${Uri.encodeComponent(widget.title)}&date=${Uri.encodeComponent(widget.dateString)}";
    String message = "📅 ${widget.title} - ${widget.dateString}\n\nTap to view event in TTACT:\n$appLink";

    try {
      if (kIsWeb) {
        await Share.share(message);
      } else {
        final directory = (await getApplicationDocumentsDirectory()).path;
        String fileName = 'ttact_event_${DateTime.now().millisecondsSinceEpoch}.png';
        String path = '$directory/$fileName';

        final imageBytes = await _screenshotController.captureFromWidget(
          EventShareCardGenerator(
            title: widget.title,
            dateString: widget.dateString,
            posterUrl: widget.posterUrl,
          ),
          delay: const Duration(milliseconds: 150),
          pixelRatio: 2.0,
        );

        File imgFile = File(path);
        await imgFile.writeAsBytes(imageBytes);

        final xFile = XFile(path);
        await Share.shareXFiles([xFile], text: message);
      }
    } catch (e) {
      debugPrint("Error sharing event: $e");
      if (kIsWeb) _copyLink();
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        Navigator.pop(context);
      }
    }
  }

  void _copyLink() {
    String appLink = "$_appDomain/event?title=${Uri.encodeComponent(widget.title)}";
    Clipboard.setData(ClipboardData(text: appLink));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(kIsWeb ? "Link copied!" : "Link Copied!"),
      backgroundColor: Colors.green,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.neumoBaseColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.all(25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          NeumorphicContainer(
            color: widget.neumoBaseColor,
            isPressed: true,
            borderRadius: 10,
             
            padding: EdgeInsets.zero,
            child: SizedBox(),
          ),
          SizedBox(height: 20),
          
          Text(
            "Share Event",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: widget.theme.primaryColor,
            ),
          ),
          SizedBox(height: 30),

          if (_isGenerating)
            Column(
              children: [
                CircularProgressIndicator(color: widget.theme.primaryColor),
                SizedBox(height: 15),
                Text("Creating poster...", style: TextStyle(color: widget.theme.hintColor)),
              ],
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!kIsWeb) ...[
                    _buildNeuShareBtn(
                      icon: FontAwesomeIcons.whatsapp,
                      color: Colors.white,
                      bg: Color(0xFF25D366),
                      label: "Status",
                      onTap: () => _generateAndShare(true),
                    ),
                    SizedBox(width: 25),
                    _buildNeuShareBtn(
                      icon: FontAwesomeIcons.whatsapp,
                      color: Colors.white,
                      bg: Color(0xFF25D366),
                      label: "WhatsApp",
                      onTap: () => _generateAndShare(false),
                    ),
                    SizedBox(width: 25),
                  ],
                  _buildNeuShareBtn(
                    icon: Icons.link,
                    color: Colors.white,
                    bg: Colors.blueAccent,
                    label: "Link",
                    onTap: _copyLink,
                  ),
                  SizedBox(width: 25),
                  _buildNeuShareBtn(
                    icon: Icons.share,
                    color: widget.theme.primaryColor,
                    bg: widget.neumoBaseColor, // Outline style
                    label: "More",
                    onTap: () => _generateAndShare(false),
                    isOutline: true,
                  ),
                ],
              ),
            ),
          
          SizedBox(height: 30),
          
          // Cancel Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: NeumorphicContainer(
              color: widget.neumoBaseColor,
              isPressed: false,
              borderRadius: 15,
              padding: EdgeInsets.symmetric(vertical: 15, horizontal: 40),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildNeuShareBtn({
    required IconData icon,
    required Color color,
    required Color bg,
    required String label,
    required VoidCallback onTap,
    bool isOutline = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          NeumorphicContainer(
            color: isOutline ? bg : widget.neumoBaseColor,
            isPressed: false,
            borderRadius: 50,
            padding: EdgeInsets.all(4), // Ring effect
            child: Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: isOutline ? bg : bg,
                shape: BoxShape.circle,
                gradient: isOutline ? null : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bg, bg.withOpacity(0.8)],
                ),
              ),
              child: Center(
                child: Icon(icon, color: color, size: 24),
              ),
            ),
          ),
          SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: widget.theme.hintColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. EVENT CARD GENERATOR (Visuals)
// ==========================================
// Kept mostly standard as this generates an IMAGE file, 
// so Neumorphism (shadows) won't render perfectly on all backgrounds.
// Adjusted typography for a premium look.
class EventShareCardGenerator extends StatelessWidget {
  final String title;
  final String dateString;
  final String? posterUrl;

  const EventShareCardGenerator({
    Key? key,
    required this.title,
    required this.dateString,
    this.posterUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080 / 3,
      height: 1920 / 3,
      decoration: posterUrl != null
          ? BoxDecoration(
              color: Colors.black,
              image: DecorationImage(
                image: NetworkImage(posterUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.6), // Darker overlay for text pop
                  BlendMode.darken
                ),
              ),
            )
          : BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1a2a6c), Color(0xFFb21f1f), Color(0xFFfdbb2d)],
              ),
            ),
      child: Stack(
        children: [
          // Glass-morphic Border
          Container(
            margin: EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0,5))],
                ),
                child: Text(
                  "UPCOMING EVENT",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                ),
              ),
              SizedBox(height: 40),

              if (posterUrl == null)
                Center(
                  child: Icon(Icons.event_available_rounded, color: Colors.white.withOpacity(0.8), size: 80),
                ),
              
              SizedBox(height: 20),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Text(
                  title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 20, offset: Offset(0, 5))
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Date
              Container(
                padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      dateString,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 80),

              // App Action
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_rounded, color: Colors.white70, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Open TTACT for details",
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, letterSpacing: 1),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}