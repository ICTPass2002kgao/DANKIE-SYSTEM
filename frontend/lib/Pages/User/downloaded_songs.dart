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

  /// ⭐️ UPDATED: Builds the full playlist and opens the Player Sheet
  Future<void> _playLocalSong(int index) async {
    try {
      // 1. Convert ALL files to MediaItems to form a Queue/Playlist
      // This ensures "Next" and "Previous" buttons work correctly
      List<MediaItem> playlist = _files.map((file) {
        final path = file.path;
        String filename = path.split('/').last.replaceAll('.mp3', '');
        String title = "Unknown Title";
        String artist = "Unknown Artist";

        // Parse Title_Artist format
        if (filename.contains('_')) {
          final parts = filename.split('_');
          title = parts[0];
          if (parts.length > 1) artist = parts[1];
        } else {
          title = filename;
        }

        return MediaItem(
          id: path, // IMPORTANT: ID is the local file path
          title: title,
          artist: artist,
          album: 'Downloaded Songs',
          // ⭐️ Use local asset for offline logo support
          artUri: Uri.parse("asset:///assets/dankie_logo.PNG"),
        );
      }).toList();

      // 2. Load the playlist into AudioHandler starting at the tapped index
      await audioHandler?.loadPlaylist(playlist, index);

      // 3. Show the Music Player Sheet
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true, // Allows sheet to expand fully
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (context) => MusicPlayerSheet(themeColor: Theme.of(context), onDownload: (String url, String title, String artist) {  },),
        );
      }
    } catch (e) {
      debugPrint("Error playing local file: $e");
    }
  }

  // 

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return Scaffold(
      backgroundColor: color.scaffoldBackgroundColor,
      appBar: isIOSPlatform
          ? CupertinoNavigationBar(
              middle: Text(
                'Downloaded Songs',
                style: TextStyle(color: color.primaryColor),
              ),
              backgroundColor: color.scaffoldBackgroundColor,
              leading: CupertinoNavigationBarBackButton(
                color: color.primaryColor,
                onPressed: () => Navigator.pop(context),
              ),
            )
          : AppBar(
              title: const Text('Downloaded Songs'),
              foregroundColor: color.primaryColor,
              backgroundColor: color.scaffoldBackgroundColor,
              centerTitle: true,
            ),
      body: _isLoading
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
                  Icon(
                    Ionicons.cloud_offline_outline,
                    size: 60,
                    color: color.hintColor,
                  ),
                  SizedBox(height: 20),
                  Text(
                    "No downloaded songs",
                    style: TextStyle(color: color.hintColor, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _files.length,
              padding: EdgeInsets.all(10),
              itemBuilder: (context, index) {
                final file = _files[index];
                final path = file.path;
                final filename = path.split('/').last.replaceAll('.mp3', '');

                // Basic parsing of our filename format "Title_Artist"
                String displayTitle = filename;
                String displayArtist = "Offline Music";

                if (filename.contains('_')) {
                  final parts = filename.split('_');
                  displayTitle = parts[0];
                  if (parts.length > 1) displayArtist = parts[1];
                }

                return Card(
                  elevation: 2,
                  margin: EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  color: color.scaffoldBackgroundColor,
                  child: ListTile(
                    leading: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: color.primaryColor.withOpacity(0.1),
                      ),
                      child: Icon(
                        Ionicons.musical_note,
                        color: color.primaryColor,
                      ),
                    ),
                    title: Text(
                      displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      displayArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        isIOSPlatform
                            ? CupertinoIcons.trash
                            : Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _deleteSong(file),
                    ),
                    onTap: () => _playLocalSong(index),
                  ),
                );
              },
            ),
    );
  }
}
