// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/AdBanner.dart' hide isAndroidPlatform;
import 'package:ttact/Components/LiabraryHelper.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/home/Tabs/music_player.dart';
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

class MusicTabState extends State<MusicTab>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // Tells Flutter to keep this widget alive when navigating away
  @override
  bool get wantKeepAlive => true;

  AdManager adManager = AdManager();
  int _songPlayCount = 0;

  final TextEditingController _musicSearchController = TextEditingController();
  String _musicSearchQuery = '';
  String _selectedCategory = 'All';
  int? _selectedSongIndex;
  Timer? _debounce;

  // Lazy Loading / Pagination State Variables
  final ScrollController _scrollController = ScrollController();
  final List<dynamic> _allLoadedSongs = [];
  bool _isLoadingNextPage = false;
  bool _hasMoreSongs = true;
  int _currentPage = 1;
  final int _pageSize = 20;

  // Data State
  List<dynamic> _currentFilteredSongs = [];
  late Future<void> _initialLoadFuture;
  late AnimationController _rotationController;

  String? _localAppPath;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    _initLocalPath();

    _initialLoadFuture = _refreshData();
    _scrollController.addListener(_onScroll);

    // ⭐️ SEARCH LOGIC FIX: Instant local filtering + Server Debounce
    _musicSearchController.addListener(() {
      if (_musicSearchQuery != _musicSearchController.text) {
        setState(() {
          _musicSearchQuery = _musicSearchController.text;
          _selectedSongIndex = null;
          _applyLocalFilter(); // Instantly update UI based on typing
        });

        // Debounce the server request to save bandwidth
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          _refreshData();
        });
      }
    });

    adManager.loadRewardedInterstitialAd();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _rotationController.dispose();
    _musicSearchController.dispose();
    super.dispose();
  }

  Future<void> _initLocalPath() async {
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      setState(() {
        _localAppPath = dir.path;
      });
    }
  }

  // ⭐️ NEW: Instant Client-Side Filter Function
  void _applyLocalFilter() {
    if (_musicSearchQuery.trim().isEmpty) {
      _currentFilteredSongs = List.from(_allLoadedSongs);
    } else {
      final query = _musicSearchQuery.trim().toLowerCase();
      _currentFilteredSongs = _allLoadedSongs.where((song) {
        final name = (song['song_name'] ?? song['songName'] ?? '')
            .toString()
            .toLowerCase();
        final artist = (song['artist'] ?? '').toString().toLowerCase();
        return name.contains(query) || artist.contains(query);
      }).toList();
    }
  }

  // --- FETCH MUSIC PAGE (DJANGO - SECURED) ---
  Future<List<dynamic>> _fetchMusicPage(int page) async {
    try {
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

      // Build query string
      String queryParams = '?page=$page&page_size=$_pageSize';

      if (_musicSearchQuery.trim().isNotEmpty) {
        queryParams +=
            '&search=${Uri.encodeComponent(_musicSearchQuery.trim())}';
      }

      if (_selectedCategory != 'All') {
        queryParams += '&category=${Uri.encodeComponent(_selectedCategory)}';
      }

      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/songs/$queryParams',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);

        if (decodedData is Map<String, dynamic> &&
            decodedData.containsKey('results')) {
          return decodedData['results'] as List<dynamic>;
        } else if (decodedData is List<dynamic>) {
          return decodedData;
        }
        return [];
      } else {
        print("Error fetching music page $page: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Network error: $e");
      return [];
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _currentPage = 1;
      _hasMoreSongs = true;
      _allLoadedSongs.clear();
      _currentFilteredSongs.clear();
    });

    final firstPageData = await _fetchMusicPage(_currentPage);

    if (mounted) {
      setState(() {
        if (firstPageData.isEmpty || firstPageData.length < _pageSize) {
          _hasMoreSongs = false;
        }
        _allLoadedSongs.addAll(firstPageData);
        _applyLocalFilter(); // Ensure the filter is applied to the fresh data
      });
    }
  }

  void _onScroll() async {
    if (!_scrollController.hasClients || _isLoadingNextPage || !_hasMoreSongs)
      return;

    final threshold = _scrollController.position.maxScrollExtent * 0.85;
    if (_scrollController.position.pixels >= threshold) {
      setState(() {
        _isLoadingNextPage = true;
      });

      int nextPage = _currentPage + 1;
      final nextPageData = await _fetchMusicPage(nextPage);

      if (mounted) {
        setState(() {
          if (nextPageData.isEmpty || nextPageData.length < _pageSize) {
            _hasMoreSongs = false;
          }

          final existingUrls = _allLoadedSongs
              .map((song) => song['song_url'] ?? song['songUrl'])
              .toSet();

          final newSongs = nextPageData.where((song) {
            final url = song['song_url'] ?? song['songUrl'];
            return url != null && !existingUrls.contains(url);
          }).toList();

          if (nextPageData.isNotEmpty && newSongs.isEmpty) {
            _hasMoreSongs = false;
          } else {
            _allLoadedSongs.addAll(newSongs);
            _currentPage = nextPage;
            _applyLocalFilter(); // Apply local filter to newly fetched data
          }

          _isLoadingNextPage = false;
        });
      }
    }
  }

  Future<void> playDeepLinkedSong(
    String targetIdentifier, {
    int retryCount = 0,
  }) async {
    // Retry if list is empty
    if (_allLoadedSongs.isEmpty && retryCount < 10) {
      await Future.delayed(Duration(milliseconds: 500));
      return playDeepLinkedSong(targetIdentifier, retryCount: retryCount + 1);
    }

    final foundIndex = _allLoadedSongs.indexWhere((song) {
      final songId = song['uid']?.toString() ?? song['id']?.toString();
      final songUrl =
          song['song_url']?.toString() ?? song['songUrl']?.toString();

      return songId == targetIdentifier || songUrl == targetIdentifier;
    });

    if (foundIndex != -1) {
      setState(() {
        _selectedCategory = 'All';
        _musicSearchController.clear();
        _musicSearchQuery = '';
        _applyLocalFilter();
        _selectedSongIndex = foundIndex;
      });
      _handleSongPlay(foundIndex, _currentFilteredSongs, Theme.of(context));
    } else {
      Api().showMessage(
        context,
        "Song Not Found",
        "The shared song could not be found in our library. Please try searching for it.",
        Colors.orange,
      );
    }
  }

  Future<void> _downloadSong(String url, String title, String artist) async {
    if (!kIsWeb && Api().isAndroidPlatform) {
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
        Api().showMessage(
          context,
          'Info',
          'Song already downloaded!',
          Colors.blue,
        );
        return;
      }

      Api().showMessage(
        context,
        'Downloading',
        'Downloading $title...',
        Colors.orange,
      );

      await Dio().download(url, savePath);

      Api().showMessage(
        context,
        'Success',
        'Song saved to library!',
        Colors.green,
      );
      setState(() {});
    } catch (e) {
      debugPrint("Download Error: $e");
      Api().showMessage(
        context,
        'Error',
        'Failed to download. Check connection.',
        Colors.red,
      );
    }
  }

  void _handleSongPlay(int index, List<dynamic> songList, ThemeData color) {
    final songData = songList[index];
    final clickedSongUrl =
        songData['song_url'] ?? songData['songUrl'] as String?;

    final List<MediaItem> mediaItems = [];
    int validSongIndex = -1;

    for (int i = 0; i < songList.length; i++) {
      final s = songList[i];
      final sUrl = s['song_url'] ?? s['songUrl'] as String?;
      if (sUrl != null && sUrl.trim().startsWith('https://')) {
        mediaItems.add(
          MediaItem(
            id: sUrl,
            title: s['song_name'] ?? s['songName'] ?? 'Untitled',
            artist: s['artist'] ?? 'Unknown',
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              MusicPlayerPage(themeColor: color, onDownload: _downloadSong),
        ),
      );
    }

    if (widget.isDesktop) {
      playAction();
    } else {
      _songPlayCount++;
      if (_songPlayCount >= 4) {
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
      } else {
        playAction();
      }
    }
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
      Api().showMessage(
        context,
        "Added",
        "Song added to library",
        color.primaryColor,
      );
    }

    if (Api().isIOSPlatform) {
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    Widget bodyContent;

    if (widget.isDesktop) {
      bodyContent = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildMusicControls(theme, neumoBaseColor),
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 20.0,
                horizontal: 10.0,
              ),
              child: _buildSongList(theme, neumoBaseColor),
            ),
          ),
        ],
      );
    } else {
      bodyContent = Column(
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
      );
    }

    return Stack(
      children: [
        bodyContent,
        _buildMiniPlayer(theme, neumoBaseColor),

        StreamBuilder<MediaItem?>(
          stream: audioHandler?.mediaItem,
          builder: (context, snapshot) {
            double bottomPos = snapshot.hasData ? 95 : 15;
            return AnimatedPositioned(
              duration: Duration(milliseconds: 300),
              right: 85,
              bottom: bottomPos,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DownloadedSongs()),
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

        // Library Button
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MusicPlayerPage(
                    themeColor: theme,
                    onDownload: (url, title, artist) =>
                        _downloadSong(url, title, artist),
                  ),
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
                  Api().isIOSPlatform ? CupertinoIcons.search : Icons.search,
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
                        onTap: () {
                          if (_selectedCategory != category) {
                            setState(() {
                              _selectedCategory = category;
                              _selectedSongIndex = null;
                            });
                            _refreshData();
                          }
                        },
                        child: NeumorphicContainer(
                          color: isSelected ? theme.primaryColor : baseColor,
                          isPressed: false,
                          borderRadius: 12,
                          padding: EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                Api().isIOSPlatform
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
                        onTap: () {
                          if (_selectedCategory != category) {
                            setState(() {
                              _selectedCategory = category;
                              _selectedSongIndex = null;
                            });
                            _refreshData();
                          }
                        },
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
    return FutureBuilder<void>(
      future: _initialLoadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _allLoadedSongs.isEmpty) {
          return Center(
            child: Api().isIOSPlatform
                ? CupertinoActivityIndicator()
                : CircularProgressIndicator(),
          );
        }
        if (_allLoadedSongs.isEmpty) {
          return Center(
            child: Text(
              'No songs available',
              style: TextStyle(color: theme.hintColor),
            ),
          );
        }

        if (_currentFilteredSongs.isEmpty) {
          return Center(
            child: Text(
              'No songs found.',
              style: TextStyle(color: theme.hintColor),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          physics: BouncingScrollPhysics(),
          itemCount: _currentFilteredSongs.length + (_hasMoreSongs ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _currentFilteredSongs.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Api().isIOSPlatform
                      ? CupertinoActivityIndicator()
                      : CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            return _buildSongListItem(
              theme,
              baseColor,
              _currentFilteredSongs,
              index,
            );
          },
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

    bool isDownloaded = false;
    if (_localAppPath != null && !kIsWeb) {
      final title = song['song_name'] ?? song['songName'] ?? 'Untitled';
      final artist = song['artist'] ?? 'Unknown';
      final safeTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final safeArtist = artist.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final filename = '${safeTitle}_${safeArtist}.mp3';
      final savePath = '$_localAppPath/$filename';
      isDownloaded = File(savePath).existsSync();
    }

    return StreamBuilder<MediaItem?>(
      stream: audioHandler?.mediaItem,
      builder: (context, mediaItemSnapshot) {
        final currentlyPlayingId = mediaItemSnapshot.data?.id;
        final songUrl = song['song_url'] ?? song['songUrl'];
        final isSelected = (songUrl != null && currentlyPlayingId == songUrl);

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
                    ? Border.all(color: theme.primaryColor, width: 1.5)
                    : Border.all(
                        color: theme.primaryColor.withOpacity(0.3),
                        width: 0.5,
                      ),
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
                    color: theme.primaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${song['artist'] ?? 'Unknown'}',
                  style: TextStyle(color: theme.hintColor, fontSize: 11),
                  maxLines: 1,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDownloaded)
                      Padding(
                        padding: const EdgeInsets.only(right: 5.0),
                        child: Icon(
                          Icons.download_done_rounded,
                          color: theme.primaryColor,
                          size: 20,
                        ),
                      ),
                    IconButton(
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: theme.hintColor,
                      ),
                      onPressed: () => _showSongOptions(context, theme, song),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
