// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http; // Added for Django
import 'package:firebase_auth/firebase_auth.dart'; // REQUIRED FOR SECURE TOKEN

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/AdBanner.dart' hide isAndroidPlatform;
import 'package:ttact/Components/HomePageHelpers.dart';
import 'package:ttact/Components/LiabraryHelper.dart';
import 'package:ttact/Components/MusicPlayerSheet.dart';
import 'package:ttact/Pages/User/downloaded_songs.dart' hide isIOSPlatform;
import 'package:ttact/Pages/User/library_songs.dart' hide isIOSPlatform;
import 'package:ttact/main.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

class MusicTab extends StatefulWidget {
  final bool isDesktop;

  const MusicTab({super.key, required this.isDesktop});

  @override
  State<MusicTab> createState() => MusicTabState();
}

class MusicTabState extends State<MusicTab> with TickerProviderStateMixin {
  AdManager adManager = AdManager();
  int _songPlayCount = 0;

  final TextEditingController _musicSearchController = TextEditingController();
  String _musicSearchQuery = '';
  String _selectedCategory = 'All';
  int? _selectedSongIndex;
  
  // Data State (Replaces QuerySnapshot)
  List<dynamic> _currentFilteredSongs = [];
  late Future<List<dynamic>> _musicFuture;
  late AnimationController _rotationController;

  String? _localAppPath;

  Future<void> _initLocalPath() async {
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      setState(() {
        _localAppPath = dir.path;
      });
    }
  }

  // --- 1. FETCH MUSIC (DJANGO - SECURED) ---
  Future<List<dynamic>> _fetchMusic() async {
    try {
      // SECURE FIX: Grab the current user and their token
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Blocked: No user is currently logged in.");
        return []; 
      }

      String? token = await user.getIdToken();
      if (token == null) {
        print("❌ Blocked: Could not retrieve Firebase token.");
        return [];
      }

      // URL: /api/tact_music/
      final url = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/songs/');
      
      // SECURE FIX: Add Authorization header
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        }
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("Error fetching music: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("Network error: $e");
      return [];
    }
  }

  // --- PUBLIC METHOD FOR DEEP LINKING ---
  Future<void> playDeepLinkedSong(String targetUrl) async {
    try {
      List<dynamic> allSongs = await _musicFuture;

      final validSongs = allSongs.where((song) {
        final sUrl = song['song_url'] ?? song['songUrl'];
        return sUrl != null && sUrl.toString().trim().startsWith('https://');
      }).toList();

      int foundIndex = -1;
      for (int i = 0; i < validSongs.length; i++) {
        final data = validSongs[i];
        if ((data['song_url'] ?? data['songUrl']) == targetUrl) {
          foundIndex = i;
          break;
        }
      }

      if (foundIndex != -1) {
        debugPrint("✅ Deep Linked Song found at index $foundIndex. Playing...");
        setState(() {
          _selectedCategory = 'All';
          _musicSearchController.clear();
          _musicSearchQuery = '';
          _currentFilteredSongs = validSongs;
          _selectedSongIndex = foundIndex;
        });
        _handleSongPlay(foundIndex, _currentFilteredSongs, Theme.of(context));
      } else {
        showPlatformMessage(
          context,
          "Song Not Found",
          "The shared song could not be found in our library.",
          Colors.orange,
        );
      }
    } catch (e) {
      debugPrint("Error processing deep link song: $e");
      showPlatformMessage(
        context,
        "Error",
        "Failed to load song data. Please check your connection.",
        Colors.red,
      );
    }
  }

  // --- DOWNLOAD LOGIC ---
  Future<void> _downloadSong(String url, String title, String artist) async {
    if (!kIsWeb && isAndroidPlatform) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final safeArtist = artist.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final filename = '${safeTitle}_${safeArtist}.mp3';
      final savePath = '${dir.path}/$filename';

      if (File(savePath).existsSync()) {
        showPlatformMessage(
          context,
          'Info',
          'Song already downloaded!',
          Colors.blue,
        );
        return;
      }

      showPlatformMessage(
        context,
        'Downloading',
        'Downloading $title...',
        Colors.orange,
      );

      await Dio().download(url, savePath);

      showPlatformMessage(
        context,
        'Success',
        'Song saved to library!',
        Colors.green,
      );
      setState(() {});
    } catch (e) {
      debugPrint("Download Error: $e");
      showPlatformMessage(
        context,
        'Error',
        'Failed to download. Check connection.',
        Colors.red,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    _initLocalPath();
    _musicFuture = _fetchMusic();

    _musicSearchController.addListener(() {
      setState(() {
        _musicSearchQuery = _musicSearchController.text;
        _selectedSongIndex = null;
      });
    });

    adManager.loadRewardedInterstitialAd();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _musicSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // TINT CALCULATION
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    if (widget.isDesktop) {
      // DESKTOP LAYOUT
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 300,
            padding: const EdgeInsets.all(20.0),
            child: _buildMusicControls(theme, neumoBaseColor),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildSongList(theme, neumoBaseColor),
            ),
          ),
          Container(
            alignment: Alignment.centerRight,
            width: 350, 
            padding: const EdgeInsets.all(20.0),
            child: _buildDesktopPlayer(theme, neumoBaseColor),
          ),
        ],
      );
    } else {
      // MOBILE LAYOUT
      return Stack(
        children: [
          Column(
            children: [
              SizedBox(height: 10),
              _buildMusicControls(theme, neumoBaseColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 10,
                  ),
                  child: _buildSongList(theme, neumoBaseColor),
                ),
              ),
              StreamBuilder<MediaItem?>(
                stream: audioHandler?.mediaItem,
                builder: (context, snapshot) =>
                    snapshot.hasData ? SizedBox(height: 80) : SizedBox.shrink(),
              ),
            ],
          ),

          _buildMiniPlayer(theme, neumoBaseColor),

          if (!kIsWeb)
            StreamBuilder<MediaItem?>(
              stream: audioHandler?.mediaItem,
              builder: (context, snapshot) {
                double bottomPos = snapshot.hasData ? 95 : 15;
                return AnimatedPositioned(
                  duration: Duration(milliseconds: 300),
                  right: 15,
                  bottom: bottomPos,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DownloadedSongs(),
                        ),
                      );
                    },
                    child: NeumorphicContainer(
                      color: neumoBaseColor,
                      borderRadius: 50,
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.download_done_outlined,
                        size: 28,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          StreamBuilder<MediaItem?>(
            stream: audioHandler?.mediaItem,
            builder: (context, snapshot) {
              double bottomPos = snapshot.hasData ? 95 : 15;
              return AnimatedPositioned(
                duration: Duration(milliseconds: 300),
                right: kIsWeb ? 15 : 85,
                bottom: bottomPos,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LibrarySongs()),
                    );
                  },
                  child: NeumorphicContainer(
                    color: neumoBaseColor,
                    borderRadius: 50,
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.library_add,
                      size: 28,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    }
  }

  // --- MINI PLAYER WIDGET ---
  Widget _buildMiniPlayer(ThemeData theme, Color baseColor) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler?.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return SizedBox.shrink();

        return Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (context) => MusicPlayerSheet(
                  themeColor: theme,
                  onDownload: (url, title, artist) =>
                      _downloadSong(url, title, artist),
                ),
              );
            },
            child: NeumorphicContainer(
              color: baseColor,
              borderRadius: 20,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  RotationTransition(
                    turns: Tween(
                      begin: 0.0,
                      end: 1.0,
                    ).animate(_rotationController),
                    child: NeumorphicContainer(
                      color: baseColor,
                      borderRadius: 40,
                      padding: EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: Image.asset(
                          "assets/dankie_logo.PNG",
                          width: 45,
                          height: 45,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mediaItem.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: theme.primaryColor,
                          ),
                        ),
                        Text(
                          mediaItem.artist ?? "Unknown",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<PlaybackState>(
                    stream: audioHandler?.playbackState,
                    builder: (context, playbackSnapshot) {
                      final playing = playbackSnapshot.data?.playing ?? false;
                      return IconButton(
                        icon: Icon(
                          playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: theme.primaryColor,
                          size: 35,
                        ),
                        onPressed: () => playing
                            ? audioHandler?.pause()
                            : audioHandler?.play(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildSeekBar(ThemeData theme) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler?.playbackState,
      builder: (context, playbackSnapshot) {
        final state = playbackSnapshot.data;
        final position = state?.updatePosition ?? Duration.zero;
        final duration =
            audioHandler?.mediaItem.value?.duration ?? Duration.zero;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 6,
                activeTrackColor: theme.primaryColor,
                inactiveTrackColor: theme.primaryColor.withOpacity(0.2),
                thumbColor: theme.primaryColor,
                overlayColor: theme.primaryColor.withOpacity(0.1),
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value:
                    (position.inMilliseconds > 0 &&
                        position.inMilliseconds < duration.inMilliseconds)
                    ? position.inMilliseconds.toDouble()
                    : 0.0,
                max: (duration.inMilliseconds > 0)
                    ? duration.inMilliseconds.toDouble()
                    : 1.0,
                onChanged: (value) {
                  audioHandler?.seek(Duration(milliseconds: value.round()));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: TextStyle(
                      color: theme.hintColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      color: theme.hintColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMusicControls(ThemeData theme, Color baseColor) {
    final categories = [
      'All',
      'choreography',
      'Apostle choir',
      'Slow Jam',
      'Instrumental songs',
      'Evangelical Brothers Songs',
    ];

    return Column(
      mainAxisSize: widget.isDesktop ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.isDesktop ? 0 : 10),
          child: NeumorphicContainer(
            color: baseColor,
            isPressed: true,
            borderRadius: 10,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _musicSearchController,
              decoration: InputDecoration(
                hintText: 'Search songs...',
                hintStyle: TextStyle(color: theme.hintColor),
                border: InputBorder.none,
                icon: Icon(
                  isIOSPlatform ? CupertinoIcons.search : Icons.search,
                  color: theme.primaryColor,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 20),
        widget.isDesktop
            ? Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedCategory = category;
                          _selectedSongIndex = null;
                        }),
                        child: NeumorphicContainer(
                          color: isSelected ? theme.primaryColor : baseColor,
                          isPressed: false,
                          borderRadius: 12,
                          padding: EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                isIOSPlatform
                                    ? CupertinoIcons.music_note
                                    : Ionicons.musical_notes_outline,
                                color: isSelected
                                    ? Colors.white
                                    : theme.hintColor,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : theme.hintColor,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            : SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedCategory = category;
                          _selectedSongIndex = null;
                        }),
                        child: NeumorphicContainer(
                          color: isSelected ? theme.primaryColor : baseColor,
                          isPressed: false,
                          borderRadius: 10,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: Center(
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : theme.hintColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildSongList(ThemeData theme, Color baseColor) {
    return FutureBuilder<List<dynamic>>(
      future: _musicFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: isIOSPlatform
                ? CupertinoActivityIndicator()
                : CircularProgressIndicator(),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No songs available',
              style: TextStyle(color: theme.hintColor),
            ),
          );
        }

        final allSongs = snapshot.data!;
        final String query = _musicSearchQuery.toLowerCase().trim();

        final filteredSongs = allSongs.where((songData) {
          // Handle Django snake_case vs legacy keys
          final String songName = (songData['song_name'] ?? songData['songName'] ?? '').toString().toLowerCase();
          final String artist = (songData['artist'] ?? '').toString().toLowerCase();
          final String category = (songData['category'] ?? '').toString().toLowerCase();
          
          final bool categoryMatches =
              _selectedCategory == 'All' ||
              category == _selectedCategory.toLowerCase();
          final bool searchMatches =
              query.isEmpty ||
              songName.contains(query) ||
              artist.contains(query);
          return categoryMatches && searchMatches;
        }).toList();

        if (filteredSongs.isEmpty)
          return Center(
            child: Text(
              'No songs found.',
              style: TextStyle(color: theme.hintColor),
            ),
          );

        _currentFilteredSongs = filteredSongs;
        return ListView.builder(
          physics: BouncingScrollPhysics(),
          itemCount: _currentFilteredSongs.length,
          itemBuilder: (context, index) => _buildSongListItem(
            theme,
            baseColor,
            _currentFilteredSongs,
            index,
          ),
        );
      },
    );
  }

  Widget _buildSongListItem(
    ThemeData theme,
    Color baseColor,
    List<dynamic> filteredSongs,
    int index,
  ) {
    final song = filteredSongs[index];

    return StreamBuilder<MediaItem?>(
      stream: audioHandler?.mediaItem,
      builder: (context, mediaItemSnapshot) {
        final currentlyPlayingId = mediaItemSnapshot.data?.id;
        final songUrl = song['song_url'] ?? song['songUrl'];
        final isSelected =
            (widget.isDesktop && index == _selectedSongIndex) ||
            (songUrl != null && currentlyPlayingId == songUrl);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: NeumorphicContainer(
            color: isSelected
                ? theme.primaryColor.withOpacity(0.05)
                : baseColor,
            isPressed: false,
            borderRadius: 15,
            padding: EdgeInsets.zero,
            child: Container(
              decoration: BoxDecoration(
                border: isSelected
                    ? Border.all(color: theme.splashColor, width: 0.1)
                    : Border.all(color: theme.primaryColor, width: 1.5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                dense: true,
                visualDensity: VisualDensity(vertical: -1),
                onTap: () => _handleSongPlay(index, filteredSongs, theme),
                leading: NeumorphicContainer(
                  color: baseColor,
                  borderRadius: 10,
                  padding: EdgeInsets.all(2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      "assets/dankie_logo.PNG",
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                title: Text(
                  song['song_name'] ?? song['songName'] ?? 'Untitled',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isSelected ? theme.primaryColor : theme.primaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${song['artist'] ?? 'Unknown'}',
                  style: TextStyle(color: theme.hintColor, fontSize: 11),
                  maxLines: 1,
                ),
                trailing: IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  icon: Icon(Icons.more_vert_rounded, color: theme.hintColor),
                  onPressed: () => _showSongOptions(context, theme, song),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopPlayer(ThemeData theme, Color baseColor) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler?.mediaItem,
      builder: (context, mediaItemSnapshot) {
        final mediaItem = mediaItemSnapshot.data;
        if (mediaItem == null)
          return Center(
            child: NeumorphicContainer(
              color: baseColor,
              isPressed: true,
              borderRadius: 20,
              padding: EdgeInsets.all(30),
              child: Text(
                'Select a song to play!',
                style: TextStyle(color: theme.hintColor),
              ),
            ),
          );

        return NeumorphicContainer(
          color: baseColor,
          isPressed: false,
          borderRadius: 30,
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StreamBuilder<PlaybackState>(
                stream: audioHandler?.playbackState,
                builder: (context, playbackStateSnapshot) {
                  final playbackState = playbackStateSnapshot.data;
                  final isPlaying = playbackState?.playing ?? false;
                  final processingState = playbackState?.processingState;
                  if (isPlaying &&
                      processingState != AudioProcessingState.loading)
                    _rotationController.repeat();
                  else
                    _rotationController.stop();
                  return RotationTransition(
                    turns: Tween(
                      begin: 1.0,
                      end: 0.0,
                    ).animate(_rotationController),
                    child: NeumorphicContainer(
                      color: baseColor,
                      isPressed: false,
                      padding: EdgeInsets.all(10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: Image.asset(
                          "assets/dankie_logo.PNG",
                          height: 180,
                          width: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 25),
              Text(
                mediaItem.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 5),
              Text(
                mediaItem.artist ?? 'Unknown Artist',
                style: TextStyle(fontSize: 14, color: theme.hintColor),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
              SizedBox(height: 30),
              _buildSeekBar(theme),
              SizedBox(height: 20),
              StreamBuilder<PlaybackState>(
                stream: audioHandler?.playbackState,
                builder: (context, playbackStateSnapshot) {
                  final playbackState = playbackStateSnapshot.data;
                  final isPlaying = playbackState?.playing ?? false;
                  final shuffleMode =
                      playbackState?.shuffleMode ??
                      AudioServiceShuffleMode.none;
                  final repeatMode =
                      playbackState?.repeatMode ?? AudioServiceRepeatMode.none;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNeuControlButton(
                        theme,
                        baseColor,
                        Ionicons.shuffle,
                        () => audioHandler?.setShuffleMode(
                          shuffleMode == AudioServiceShuffleMode.all
                              ? AudioServiceShuffleMode.none
                              : AudioServiceShuffleMode.all,
                        ),
                        isActive: shuffleMode == AudioServiceShuffleMode.all,
                      ),
                      _buildNeuControlButton(
                        theme,
                        baseColor,
                        Icons.skip_previous_rounded,
                        () => audioHandler?.skipToPrevious(),
                      ),
                      GestureDetector(
                        onTap: isPlaying
                            ? audioHandler?.pause
                            : audioHandler?.play,
                        child: NeumorphicContainer(
                          color: theme.primaryColor,
                          padding: EdgeInsets.all(16),
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      _buildNeuControlButton(
                        theme,
                        baseColor,
                        Icons.skip_next_rounded,
                        () => audioHandler?.skipToNext(),
                      ),
                      _buildNeuControlButton(
                        theme,
                        baseColor,
                        repeatMode == AudioServiceRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Ionicons.repeat,
                        () {
                          final newMode =
                              repeatMode == AudioServiceRepeatMode.none
                              ? AudioServiceRepeatMode.all
                              : (repeatMode == AudioServiceRepeatMode.all
                                    ? AudioServiceRepeatMode.one
                                    : AudioServiceRepeatMode.none);
                          audioHandler?.setRepeatMode(newMode);
                        },
                        isActive: repeatMode != AudioServiceRepeatMode.none,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNeuControlButton(
    ThemeData theme,
    Color baseColor,
    IconData icon,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: NeumorphicContainer(
        color: baseColor,
        isPressed: isActive,
        padding: EdgeInsets.all(12),
        child: Icon(
          icon,
          color: isActive ? theme.primaryColor : theme.hintColor,
          size: 20,
        ),
      ),
    );
  }

  void _showSongOptions(
    BuildContext context,
    ThemeData color,
    Map<String, dynamic> song,
  ) {
    void handleDownload() {
      Navigator.pop(context);
      _downloadSong(
        song['song_url'] ?? song['songUrl'],
        song['song_name'] ?? song['songName'] ?? 'Untitled',
        song['artist'] ?? 'Unknown',
      );
    }

    Future<void> handleAddToLibrary() async {
      Navigator.pop(context);
      await LibraryHelper.addToLibrary(song);
      showPlatformMessage(
        context,
        "Added",
        "Song added to library",
        color.primaryColor,
      );
    }

    if (isIOSPlatform) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: Text(song['song_name'] ?? song['songName'] ?? 'Song Options'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: handleDownload,
              child: const Text('Download Song'),
            ),
            CupertinoActionSheetAction(
              onPressed: handleAddToLibrary,
              child: const Text('Add to Library'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: color.scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.download_rounded,
                  color: color.primaryColor,
                ),
                title: const Text('Download Song'),
                onTap: handleDownload,
              ),
              ListTile(
                leading: Icon(Icons.library_add, color: color.primaryColor),
                title: const Text('Add to Library'),
                onTap: handleAddToLibrary,
              ),
            ],
          ),
        ),
      );
    }
  }

  void _handleSongPlay(
    int index,
    List<dynamic> filteredSongs,
    ThemeData color,
  ) {
    final isDesktop = isLargeScreen(context);
    final songData = filteredSongs[index];
    final clickedSongUrl = songData['song_url'] ?? songData['songUrl'] as String?;
    final currentMediaItem = audioHandler?.mediaItem.value;

    if (clickedSongUrl != null && currentMediaItem?.id == clickedSongUrl) {
      if (isDesktop)
        setState(() => _selectedSongIndex = index);
      else
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (context) =>
              MusicPlayerSheet(themeColor: color, onDownload: _downloadSong),
        );
      return;
    }

    final List<MediaItem> mediaItems = [];
    int validSongIndex = -1;
    for (int i = 0; i < filteredSongs.length; i++) {
      final sData = filteredSongs[i];
      final sUrl = sData['song_url'] ?? sData['songUrl'] as String?;
      if (sUrl != null && sUrl.trim().startsWith('https://')) {
        mediaItems.add(
          MediaItem(
            id: sUrl,
            title: sData['song_name'] ?? sData['songName'] ?? 'Untitled',
            artist: sData['artist'] ?? 'Unknown',
            artUri: Uri.parse(
              "https://firebasestorage.googleapis.com/v0/b/tact-3c612.firebasestorage.app/o/App%20Logo%2Fdankie_logo.PNG?alt=media&token=fb3a28a9-ab50-43f0-bee1-eecb34e5f394",
            ),
          ),
        );
        if (sUrl == clickedSongUrl) validSongIndex = mediaItems.length - 1;
      }
    }

    if (validSongIndex == -1) return;
    void playAction() {
      audioHandler?.loadPlaylist(mediaItems, validSongIndex);
      if (isDesktop)
        setState(() => _selectedSongIndex = index);
      else
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (context) =>
              MusicPlayerSheet(themeColor: color, onDownload: _downloadSong),
        );
    }

    if (isDesktop)
      playAction();
    else {
      _songPlayCount++;
      if (_songPlayCount >= 4)
        adManager.showRewardedInterstitialAd(
          (ad, r) {
            playAction();
            setState(() => _songPlayCount = 0);
          },
          onAdFailed: () {
            playAction();
            setState(() => _songPlayCount = 0);
          },
        );
      else
        playAction();
    }
  }
}