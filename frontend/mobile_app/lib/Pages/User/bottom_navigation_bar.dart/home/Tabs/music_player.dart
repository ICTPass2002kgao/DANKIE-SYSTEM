// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart'; 
import 'package:path_provider/path_provider.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/HomePageHelpers.dart'; // For isIOSPlatform
import 'package:ttact/Components/LiabraryHelper.dart';
import 'package:ttact/Components/Share_Song.dart' hide isIOSPlatform;
import 'package:ttact/main.dart'; // For global audioHandler

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

class MusicPlayerPage extends StatefulWidget {
  final ThemeData themeColor;
  final Function(String url, String title, String artist) onDownload;

  const MusicPlayerPage({
    Key? key,
    required this.themeColor,
    required this.onDownload,
  }) : super(key: key);

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;

  // Player State
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Subscriptions
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;

  // Library & Download State
  bool _isSongInLibrary = false;
  bool _isDownloaded = false;
  String? _localAppPath;

  // Ad Logic
  static int _nextBtnClickCount = 0;
  final int _adThreshold = 5;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _initLocalPath();

    // Listen for Duration & Library Status
    _durationSubscription = audioHandler?.mediaItem.listen((mediaItem) {
      final newDuration = mediaItem?.duration ?? Duration.zero;
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
        if (mediaItem != null) {
          _checkLibraryStatus(mediaItem.id);
          _checkDownloadStatus(mediaItem.title, mediaItem.artist ?? 'Unknown');
        }
      }
    });

    // Listen for Position
    _positionSubscription = AudioService.position.listen((newPosition) {
      if (mounted) {
        setState(() => _position = newPosition);
      }
    });

    // Listen for Playback State (Animation)
    _playerCompleteSubscription = audioHandler?.playbackState.listen((state) {
      if (mounted) {
        if (state.playing &&
            state.processingState != AudioProcessingState.loading) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }
      }
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _initLocalPath() async {
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      setState(() {
        _localAppPath = dir.path;
      });
      // Check immediately if media item is already loaded
      final mediaItem = audioHandler?.mediaItem.value;
      if (mediaItem != null) {
        _checkDownloadStatus(mediaItem.title, mediaItem.artist ?? 'Unknown');
      }
    }
  }

  void _checkDownloadStatus(String title, String artist) {
    if (_localAppPath != null && !kIsWeb) {
      final safeTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final safeArtist = artist.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final filename = '${safeTitle}_${safeArtist}.mp3';
      final savePath = '$_localAppPath/$filename';

      setState(() {
        _isDownloaded = File(savePath).existsSync();
      });
    }
  }

  Future<void> _checkLibraryStatus(String songId) async {
    bool exists = await LibraryHelper.isSongInLibrary(songId);
    if (mounted) setState(() => _isSongInLibrary = exists);
  }

  Future<void> _toggleLibrary() async {
    final mediaItem = audioHandler?.mediaItem.value;
    if (mediaItem == null) return;

    if (_isSongInLibrary) {
      await LibraryHelper.removeFromLibrary(mediaItem.id);
      if (mounted) {
        setState(() => _isSongInLibrary = false);
        Api().showMessage(
          context,
          "Removed from Library",
          "Success",
          Colors.red,
        );
      }
    } else {
      Map<String, dynamic> songMap = {
        'songName': mediaItem.title,
        'artist': mediaItem.artist,
        'songUrl': mediaItem.id,
      };
      await LibraryHelper.addToLibrary(songMap);
      if (mounted) {
        setState(() => _isSongInLibrary = true);
        Api().showMessage(context, "Added to Library", "Success", Colors.green);
      }
    }
  }

  void _handleNextPress() {
    _nextBtnClickCount++;
    if (_nextBtnClickCount >= _adThreshold) {
      if (!kIsWeb) {
        AdManager().showRewardedInterstitialAd(
          (ad, reward) {
            audioHandler?.skipToNext();
            _nextBtnClickCount = 0;
          },
          onAdFailed: () {
            audioHandler?.skipToNext();
            _nextBtnClickCount = 0;
          },
        );
      } else {
        audioHandler?.skipToNext();
        _nextBtnClickCount = 0;
      }
    } else {
      audioHandler?.skipToNext();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildSeekBar(Color baseColor) {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: widget.themeColor.primaryColor,
            inactiveTrackColor: widget.themeColor.primaryColor.withOpacity(0.2),
            thumbColor: widget.themeColor.primaryColor,
            overlayColor: widget.themeColor.primaryColor.withOpacity(0.1),
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            min: 0.0,
            max: _duration.inSeconds.toDouble() > 0
                ? _duration.inSeconds.toDouble()
                : 1.0,
            value: _position.inSeconds.toDouble().clamp(
              0.0,
              (_duration.inSeconds.toDouble() > 0
                  ? _duration.inSeconds.toDouble()
                  : 1.0),
            ),
            onChanged: (value) {
              audioHandler?.seek(Duration(seconds: value.toInt()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: TextStyle(
                  color: widget.themeColor.hintColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: TextStyle(
                  color: widget.themeColor.hintColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNeuBtn({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 24,
    Color? iconColor,
    bool isActive = false,
    bool isLarge = false,
  }) {
    final color =
        iconColor ??
        (isActive
            ? widget.themeColor.primaryColor
            : widget.themeColor.hintColor);

    final theme = widget.themeColor;
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return GestureDetector(
      onTap: onPressed,
      child: NeumorphicContainer(
        color: isLarge ? widget.themeColor.primaryColor : neumoBaseColor,
        isPressed: isActive && !isLarge,
        padding: EdgeInsets.all(isLarge ? 20 : 15),
        child: Icon(icon, size: size, color: isLarge ? Colors.white : color),
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required VoidCallback onTap,
    required ThemeData theme,
    required Color baseColor,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: NeumorphicContainer(
        color: baseColor,
        isPressed: isActive,
        padding: EdgeInsets.all(10),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? theme.primaryColor : theme.hintColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.themeColor;
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    // RESPONSIVE SCREEN CHECKS
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;

    // Dynamic sizing based on layout
    final double albumArtSize = isDesktop ? 350 : 220;
    final double albumArtPadding = isDesktop ? 70 : 50;
    final double maxBoxWidth = isDesktop ? 1100 : 450;

    return Scaffold(
      backgroundColor: neumoBaseColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            isIOSPlatform ? CupertinoIcons.chevron_back : Icons.arrow_back,
            size: 32,
            color: theme.primaryColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBoxWidth),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(25, 15, 25, 40),
                child: StreamBuilder<MediaItem?>(
                  stream: audioHandler?.mediaItem,
                  builder: (context, mediaItemSnapshot) {
                    final mediaItem = mediaItemSnapshot.data;

                    if (mediaItem == null) {
                      return SizedBox(
                        height: 300,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: theme.primaryColor,
                          ),
                        ),
                      );
                    }

                    return StreamBuilder<PlaybackState>(
                      stream: audioHandler?.playbackState,
                      builder: (context, playbackStateSnapshot) {
                        final playbackState = playbackStateSnapshot.data;
                        final isPlaying = playbackState?.playing ?? false;
                        final shuffleMode =
                            playbackState?.shuffleMode ??
                            AudioServiceShuffleMode.none;
                        final repeatMode =
                            playbackState?.repeatMode ??
                            AudioServiceRepeatMode.none;

                        // --- 1. ALBUM ART WIDGET ---
                        Widget albumArtWidget = NeumorphicContainer(
                          color: neumoBaseColor,
                          isPressed: true,
                          borderRadius: isDesktop ? 50 : 30,
                          padding: EdgeInsets.all(albumArtPadding),
                          child: RotationTransition(
                            turns: Tween(
                              begin: 0.0,
                              end: 1.0,
                            ).animate(_rotationController),
                            child: Container(
                              height: albumArtSize,
                              width: albumArtSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: neumoBaseColor,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: Offset(5, 5),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  albumArtSize / 2,
                                ),
                                child: Image.asset(
                                  "assets/dankie_logo.PNG",
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        );

                        // --- 2. CONTROLS WIDGET ---
                        Widget controlsWidget = Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // TITLE & ACTIONS ROW
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mediaItem.title,
                                        style: TextStyle(
                                          fontSize: isDesktop ? 28 : 22,
                                          fontWeight: FontWeight.w900,
                                          color: theme.primaryColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        mediaItem.artist ?? 'Unknown Artist',
                                        style: TextStyle(
                                          fontSize: isDesktop ? 18 : 16,
                                          color: theme.hintColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),

                                Row(
                                  children: [
                                    _buildActionIcon(
                                      icon: _isDownloaded
                                          ? (isIOSPlatform
                                                ? CupertinoIcons
                                                      .cloud_download_fill
                                                : Icons.download_done_rounded)
                                          : (isIOSPlatform
                                                ? CupertinoIcons.cloud_download
                                                : Icons.download_rounded),
                                      isActive: _isDownloaded,
                                      onTap: () {
                                        if (!_isDownloaded) {
                                          widget.onDownload(
                                            mediaItem.id,
                                            mediaItem.title,
                                            mediaItem.artist ?? 'Unknown',
                                          );
                                          setState(() => _isDownloaded = true);
                                        } else {
                                          Api().showMessage(
                                            context,
                                            "Already Downloaded",
                                            "This song is saved.",
                                            Colors.blue,
                                          );
                                        }
                                      },
                                      theme: theme,
                                      baseColor: neumoBaseColor,
                                    ),
                                    SizedBox(width: 15),
                                    _buildActionIcon(
                                      icon: _isSongInLibrary
                                          ? (isIOSPlatform
                                                ? CupertinoIcons.bookmark_solid
                                                : Icons.bookmark)
                                          : (isIOSPlatform
                                                ? CupertinoIcons.bookmark
                                                : Icons.bookmark_border),
                                      onTap: _toggleLibrary,
                                      theme: theme,
                                      baseColor: neumoBaseColor,
                                      isActive: _isSongInLibrary,
                                    ),
                                    SizedBox(width: 15),
                                    _buildActionIcon(
                                      icon: isIOSPlatform
                                          ? CupertinoIcons.share
                                          : Icons.share,
                                      onTap: () {
                                        showModalBottomSheet(
                                          context: context,
                                          backgroundColor: Colors.transparent,
                                          builder: (context) =>
                                              TikTokShareSheet(
                                                songName: mediaItem.title,
                                                artistName:
                                                    mediaItem.artist ??
                                                    "Unknown",
                                                songUrl: mediaItem.id,
                                                theme: widget.themeColor,
                                              ),
                                        );
                                      },
                                      theme: theme,
                                      baseColor: neumoBaseColor,
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 30),

                            // SEEK BAR
                            _buildSeekBar(neumoBaseColor),

                            const SizedBox(height: 30),

                            // MAIN CONTROLS
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildNeuBtn(
                                  icon: isIOSPlatform
                                      ? CupertinoIcons.shuffle
                                      : Icons.shuffle,
                                  isActive:
                                      shuffleMode ==
                                      AudioServiceShuffleMode.all,
                                  onPressed: () {
                                    final newMode =
                                        shuffleMode ==
                                            AudioServiceShuffleMode.all
                                        ? AudioServiceShuffleMode.none
                                        : AudioServiceShuffleMode.all;
                                    audioHandler?.setShuffleMode(newMode);
                                  },
                                ),

                                _buildNeuBtn(
                                  icon: isIOSPlatform
                                      ? CupertinoIcons.backward_fill
                                      : Icons.skip_previous_rounded,
                                  size: 30,
                                  onPressed: () =>
                                      audioHandler?.skipToPrevious(),
                                ),

                                _buildNeuBtn(
                                  icon: isPlaying
                                      ? (isIOSPlatform
                                            ? CupertinoIcons.pause_fill
                                            : Icons.pause_rounded)
                                      : (isIOSPlatform
                                            ? CupertinoIcons.play_fill
                                            : Icons.play_arrow_rounded),
                                  size: isDesktop ? 50 : 40,
                                  isLarge: true,
                                  onPressed: isPlaying
                                      ? () => audioHandler?.pause()
                                      : () => audioHandler?.play(),
                                ),

                                _buildNeuBtn(
                                  icon: isIOSPlatform
                                      ? CupertinoIcons.forward_fill
                                      : Icons.skip_next_rounded,
                                  size: 30,
                                  onPressed: _handleNextPress,
                                ),

                                _buildNeuBtn(
                                  icon: repeatMode == AudioServiceRepeatMode.one
                                      ? (isIOSPlatform
                                            ? CupertinoIcons.repeat_1
                                            : Icons.repeat_one_rounded)
                                      : (isIOSPlatform
                                            ? CupertinoIcons.repeat
                                            : Icons.repeat_rounded),
                                  isActive:
                                      repeatMode != AudioServiceRepeatMode.none,
                                  onPressed: () {
                                    final newMode =
                                        repeatMode ==
                                            AudioServiceRepeatMode.none
                                        ? AudioServiceRepeatMode.all
                                        : (repeatMode ==
                                                  AudioServiceRepeatMode.all
                                              ? AudioServiceRepeatMode.one
                                              : AudioServiceRepeatMode.none);
                                    audioHandler?.setRepeatMode(newMode);
                                  },
                                ),
                              ],
                            ),
                          ],
                        );

                        // --- 3. RESPONSIVE LAYOUT RETURN ---
                        if (isDesktop) {
                          // HORIZONTAL LAYOUT FOR LARGE SCREENS
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Center(child: albumArtWidget),
                                ),
                                SizedBox(width: 50),
                                Expanded(flex: 5, child: controlsWidget),
                              ],
                            ),
                          );
                        } else {
                          // VERTICAL LAYOUT FOR MOBILE SCREENS
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 10),
                              albumArtWidget,
                              const SizedBox(height: 30),
                              controlsWidget,
                              const SizedBox(height: 20),
                            ],
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
