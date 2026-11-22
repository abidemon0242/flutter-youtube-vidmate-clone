import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/paged_feed.dart';
import '../../models/playback_quality.dart';
import '../../models/video_details.dart';
import '../../models/video_model.dart';
import '../../providers/playback_settings.dart';
import '../../services/home_library_service.dart';
import '../../services/media_session_service.dart';
import '../../services/network_monitor.dart';
import '../../services/youtube_extraction_service.dart';
import '../widgets/compact_video_tile.dart';
import '../widgets/download_options_sheet.dart';
import '../widgets/video_description.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key, required this.video, this.immersive = false, this.autoplay = true});

  final VideoModel video;
  final bool immersive;
  final bool autoplay;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  String? _error;
  bool _opening = false;
  bool _saved = false;
  double _playbackSpeed = 1.0;
  bool _temporaryDoubleSpeed = false;
  bool _fullscreen = false;
  bool _showControls = true;
  Timer? _hideTimer;
  late final MediaSessionService _mediaSession;
  late final YoutubeExtractionService _youtube;
  late final PlaybackSettings _settings;
  late final ConnectivityNetworkMonitor _networkMonitor;
  StreamSubscription<bool>? _networkSubscription;
  bool _onWifi = false;

  // Streaming quality.
  List<PlaybackQuality> _qualities = const [];
  PlaybackQuality? _quality;
  bool _switching = false;
  bool _userPickedQuality = false;
  bool _lookingForHd = false;
  bool _hdChecked = false;

  bool _attaching = false;
  bool _pausedForBackground = false;

  // Details under the player (YouTube videos only).
  Future<VideoDetails>? _details;
  PagedFeed? _related;
  String? _relatedError;
  bool _relatedLoading = false;

  static bool _askedForNotifications = false;

  @override
  void initState() {
    super.initState();
    // Resolved here, not lazily: dispose() must not look up providers.
    _mediaSession = context.read<MediaSessionService>();
    _youtube = context.read<YoutubeExtractionService>();
    _settings = context.read<PlaybackSettings>();
    _networkMonitor = ConnectivityNetworkMonitor();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedState();
    if (!widget.immersive || widget.autoplay) {
      unawaited(_monitorNetwork());
      _open();
    }
    final id = widget.video.youtubeId;
    if (widget.video.isYoutube && !widget.video.isLocal && id != null && !widget.immersive) {
      _details = _youtube.details(id);
      _loadRelated();
    }
  }

  @override
  void didUpdateWidget(covariant WatchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoplay != widget.autoplay) {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        if (widget.autoplay) {
          unawaited(controller.play());
          unawaited(_attachMediaSession(controller));
        } else {
          unawaited(controller.pause());
          _mediaSession.detach(controller);
        }
      } else if (widget.autoplay && controller == null) {
        unawaited(_monitorNetwork());
        unawaited(_open());
      }
    }
  }

  int get _effectivePreferredHeight => _settings.preferredHeight > 0 ? _settings.preferredHeight : (_onWifi ? 0 : 360);

  Future<void> _monitorNetwork() async {
    try {
      _onWifi = await _networkMonitor.isOnWifi();
      if (_settings.preferredHeight == 0 && _qualities.isNotEmpty) unawaited(_applyNetworkQuality());
      _networkSubscription ??= _networkMonitor.onWifiChanged.listen((onWifi) {
        if (!mounted || _onWifi == onWifi) return;
        _onWifi = onWifi;
        if (_settings.preferredHeight == 0) unawaited(_applyNetworkQuality());
      });
    } catch (_) {
      // If network classification is unavailable, keep the conservative 360p Auto cap.
    }
  }

  Future<void> _applyNetworkQuality() async {
    if (!mounted || _settings.preferredHeight != 0 || _qualities.isEmpty) return;
    final next = pickPlaybackQuality(_qualities, _effectivePreferredHeight);
    if (next != null && next.key != _quality?.key) {
      _userPickedQuality = false;
      await _switchQuality(next, automatic: true);
    }
  }

  Future<void> _loadSavedState() async {
    try {
      final saved = await HomeLibraryService().isSaved(widget.video);
      if (mounted) setState(() => _saved = saved);
    } catch (_) {
      // The bookmark remains usable for this screen if local storage is unavailable.
    }
  }

  Future<void> _toggleSaved() async {
    final next = !_saved;
    setState(() => _saved = next);
    try {
      await HomeLibraryService().setSaved(widget.video, next);
    } catch (_) {
      if (mounted) setState(() => _saved = !next);
    }
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      await controller.setPlaybackSpeed(speed);
    }
    if (mounted) setState(() {});
  }

  Future<void> _setTemporaryDoubleSpeed(bool active) async {
    if (_temporaryDoubleSpeed == active) return;
    _temporaryDoubleSpeed = active;
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      await controller.setPlaybackSpeed(active ? 2.0 : _playbackSpeed);
    }
  }

  /// Background playback is always allowed at the player level so the setting
  /// can change at any time; when it is off the screen pauses on its own.
  static VideoPlayerOptions get _options => VideoPlayerOptions(allowBackgroundPlayback: true);

  VideoPlayerController _networkController(PlaybackQuality quality) => VideoPlayerController.networkUrl(
    quality.url,
    formatHint: quality.isHls ? VideoFormat.hls : null,
    videoPlayerOptions: _options,
  );

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    setState(() => _error = null);
    try {
      final video = widget.video;
      VideoPlayerController controller;
      PlaybackQuality? quality;
      if (video.isLocal) {
        final file = File(video.localPath!);
        if (!await file.exists()) throw const YoutubeServiceException('This file is no longer on the device.');
        controller = VideoPlayerController.file(file, videoPlayerOptions: _options);
        await controller.initialize();
      } else if (video.isYoutube) {
        final id = video.youtubeId!;
        var qualities = await _youtube.playbackQualities(id);
        if (qualities.isEmpty) {
          qualities = await _youtube.hlsQualities(id);
          _hdChecked = true;
        }
        quality = pickPlaybackQuality(qualities, _effectivePreferredHeight);
        if (quality == null) {
          throw const YoutubeServiceException(
            'Streaming is not available for this video, but you can still download it.',
          );
        }
        _qualities = qualities;
        controller = _networkController(quality);
        try {
          await controller.initialize();
        } catch (_) {
          // An HLS stream that won't open falls back to the progressive one.
          final fallback = qualities.where((q) => !q.isHls).firstOrNull;
          await controller.dispose();
          if (fallback == null || fallback == quality) rethrow;
          quality = fallback;
          controller = _networkController(fallback);
          await controller.initialize();
        }
      } else {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(video.playbackUrl ?? VideoModel.samplePlaybackUrl),
          videoPlayerOptions: _options,
        );
        await controller.initialize();
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setPlaybackSpeed(_playbackSpeed);
      unawaited(HomeLibraryService().addToHistory(video));
      controller.addListener(_onPlayerChanged);
      setState(() {
        _controller = controller;
        _quality = quality;
      });
      if (widget.autoplay) unawaited(_attachMediaSession(controller));
      if (widget.autoplay) {
        await controller.play();
        _scheduleHide();
      } else {
        await controller.pause();
      }
      if (_settings.preferredHeight == 0) unawaited(_applyNetworkQuality());
      if (video.isYoutube && !_hdChecked) unawaited(_findHdQualities(video.youtubeId!));
    } on YoutubeServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not play this video.');
    } finally {
      _opening = false;
    }
  }

  /// Looks for HLS streams above 360p after playback has started, and moves
  /// to the preferred quality once, unless the user already picked one.
  Future<void> _findHdQualities(String id) async {
    setState(() => _lookingForHd = true);
    final extra = await _youtube.hlsQualities(id);
    if (!mounted) return;
    setState(() {
      _hdChecked = true;
      _lookingForHd = false;
      _qualities = mergePlaybackQualities([..._qualities, ...extra]);
    });
    final current = _quality;
    if (_userPickedQuality || current == null) return;
    final best = pickPlaybackQuality(_qualities, _effectivePreferredHeight);
    if (best != null && best.height > current.height) await _switchQuality(best, automatic: true);
  }

  /// Opens [quality] in a new player while the current one keeps playing,
  /// then swaps them at the same position. Fullscreen, controls and the
  /// media session carry over; on failure the current stream stays.
  Future<void> _switchQuality(PlaybackQuality quality, {bool automatic = false}) async {
    final old = _controller;
    if (old == null || _switching || quality.key == _quality?.key) return;
    setState(() => _switching = true);
    final next = _networkController(quality);
    try {
      await next.initialize();
      if (!mounted || !identical(_controller, old)) {
        await next.dispose();
        return;
      }
      final wasPlaying = old.value.isPlaying;
      final position = old.value.position;
      await old.pause();
      await next.seekTo(position);
      await next.setPlaybackSpeed(_playbackSpeed);
      old.removeListener(_onPlayerChanged);
      next.addListener(_onPlayerChanged);
      setState(() {
        _controller = next;
        _quality = quality;
      });
      final hadSession = _mediaSession.isAttachedTo(old);
      if (hadSession) unawaited(_attachMediaSession(next));
      if (wasPlaying) await next.play();
      await old.dispose();
    } catch (_) {
      await next.dispose();
      if (mounted && !automatic) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${quality.label} could not be played here. Staying on ${_quality?.label}.')),
        );
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _attachMediaSession(VideoPlayerController controller) async {
    _attaching = true;
    try {
      if (!_askedForNotifications && Platform.isAndroid) {
        _askedForNotifications = true;
        try {
          await Permission.notification.request();
        } catch (_) {}
      }
      if (!identical(_controller, controller)) return;
      await _mediaSession.attach(
        controller,
        id: widget.video.id,
        title: widget.video.title,
        artist: widget.video.channelName,
        artUri: widget.video.thumbnailUrl,
      );
    } finally {
      _attaching = false;
    }
  }

  void _onPlayerChanged() {
    if (!mounted) return;
    final controller = _controller;
    // After "Stop" in the notification the session is released; starting
    // playback again from the app brings the notification back.
    if (controller != null &&
        controller.value.isPlaying &&
        !_attaching &&
        !_switching &&
        !_mediaSession.isAttachedTo(controller)) {
      unawaited(_attachMediaSession(controller));
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (!_settings.backgroundPlayback && controller.value.isPlaying) {
        _pausedForBackground = true;
        controller.pause();
      }
    } else if (state == AppLifecycleState.resumed && _pausedForBackground) {
      _pausedForBackground = false;
      controller.play();
    }
  }

  Future<void> _loadRelated() async {
    final id = widget.video.youtubeId!;
    setState(() {
      _relatedLoading = true;
      _relatedError = null;
    });
    try {
      final page = await _youtube.related(id);
      if (!mounted) return;
      setState(() => _related = PagedFeed(page));
    } on YoutubeServiceException catch (error) {
      if (mounted) setState(() => _relatedError = error.message);
    } catch (_) {
      if (mounted) setState(() => _relatedError = 'Could not load related videos.');
    } finally {
      if (mounted) setState(() => _relatedLoading = false);
    }
  }

  Future<void> _openRelated(VideoModel video) async {
    // Keep the current Watch route underneath so Back returns to this video.
    final router = GoRouter.of(context);
    final controller = _controller;
    final resumePrevious = controller?.value.isPlaying ?? false;
    if (resumePrevious) await controller!.pause();
    await router.push('/watch', extra: video);
    if (!mounted) return;
    if (resumePrevious && _controller?.value.isInitialized == true) {
      await _controller!.play();
    }
  }

  bool get _ended {
    final value = _controller?.value;
    if (value == null || !value.isInitialized || value.duration == Duration.zero) return false;
    return !value.isPlaying && value.position >= value.duration - const Duration(milliseconds: 300);
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    if (_ended) {
      await controller.seekTo(Duration.zero);
      await controller.play();
    } else if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    _scheduleHide();
  }

  Future<void> _seekBy(int seconds) async {
    final controller = _controller;
    if (controller == null) return;
    final target = controller.value.position + Duration(seconds: seconds);
    await controller.seekTo(target < Duration.zero ? Duration.zero : target);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    setState(() => _showControls = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) setState(() => _showControls = false);
    });
  }

  Future<void> _toggleFullscreen() async {
    final enter = !_fullscreen;
    setState(() => _fullscreen = enter);
    if (enter) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      await _restoreSystemUi();
    }
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  Future<void> _openPlaybackSettings() async {
    _hideTimer?.cancel();
    final picked = await showModalBottomSheet<PlaybackQuality>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: _settings,
        builder: (sheetContext, _) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8),
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text('Auto (network-aware)'),
                  subtitle: Text(
                    _onWifi ? 'Unmetered connection: best available quality' : 'Metered connection: prefer 360p',
                  ),
                  trailing: _settings.preferredHeight == 0 ? const Icon(Icons.check_rounded) : null,
                  onTap: () async {
                    await _settings.setPreferredHeight(0);
                    if (!sheetContext.mounted) return;
                    _userPickedQuality = false;
                    Navigator.pop(sheetContext);
                  },
                ),
                if (_qualities.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Text('Quality', style: Theme.of(sheetContext).textTheme.titleLarge),
                  ),
                  for (final q in _qualities)
                    ListTile(
                      title: Text(q.label),
                      subtitle: Text(q.isHls ? 'Adaptive stream (HLS)' : 'MP4'),
                      trailing: q.key == _quality?.key
                          ? const Icon(Icons.check_rounded, color: AppColors.primaryStart)
                          : null,
                      onTap: () => Navigator.pop(sheetContext, q),
                    ),
                  if (_lookingForHd)
                    ListTile(
                      leading: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      title: Text(
                        'Looking for higher qualities...',
                        style: TextStyle(color: sheetContext.textSecondary),
                      ),
                    )
                  else if (_qualities.every((q) => q.height <= 360))
                    ListTile(
                      leading: Icon(Icons.info_outline_rounded, color: sheetContext.textSecondary),
                      title: Text(
                        'YouTube only offers this quality for streaming here. Downloads can go higher.',
                        style: TextStyle(color: sheetContext.textSecondary, fontSize: 13),
                      ),
                    ),
                  const Divider(),
                ],
                SwitchListTile(
                  title: const Text('Play in background'),
                  subtitle: const Text('Keep playing with the screen off or in another app'),
                  value: _settings.backgroundPlayback,
                  onChanged: _settings.setBackgroundPlayback,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    _scheduleHide();
    if (picked == null) {
      if (_settings.preferredHeight == 0) await _applyNetworkQuality();
      return;
    }
    _userPickedQuality = true;
    unawaited(_settings.setPreferredHeight(picked.height));
    await _switchQuality(picked);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _networkSubscription?.cancel();
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onPlayerChanged);
      _mediaSession.detach(controller);
      controller.dispose();
    }
    _related?.dispose();
    if (_fullscreen) _restoreSystemUi();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player();
    if (widget.immersive && !_fullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: player),
      );
    }
    if (_fullscreen) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _toggleFullscreen();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: player),
        ),
      );
    }
    final video = widget.video;
    return Scaffold(
      appBar: AppBar(title: Text(video.isLocal ? 'Offline' : 'Watch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(20), child: player),
            const SizedBox(height: 16),
            Text(
              video.title,
              style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              [video.channelName, video.metaLine].where((s) => s.isNotEmpty).join(' • '),
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (!video.isLocal)
                  ActionChip(
                    label: const Text('Download'),
                    avatar: const Icon(Icons.download_rounded, size: 18),
                    onPressed: () => showDownloadOptionsSheet(context, video),
                  ),
                ActionChip(
                  label: Text(_saved ? 'Saved' : 'Save'),
                  avatar: Icon(_saved ? Icons.bookmark : Icons.bookmark_border, size: 18),
                  onPressed: _toggleSaved,
                ),
              ],
            ),
            if (!video.isYoutube && !video.isLocal) ...[
              const SizedBox(height: 20),
              Text(
                'This is a sample video. Open a YouTube video to stream or download it.',
                style: TextStyle(color: context.textSecondary),
              ),
            ],
            if (_details != null) ...[
              const SizedBox(height: 16),
              FutureBuilder<VideoDetails>(
                future: _details,
                builder: (context, snapshot) {
                  if (snapshot.hasData) return VideoDescription(details: snapshot.data!);
                  if (snapshot.hasError) return const SizedBox.shrink();
                  return const LinearProgressIndicator(minHeight: 2);
                },
              ),
            ],
            if (video.isYoutube && !video.isLocal) _relatedSection(),
          ],
        ),
      ),
    );
  }

  Widget _relatedSection() {
    final related = _related;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Related videos',
          style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (_relatedLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_relatedError != null)
          Row(
            children: [
              Expanded(
                child: Text(_relatedError!, style: TextStyle(color: context.textSecondary)),
              ),
              TextButton(onPressed: _loadRelated, child: const Text('Retry')),
            ],
          )
        else if (related != null)
          ListenableBuilder(
            listenable: related,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (related.isEmpty && !related.hasMore)
                  Text('No related videos found.', style: TextStyle(color: context.textSecondary)),
                for (final v in related.items) CompactVideoTile(video: v, onTap: () => _openRelated(v)),
                if (related.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (related.error != null)
                  TextButton(onPressed: related.loadMore, child: Text('${related.error} Retry'))
                else if (related.hasMore)
                  TextButton(onPressed: related.loadMore, child: const Text('Show more')),
              ],
            ),
          ),
      ],
    );
  }

  Widget _player() {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final aspect = ready && controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 16 / 9;
    return AspectRatio(
      aspectRatio: aspect,
      child: ColoredBox(
        color: Colors.black,
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _open, child: const Text('Try again')),
                    ],
                  ),
                ),
              )
            : !ready
            ? const Center(child: CircularProgressIndicator())
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showControls ? setState(() => _showControls = false) : _scheduleHide(),
                onLongPressStart: (_) => _setTemporaryDoubleSpeed(true),
                onLongPressEnd: (_) => _setTemporaryDoubleSpeed(false),
                onLongPressCancel: () => _setTemporaryDoubleSpeed(false),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(controller),
                    if (controller.value.isBuffering) const Center(child: CircularProgressIndicator()),
                    AnimatedOpacity(
                      opacity: _showControls || !controller.value.isPlaying ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: _controls(controller),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _controls(VideoPlayerController controller) {
    final value = controller.value;
    return Container(
      color: Colors.black38,
      child: Column(
        children: [
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Back 10 seconds',
                iconSize: 34,
                color: Colors.white,
                onPressed: () => _seekBy(-10),
                icon: const Icon(Icons.replay_10_rounded),
              ),
              const SizedBox(width: 16),
              IconButton.filled(
                tooltip: _ended ? 'Replay' : (value.isPlaying ? 'Pause' : 'Play'),
                iconSize: 42,
                onPressed: _togglePlay,
                icon: Icon(_ended ? Icons.replay_rounded : (value.isPlaying ? Icons.pause : Icons.play_arrow)),
              ),
              const SizedBox(width: 16),
              IconButton(
                tooltip: 'Forward 10 seconds',
                iconSize: 34,
                color: Colors.white,
                onPressed: () => _seekBy(10),
                icon: const Icon(Icons.forward_10_rounded),
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  '${_fmt(value.position)} / ${_fmt(value.duration)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Spacer(),
                if (_switching)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                PopupMenuButton<double>(
                  tooltip: 'Playback speed',
                  initialValue: _playbackSpeed,
                  onSelected: _setPlaybackSpeed,
                  itemBuilder: (context) => [
                    for (final speed in [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
                      PopupMenuItem(value: speed, child: Text('${speed}x')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _temporaryDoubleSpeed ? '2x' : '${_playbackSpeed}x',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _openPlaybackSettings,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.settings_rounded, size: 20),
                  label: Text(_quality?.label ?? 'Settings', style: const TextStyle(fontSize: 12)),
                ),
                IconButton(
                  tooltip: _fullscreen ? 'Exit fullscreen' : 'Fullscreen',
                  color: Colors.white,
                  onPressed: _toggleFullscreen,
                  icon: Icon(_fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
                ),
              ],
            ),
          ),
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            colors: const VideoProgressColors(playedColor: AppColors.primaryStart, bufferedColor: Colors.white38),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) => YoutubeExtractionService.formatDuration(d);
}
