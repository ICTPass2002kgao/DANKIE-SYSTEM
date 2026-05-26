// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/HomePageHelpers.dart'; // For isIOSPlatform
import 'package:ttact/Components/LiabraryHelper.dart';
import 'package:ttact/Components/Share_Song.dart' hide isIOSPlatform; 
import 'package:ttact/main.dart'; // For global audioHandler

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

class MusicPlayerSheet extends StatefulWidget {
  final ThemeData themeColor;
  final Function(String url, String title, String artist) onDownload;

  const MusicPlayerSheet({
    Key? key,
    required this.themeColor,
    required this.onDownload,
  }) : super(key: key);

  @override
  State<MusicPlayerSheet> createState() => _MusicPlayerSheetState();
}

class _MusicPlayerSheetState extends State<MusicPlayerSheet>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;

  // Player State
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Subscriptions
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;

  // Library State
  bool _isSongInLibrary = false;

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

    // Listen for Duration & Library Status
    _durationSubscription = audioHandler?.mediaItem.listen((mediaItem) {
      final newDuration = mediaItem?.duration ?? Duration.zero;
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
        if (mediaItem != null) {
          _checkLibraryStatus(mediaItem.id);
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

  // ⭐️ NEUMORPHIC SEEK BAR
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

  // ⭐️ NEUMORPHIC CONTROL BUTTON
  Widget _buildNeuBtn({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 24,
    Color? iconColor,
    bool isActive = false,
    bool isLarge = false, // For Play/Pause
  }) {
    final color =
        iconColor ??
        (isActive
            ? widget.themeColor.primaryColor
            : widget.themeColor.hintColor);

    // Calculate Tint
    final theme = widget.themeColor;
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return GestureDetector(
      onTap: onPressed,
      child: NeumorphicContainer(
        
        color: isLarge
            ? widget.themeColor.primaryColor
            : neumoBaseColor, // Play button is colored
        isPressed: isActive && !isLarge, // Only toggle buttons look "pressed"
        padding: EdgeInsets.all(isLarge ? 20 : 15),
        child: Icon(icon, size: size, color: isLarge ? Colors.white : color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // TINT CALCULATION
    final theme = widget.themeColor;
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Container(
      decoration: BoxDecoration(
        color: neumoBaseColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
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
                    child: CircularProgressIndicator(color: theme.primaryColor),
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
                      playbackState?.repeatMode ?? AudioServiceRepeatMode.none;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Handle Bar
                      Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: theme.hintColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // 1. ROTATING ALBUM ART (Sunken Ring)
                      NeumorphicContainer(
                        color: neumoBaseColor,
                        isPressed: true, // Sunken Ring
                        padding: EdgeInsets.all(8),
                        child: RotationTransition(
                          turns: Tween(
                            begin: 0.0,
                            end: 1.0,
                          ).animate(_rotationController),
                          child: Container(
                            height: 220,
                            width: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              // Border around image
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
                              borderRadius: BorderRadius.circular(110),
                              child: Image.asset(
                                "assets/dankie_logo.PNG",
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // 2. TITLE & ACTIONS ROW
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mediaItem.title,
                                  style: TextStyle(
                                    fontSize: 22,
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
                                    fontSize: 16,
                                    color: theme.hintColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Action Buttons (Download, Library, Share)
                          Row(
                            children: [
                              _buildActionIcon(
                                icon: isIOSPlatform
                                    ? CupertinoIcons.cloud_download
                                    : Icons.download_rounded,
                                onTap: () => widget.onDownload(
                                  mediaItem.id,
                                  mediaItem.title,
                                  mediaItem.artist ?? 'Unknown',
                                ),
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
                                    builder: (context) => TikTokShareSheet(
                                      songName: mediaItem.title,
                                      artistName: mediaItem.artist ?? "Unknown",
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

                      // 3. SEEK BAR
                      _buildSeekBar(neumoBaseColor),

                      const SizedBox(height: 30),

                      // 4. MAIN CONTROLS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Shuffle
                          _buildNeuBtn(
                            icon: isIOSPlatform
                                ? CupertinoIcons.shuffle
                                : Icons.shuffle,
                            isActive:
                                shuffleMode == AudioServiceShuffleMode.all,
                            onPressed: () {
                              final newMode =
                                  shuffleMode == AudioServiceShuffleMode.all
                                  ? AudioServiceShuffleMode.none
                                  : AudioServiceShuffleMode.all;
                              audioHandler?.setShuffleMode(newMode);
                            },
                          ),

                          // Prev
                          _buildNeuBtn(
                            icon: isIOSPlatform
                                ? CupertinoIcons.backward_fill
                                : Icons.skip_previous_rounded,
                            size: 30,
                            onPressed: () => audioHandler?.skipToPrevious(),
                          ),

                          // PLAY / PAUSE (Large)
                          _buildNeuBtn(
                            icon: isPlaying
                                ? (isIOSPlatform
                                      ? CupertinoIcons.pause_fill
                                      : Icons.pause_rounded)
                                : (isIOSPlatform
                                      ? CupertinoIcons.play_fill
                                      : Icons.play_arrow_rounded),
                            size: 40,
                            isLarge: true, // Makes it colored and bigger
                            onPressed: isPlaying
                                ? () => audioHandler?.pause()
                                : () => audioHandler?.play(),
                          ),

                          // Next
                          _buildNeuBtn(
                            icon: isIOSPlatform
                                ? CupertinoIcons.forward_fill
                                : Icons.skip_next_rounded,
                            size: 30,
                            onPressed: _handleNextPress,
                          ),

                          // Repeat
                          _buildNeuBtn(
                            icon: repeatMode == AudioServiceRepeatMode.one
                                ? (isIOSPlatform
                                      ? CupertinoIcons.repeat_1
                                      : Icons.repeat_one_rounded)
                                : (isIOSPlatform
                                      ? CupertinoIcons.repeat
                                      : Icons.repeat_rounded),
                            isActive: repeatMode != AudioServiceRepeatMode.none,
                            onPressed: () {
                              final newMode =
                                  repeatMode == AudioServiceRepeatMode.none
                                  ? AudioServiceRepeatMode.all
                                  : (repeatMode == AudioServiceRepeatMode.all
                                        ? AudioServiceRepeatMode.one
                                        : AudioServiceRepeatMode.none);
                              audioHandler?.setRepeatMode(newMode);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Small Helper for the top right action icons
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
}
