import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);

  // Stream to broadcast the current playlist items
  final _playlistItems = BehaviorSubject<List<MediaItem>>.seeded([]);
  Stream<List<MediaItem>> get playlistItemsStream => _playlistItems.stream;

  MyAudioHandler() {
    _loadEmptyPlaylist();
    _listenForPlaybackStateChanges();
    _listenForMediaItemChanges();
  }

  Future<void> _loadEmptyPlaylist() async {
    try {
      await _player.setAudioSource(_playlist);
    } catch (e) {
      debugPrint("⛔️ [AudioHandler] Error setting empty audio source: $e");
    }
  }

  AudioSource _createAudioSource(MediaItem mediaItem) {
    Uri audioUri;
    if (mediaItem.id.startsWith('http') || mediaItem.id.startsWith('https')) {
      audioUri = Uri.parse(mediaItem.id);
    } else {
      audioUri = Uri.file(mediaItem.id);
    }
    return AudioSource.uri(audioUri, tag: mediaItem);
  }

  @override
  Future<void> loadPlaylist(List<MediaItem> items, int startIndex) async {
    debugPrint("--- [AudioHandler] loadPlaylist CALLED ---");

    // Safety check for empty lists
    if (items.isEmpty) return;

    queue.add(items);
    _playlistItems.add(items);

    try {
      // iOS: Stop current playback and clear source before adding new ones
      await _player.stop();
      await _playlist.clear();
      await _playlist.addAll(items.map(_createAudioSource).toList());

      debugPrint("--- [AudioHandler] Setting Audio Source...");
      // Await the source load to ensure iOS buffers correctly
      await _player.setAudioSource(_playlist, initialIndex: startIndex);

      debugPrint("--- [AudioHandler] Starting playback...");
      _player.play(); // No await here to allow UI to remain responsive
    } catch (e, s) {
      debugPrint("⛔️⛔️ [AudioHandler] CRITICAL ERROR: $e");
      debugPrint("Stack trace: $s");
    }
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    await loadPlaylist([mediaItem], 0);
  }

  void _listenForPlaybackStateChanges() {
    Rx.combineLatest6<
          ProcessingState,
          bool,
          Duration,
          Duration?,
          LoopMode,
          bool,
          PlaybackState
        >(
          _player.processingStateStream,
          _player.playingStream,
          _player.positionStream,
          _player.bufferedPositionStream,
          _player.loopModeStream,
          _player.shuffleModeEnabledStream,
          (
            processingState,
            playing,
            position,
            bufferedPosition,
            loopMode,
            shuffleModeEnabled,
          ) {
            final audioServiceProcessingState =
                const {
                  ProcessingState.idle: AudioProcessingState.idle,
                  ProcessingState.loading: AudioProcessingState.loading,
                  ProcessingState.buffering: AudioProcessingState.buffering,
                  ProcessingState.ready: AudioProcessingState.ready,
                  ProcessingState.completed: AudioProcessingState.completed,
                }[processingState] ??
                AudioProcessingState.idle;

            return playbackState.value.copyWith(
              updatePosition: position,
              bufferedPosition: bufferedPosition ?? Duration.zero,
              playing: playing,
              processingState: audioServiceProcessingState,
              controls: [
                MediaControl.skipToPrevious,
                playing ? MediaControl.pause : MediaControl.play,
                MediaControl.skipToNext,
                MediaControl.stop,
              ],
              repeatMode: _mapLoopModeToRepeatMode(loopMode),
              shuffleMode: shuffleModeEnabled
                  ? AudioServiceShuffleMode.all
                  : AudioServiceShuffleMode.none,
            );
          },
        )
        .distinct()
        .listen((state) => playbackState.add(state));
  }

  void _listenForMediaItemChanges() {
    Rx.combineLatest2<SequenceState?, Duration?, MediaItem?>(
      _player.sequenceStateStream,
      _player.durationStream,
      (sequenceState, duration) {
        final mediaItem = sequenceState?.currentSource?.tag as MediaItem?;
        if (mediaItem == null) return null;
        return mediaItem.copyWith(duration: duration);
      },
    ).distinct().listen((mediaItem) {
      this.mediaItem.add(mediaItem);
    });
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
    await _loadEmptyPlaylist();
    mediaItem.add(null);
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await _player.setLoopMode(_mapRepeatModeToLoopMode(repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffleModeEnabled(enabled);
  }

  AudioServiceRepeatMode _mapLoopModeToRepeatMode(LoopMode loopMode) {
    switch (loopMode) {
      case LoopMode.off:
        return AudioServiceRepeatMode.none;
      case LoopMode.one:
        return AudioServiceRepeatMode.one;
      case LoopMode.all:
        return AudioServiceRepeatMode.all;
    }
  }

  LoopMode _mapRepeatModeToLoopMode(AudioServiceRepeatMode repeatMode) {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        return LoopMode.off;
      case AudioServiceRepeatMode.one:
        return LoopMode.one;
      default:
        return LoopMode.all;
    }
  }
}
