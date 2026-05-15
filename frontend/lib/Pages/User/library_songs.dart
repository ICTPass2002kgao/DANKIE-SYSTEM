// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/LiabraryHelper.dart';
import 'package:ttact/Components/MusicPlayerSheet.dart';
import 'package:ttact/main.dart';  
import 'package:ttact/Components/NeuDesign.dart';


bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class LibrarySongs extends StatefulWidget {
  const LibrarySongs({super.key});

  @override
  State<LibrarySongs> createState() => _LibrarySongsState();
}

class _LibrarySongsState extends State<LibrarySongs> {
  List<Map<String, dynamic>> _librarySongs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final songs = await LibraryHelper.getLibrarySongs();
    if (mounted) {
      setState(() {
        _librarySongs = songs;
        _isLoading = false;
      });
    }
  }

  void _removeFromLibrary(String songId) async {
    await LibraryHelper.removeFromLibrary(songId);
    _loadLibrary();
  }

  // --- ⭐️ FIXED: Plays the WHOLE Playlist starting from index ---
  void _playLibrarySong(int startIndex) async {
    if (_librarySongs.isEmpty || audioHandler == null) return;

    final color = Theme.of(context);

    // 1. Convert ALL library songs to MediaItems to create a queue
    List<MediaItem> playlist = _librarySongs.map((song) {
      return MediaItem(
        id: song['songUrl'] ?? '',
        title: song['songName'] ?? 'Untitled',
        artist: song['artist'] ?? 'Unknown',
        artUri: Uri.parse(
          "https://firebasestorage.googleapis.com/v0/b/tact-3c612.firebasestorage.app/o/App%20Logo%2Fdankie_logo.PNG?alt=media&token=fb3a28a9-ab50-43f0-bee1-eecb34e5f394",
        ),
      );
    }).toList();

    // 2. Load the FULL playlist, setting the clicked song as the current index
    await audioHandler!.loadPlaylist(playlist, startIndex);

    // 3. Show the Music Player Sheet
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => MusicPlayerSheet(
          themeColor: color,
          onDownload: (url, title, artist) {
            print("Download from library: $title");
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ⭐️ TINT CALCULATION
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: SafeArea(
        child: Column(
          children: [
            // ⭐️ 1. NEUMORPHIC HEADER
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 15.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: NeumorphicContainer(
                      color: neumoBaseColor,
                      borderRadius: 50,
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.arrow_back, color: theme.primaryColor),
                    ),
                  ),
                  Text(
                    "My Library",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: theme.primaryColor,
                    ),
                  ),
                  // Placeholder for spacing balance
                  SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? Center(
                      child: isIOSPlatform
                          ? const CupertinoActivityIndicator()
                          : CircularProgressIndicator(
                              color: theme.primaryColor,
                            ),
                    )
                  : _librarySongs.isEmpty
                  ? _buildEmptyState(theme, neumoBaseColor)
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _librarySongs.length,
                      itemBuilder: (context, index) {
                        final song = _librarySongs[index];
                        final songName = song['songName'] ?? 'Untitled';
                        final artist = song['artist'] ?? 'Unknown Artist';

                        // Check if this song is currently playing to highlight it
                        return StreamBuilder<MediaItem?>(
                          stream: audioHandler?.mediaItem,
                          builder: (context, snapshot) {
                            final currentId = snapshot.data?.id;
                            final isPlaying = currentId == song['songUrl'];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 15.0),
                              child: NeumorphicContainer(
                                // ⭐️ Active song gets a subtle glow/tint
                                color: isPlaying
                                    ? theme.primaryColor.withOpacity(0.05)
                                    : neumoBaseColor,
                                isPressed: false, // Convex Tile
                                borderRadius: 20,
                                padding: EdgeInsets.zero,
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  onTap: () => _playLibrarySong(index),

                                  // ⭐️ Leading Image in Sunken Frame
                                  leading: NeumorphicContainer(
                                    color: neumoBaseColor,
                                    isPressed: true, // Sunken
                                    borderRadius: 12,
                                    padding: EdgeInsets.all(3),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.asset(
                                        "assets/dankie_logo.PNG",
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),

                                  title: Text(
                                    songName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isPlaying
                                          ? theme.primaryColor
                                          : theme.textTheme.bodyMedium?.color,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    artist,
                                    style: TextStyle(color: theme.hintColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                  // ⭐️ Delete Button
                                  trailing: GestureDetector(
                                    onTap: () {
                                      _removeFromLibrary(
                                        song['songUrl'] ?? songName,
                                      );
                                    },
                                    child: NeumorphicContainer(
                                      color: neumoBaseColor,
                                      isPressed: false,
                                      padding: EdgeInsets.all(10),
                                      child: Icon(
                                        isIOSPlatform
                                            ? CupertinoIcons.delete_solid
                                            : Icons.delete,
                                        color: Colors.red.withOpacity(0.8),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, Color baseColor) {
    return Center(
      child: NeumorphicContainer(
        color: baseColor,
        isPressed: true, // Sunken Well
        borderRadius: 30,
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isIOSPlatform
                  ? CupertinoIcons.music_albums
                  : Icons.library_music_outlined,
              size: 60,
              color: theme.hintColor.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            Text(
              "Your library is empty",
              style: TextStyle(
                color: theme.hintColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Add songs from the Music tab!",
              style: TextStyle(
                color: theme.hintColor.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
