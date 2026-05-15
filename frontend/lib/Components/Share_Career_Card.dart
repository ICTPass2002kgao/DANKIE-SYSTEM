// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/API.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Components/card_generator.dart';

class CareerShareSheet extends StatefulWidget {
  final String title;
  final String category;
  final String expiryDate;
  final String docId; 
  final ThemeData theme;

  const CareerShareSheet({
    Key? key,
    required this.title,
    required this.category,
    required this.expiryDate,
    required this.docId,
    required this.theme,
  }) : super(key: key);

  @override
  State<CareerShareSheet> createState() => _CareerShareSheetState();
}

class _CareerShareSheetState extends State<CareerShareSheet> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isGenerating = false;
  final String _appDomain = "https://tact-3c612.web.app";

  Future<void> _generateAndShare() async {
    setState(() => _isGenerating = true);

    try {
      final directory = (await getApplicationDocumentsDirectory()).path;
      String fileName = 'dankie_career_${DateTime.now().millisecondsSinceEpoch}.png';
      String path = '$directory/$fileName';

      // Capture Image
      final imageBytes = await _screenshotController.captureFromWidget(
        CareerShareCardGenerator(
          title: widget.title,
          category: widget.category,
          expiryDate: widget.expiryDate,
        ),
        delay: const Duration(milliseconds: 20),
        pixelRatio: 3.0,
      );

      File(path).writeAsBytesSync(imageBytes);

      String deepLink = "$_appDomain/career?title=${Uri.encodeComponent(widget.title)}";
      String message = "🚀 New Opportunity: ${widget.title.toUpperCase()}\n📅 Closing: ${widget.expiryDate}\n\nTap to apply in DANKIE:\n$deepLink";

      await Share.shareXFiles([XFile(path)], text: message);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Share Error: $e");
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _copyLink() {
    String deepLink = "$_appDomain/career?id=${widget.docId}&title=${Uri.encodeComponent(widget.title)}";
    Clipboard.setData(ClipboardData(text: deepLink));
    Api().showMessage(context, "Link Copied!", "Successful", Colors.green);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // ⭐️ CALCULATE TINT
    final Color neumoBaseColor = Color.alphaBlend(
      widget.theme.primaryColor.withOpacity(0.08),
      widget.theme.scaffoldBackgroundColor,
    );

    return Container(
      decoration: BoxDecoration(
        color: neumoBaseColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          NeumorphicContainer(
            color: neumoBaseColor,
            isPressed: true, // Sunken
            borderRadius: 10,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: SizedBox(height: 4, width: 40), // Invisible spacer to give size
          ),
          
          const SizedBox(height: 25),
          
          Text(
            "Share Opportunity",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: widget.theme.primaryColor,
            ),
          ),
          const SizedBox(height: 30),

          if (_isGenerating)
            Center(child: CircularProgressIndicator(color: widget.theme.primaryColor))
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNeuShareBtn(
                  icon: Icons.share,
                  label: "Share",
                  color: Colors.white,
                  bgColor: widget.theme.primaryColor, // Colored Button
                  onTap: _generateAndShare,
                  baseColor: neumoBaseColor,
                ),
                _buildNeuShareBtn(
                  icon: Icons.link,
                  label: "Copy Link",
                  color: widget.theme.primaryColor,
                  bgColor: neumoBaseColor, // Base Color Button
                  onTap: _copyLink,
                  baseColor: neumoBaseColor,
                ),
              ],
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildNeuShareBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    required Color baseColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NeumorphicContainer(
            color: bgColor,
             
            isPressed: false, // Convex Pop-out
            padding: EdgeInsets.all(20),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.bold,
              color: widget.theme.hintColor
            ),
          ),
        ],
      ),
    );
  }
}
