// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ttact/Components/MusicPlayerSheet.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/home/Tabs/music_tab.dart';
import 'package:ttact/main.dart'; // To access audioHandler
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/home/home_page.dart'; // ⭐️ IMPORT THIS to access MusicPlayerSheet

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class DownloadedSongs extends StatefulWidget {
  const DownloadedSongs({super.key});

  @override
  State<DownloadedSongs> createState() => _DownloadedSongsState();
}

class _DownloadedSongsState extends State<DownloadedSongs> {
  List<FileSystemEntity> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloadedSongs();
  }

  /// Scans the Application Documents Directory for .mp3 files
  Future<void> _loadDownloadedSongs() async {
    try {
      final dir = await getApplicationDocumentsDirectory();

      // Filter for files ending in .mp3
      final List<FileSystemEntity> files = dir.listSync().where((entity) {
        return entity.path.endsWith(".mp3");
      }).toList();

      if (mounted) {
        setState(() {
          _files = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading local songs: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Deletes a file locally
  Future<void> _deleteSong(FileSystemEntity file) async {
    try {
      await file.delete();
      await _loadDownloadedSongs(); // Refresh list
    } catch (e) {
      debugPrint("Error deleting file: $e");
    }
  }

  /// Builds the full playlist and opens the Player Sheet
  Future<void> _playLocalSong(int index) async {
    try {
      List<MediaItem> playlist = _files.map((file) {
        final path = file.path;
        String filename = path.split('/').last.replaceAll('.mp3', '');
        String title = "Unknown Title";
        String artist = "Unknown Artist";

        if (filename.contains('_')) {
          final parts = filename.split('_');
          title = parts[0];
          if (parts.length > 1) artist = parts[1];
        } else {
          title = filename;
        }

        return MediaItem(
          id: path, 
          title: title,
          artist: artist,
          album: 'Downloaded Songs',
          artUri: Uri.parse("asset:///assets/dankie_logo.PNG"),
        );
      }).toList();

      await audioHandler?.loadPlaylist(playlist, index);

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true, 
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (context) => MusicPlayerSheet(
            themeColor: Theme.of(context), 
            onDownload: (String url, String title, String artist) {},
          ),
        );
      }
    } catch (e) {
      debugPrint("Error playing local file: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;

    // TINT CALCULATION FOR PREMIUM NEUMORPHIC LOOK
    final Color neumoBaseColor = Color.alphaBlend(
      color.primaryColor.withOpacity(0.08),
      color.scaffoldBackgroundColor,
    );

    return Scaffold(
      backgroundColor: neumoBaseColor,
      appBar: isIOSPlatform
          ? CupertinoNavigationBar(
              middle: Text(
                'Downloaded Songs',
                style: TextStyle(color: color.primaryColor, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.transparent,
              border: null,
              leading: CupertinoNavigationBarBackButton(
                color: color.primaryColor,
                onPressed: () => Navigator.pop(context),
              ),
            )
          : AppBar(
              title: const Text(
                'Downloaded Songs',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              foregroundColor: color.primaryColor,
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
            ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: isIOSPlatform
                    ? CupertinoActivityIndicator()
                    : CircularProgressIndicator(color: color.primaryColor),
              )
            : _files.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    NeumorphicContainer(
                      color: neumoBaseColor,
                      isPressed: true,
                      borderRadius: 40,
                      padding: EdgeInsets.all(30),
                      child: Icon(
                        Ionicons.cloud_offline_outline,
                        size: 60,
                        color: color.hintColor,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "No downloaded songs",
                      style: TextStyle(color: color.hintColor, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 800 : double.infinity),
                  child: ListView.builder(
                    itemCount: _files.length,
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                    physics: BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      final path = file.path;
                      final filename = path.split('/').last.replaceAll('.mp3', '');

                      String displayTitle = filename;
                      String displayArtist = "Offline Music";

                      if (filename.contains('_')) {
                        final parts = filename.split('_');
                        displayTitle = parts[0];
                        if (parts.length > 1) displayArtist = parts[1];
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15.0),
                        child: NeumorphicContainer(
                          color: neumoBaseColor,
                          isPressed: false,
                          borderRadius: 15,
                          padding: EdgeInsets.zero,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: color.primaryColor, width: 1.0),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 20 : 12,
                                vertical: isDesktop ? 10 : 5,
                              ),
                              leading: NeumorphicContainer(
                                color: neumoBaseColor,
                                borderRadius: 10,
                                padding: EdgeInsets.all(isDesktop ? 5 : 2),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    "assets/dankie_logo.PNG",
                                    width: isDesktop ? 60 : 40,
                                    height: isDesktop ? 60 : 40,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              title: Text(
                                displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isDesktop ? 16 : 14,
                                  color: color.primaryColor,
                                ),
                              ),
                              subtitle: Text(
                                displayArtist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: color.hintColor, fontSize: isDesktop ? 13 : 11),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  isIOSPlatform
                                      ? CupertinoIcons.trash
                                      : Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: isDesktop ? 28 : 24,
                                ),
                                onPressed: () => _deleteSong(file),
                              ),
                              onTap: () => _playLocalSong(index),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}