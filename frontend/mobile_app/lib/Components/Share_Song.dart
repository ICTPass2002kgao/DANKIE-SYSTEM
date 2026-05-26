// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, depend_on_referenced_packages

import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_full/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:screenshot/screenshot.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Share_Card_Generator.dart';
import 'package:ttact/main.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

// --- PLATFORM UTILITIES ---
bool get isMobileNative =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class TikTokShareSheet extends StatefulWidget {
  final String songName;
  final String artistName;
  final String songUrl;
  final ThemeData theme;

  const TikTokShareSheet({
    Key? key,
    required this.songName,
    required this.artistName,
    required this.songUrl,
    required this.theme,
  }) : super(key: key);

  @override
  State<TikTokShareSheet> createState() => _TikTokShareSheetState();
}

class _TikTokShareSheetState extends State<TikTokShareSheet> {
  double _clipDurationSeconds = 15.0;
  bool _isGenerating = false;
  final String _appDomain = "https://tact-3c612.web.app";
  late final ScreenshotController _screenshotController;

  @override
  void initState() {
    super.initState();
    _screenshotController = ScreenshotController();
  }

  double _getLiveStartSeconds() {
    if (audioHandler != null) {
      final currentPosMs = audioHandler!.playbackState.value.position.inMilliseconds;
      final currentPosSec = currentPosMs / 1000.0;
      final totalDuration = audioHandler!.mediaItem.value?.duration?.inSeconds ?? 300;
      if (currentPosSec > totalDuration - 5) return 0.0;
      return currentPosSec;
    }
    return 0.0;
  }

  Future<void> _generateAndShareVideoClip() async {
    final startSeconds = _getLiveStartSeconds();

    if (kIsWeb) return _generateAndShareStatic(false);

    setState(() => _isGenerating = true);
    Api().showLoading(context);

    final directory = await getTemporaryDirectory();
    final duration = _clipDurationSeconds.toInt();
    final now = DateTime.now().millisecondsSinceEpoch;
    final tempDir = "${directory.path}/ffmpeg_share_$now";
    await Directory(tempDir).create(recursive: true);

    final String tempVisualPath = '$tempDir/visual_loop.mp4';
    final String tempAudioClipPath = '$tempDir/audio_clip.aac';
    final String finalVideoPath = '$tempDir/final_clip_$now.mp4';

    String appLink = "$_appDomain/song?url=${Uri.encodeComponent(widget.songUrl)}&song=${Uri.encodeComponent(widget.songName)}&artist=${Uri.encodeComponent(widget.artistName)}";
    String message = "🎵 ${widget.songName} - ${widget.artistName}\n\nTap to listen in DANKIE:\n$appLink";

    try {
      File sourceFile = await DefaultCacheManager().getSingleFile(widget.songUrl);
      String sourceFilePath = sourceFile.path;

      final imageBytes = await _screenshotController.captureFromWidget(
        ShareCardGenerator(
          songName: widget.songName,
          artistName: widget.artistName,
          appLogoPath: "assets/dankie_logo.PNG",
        ),
        delay: const Duration(milliseconds: 50),
      );
      final String tempPngPath = '$tempDir/frame.png';
      await File(tempPngPath).writeAsBytes(imageBytes);

      String audioCmd = "-y -ss $startSeconds -t $duration -i \"$sourceFilePath\" -c:a aac -b:a 128k \"$tempAudioClipPath\"";
      Session audioSession = await FFmpegKit.execute(audioCmd);
      if (!ReturnCode.isSuccess(await audioSession.getReturnCode())) throw Exception("Audio Cut Failed");

      String visualCmd = "-y -loop 1 -i \"$tempPngPath\" -i \"$tempAudioClipPath\" -filter_complex \"[0:v]scale=trunc(iw/2)*2:trunc(ih/2)*2[bg];[1:a]showwaves=s=600x120:mode=line:colors=white[waves];[bg][waves]overlay=(W-w)/2:H-h-455:shortest=1[video_out]\" -map \"[video_out]\" -t $duration -c:v mpeg4 -q:v 3 -pix_fmt yuv420p -r 24 \"$tempVisualPath\"";
      Session visualSession = await FFmpegKit.execute(visualCmd);
      if (!ReturnCode.isSuccess(await visualSession.getReturnCode())) throw Exception("Visual Gen Failed");

      String muxCmd = "-y -i \"$tempVisualPath\" -i \"$tempAudioClipPath\" -c:v copy -c:a aac -shortest \"$finalVideoPath\"";
      Session muxSession = await FFmpegKit.execute(muxCmd);
      if (!ReturnCode.isSuccess(await muxSession.getReturnCode())) throw Exception("Muxing Failed");

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      Navigator.pop(context);

      final xFile = XFile(finalVideoPath);
      await Share.shareXFiles([xFile], text: message);
    } catch (e) {
      debugPrint("⛔️ VIDEO ERROR: $e");
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Video generation failed: $e"), duration: const Duration(seconds: 4), backgroundColor: Colors.red));
      try { Navigator.pop(context); } catch (_) {}
      await Share.share(message);
    } finally {
      try { await Directory(tempDir).delete(recursive: true); } catch (_) {}
      if (mounted) {
        setState(() => _isGenerating = false);
        if (_isGenerating) Navigator.pop(context);
      }
    }
  }

  Future<void> _generateAndShareStatic(bool isStatus) async {
    setState(() => _isGenerating = true);
    try {
      final appLink = "$_appDomain/music?url=${Uri.encodeComponent(widget.songUrl)}";
      final message = "🎵 ${widget.songName} - ${widget.artistName}\n\nListen here: $appLink";

      if (kIsWeb) {
        await Share.share(message);
      } else {
        final directory = (await getApplicationDocumentsDirectory()).path;
        String path = '$directory/ttact_share.png';
        final imageBytes = await _screenshotController.captureFromWidget(
          ShareCardGenerator(songName: widget.songName, artistName: widget.artistName, appLogoPath: "assets/dankie_logo.PNG"),
          delay: const Duration(milliseconds: 10),
        );
        File(path).writeAsBytesSync(imageBytes); 
        await Share.shareXFiles([XFile(path)], text: message);
      }
    } catch (e) {
      debugPrint("Static Share Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        Navigator.pop(context);
      }
    }
  }

  void _copyDeepLink() {
    String appLink = "$_appDomain/music?url=${Uri.encodeComponent(widget.songUrl)}";
    Clipboard.setData(ClipboardData(text: appLink));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(kIsWeb ? "Link copied!" : "App Link Copied!"), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final Color neumoBaseColor = Color.alphaBlend(
      widget.theme.primaryColor.withOpacity(0.08),
      widget.theme.scaffoldBackgroundColor,
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: neumoBaseColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [ 
          Center(
            child: NeumorphicContainer(
              color: neumoBaseColor,
              isPressed: true, 
              borderRadius: 10,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: SizedBox(height: 4, width: 40),
            ),
          ), 
          const SizedBox(height: 25), 
          Text(
            "Share to",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: widget.theme.primaryColor,
            ),
          ),
          const SizedBox(height: 20), 
          if (!kIsWeb) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Clip Duration", style: TextStyle(fontWeight: FontWeight.bold, color: widget.theme.hintColor)),
                NeumorphicContainer(
                  color: neumoBaseColor,
                  isPressed: true,  
                  borderRadius: 8,
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text("${_clipDurationSeconds.toInt()}s", style: TextStyle(fontWeight: FontWeight.bold, color: widget.theme.primaryColor)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: widget.theme.primaryColor,
                inactiveTrackColor: widget.theme.primaryColor.withOpacity(0.2),
                thumbColor: widget.theme.primaryColor,
                overlayColor: widget.theme.primaryColor.withOpacity(0.1),
              ),
              child: Slider(
                min: 5.0,
                max: 60.0,
                divisions: 11,
                value: _clipDurationSeconds,
                onChanged: (value) {
                  setState(() {
                    _clipDurationSeconds = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // SHARE ICONS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (!kIsWeb) ...[
                  _buildNeuShareBtn(
                    icon: FontAwesomeIcons.whatsapp,
                    color: Colors.white,
                    bgColor: const Color(0xFF25D366),
                    label: "Video Status",
                    onTap: _isGenerating ? () {} : _generateAndShareVideoClip,
                    baseColor: neumoBaseColor,
                  ),
                  const SizedBox(width: 25),

                  _buildNeuShareBtn(
                    icon: FontAwesomeIcons.whatsapp,
                    color: Colors.white,
                    bgColor: const Color(0xFF25D366),
                    label: "WhatsApp Chat",
                    onTap: _isGenerating ? () {} : _generateAndShareVideoClip,
                    baseColor: neumoBaseColor,
                  ),
                  const SizedBox(width: 25),
                ],

                _buildNeuShareBtn(
                  icon: Icons.link,
                  color: widget.theme.primaryColor,
                  bgColor: neumoBaseColor, // Base color button
                  label: "Copy Link",
                  onTap: _copyDeepLink,
                  baseColor: neumoBaseColor,
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildNeuShareBtn({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String label,
    required VoidCallback onTap,
    required Color baseColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
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
              fontSize: 12, 
              color: widget.theme.hintColor,
              fontWeight: FontWeight.w600
            ),
          ),
        ],
      ),
    );
  }
}