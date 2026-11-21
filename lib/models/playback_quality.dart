/// One streamable quality of a YouTube video for the in-app player.
///
/// video_player (ExoPlayer) can only play a single URL that already contains
/// both audio and video. YouTube offers two kinds of those:
/// - progressive MP4 ("muxed"), normally only 360p, seekable instantly;
/// - HLS variant playlists with audio, often up to 1080p, available from
///   some YouTube clients only.
class PlaybackQuality {
  const PlaybackQuality({
    required this.height,
    required this.url,
    this.fps = 30,
    this.isHls = false,
    this.tag = 0,
    this.bitrate = 0,
  });

  /// Vertical resolution class: 144, 240, 360, 480, 720, 1080, ...
  final int height;
  final int fps;
  final Uri url;
  final bool isHls;
  final int tag;

  /// Bits per second, used to pick between streams with the same label.
  final int bitrate;

  /// High frame rate streams get their rate in the label, like YouTube does.
  String get label => fps > 30 ? '${height}p$fps' : '${height}p';

  String get key => '${isHls ? 'hls' : 'mp4'}-$tag-$label';

  String get detail => isHls ? 'HLS' : 'MP4';

  @override
  String toString() => 'PlaybackQuality($label, $detail, tag $tag)';
}

/// Removes duplicates (one entry per label) and sorts best first.
///
/// For the same label a progressive stream wins over HLS because it starts
/// and seeks faster; between equals the higher bitrate wins.
List<PlaybackQuality> mergePlaybackQualities(Iterable<PlaybackQuality> candidates) {
  final byLabel = <String, PlaybackQuality>{};
  for (final q in candidates) {
    if (q.height <= 0) continue;
    final current = byLabel[q.label];
    if (current == null || (current.isHls && !q.isHls) || (current.isHls == q.isHls && q.bitrate > current.bitrate)) {
      byLabel[q.label] = q;
    }
  }
  return byLabel.values.toList()..sort((a, b) {
    final byHeight = b.height.compareTo(a.height);
    return byHeight != 0 ? byHeight : b.fps.compareTo(a.fps);
  });
}

/// The quality to start with: the best one not above [preferredHeight]
/// (0 means "best available"), or the lowest one when everything is above it.
PlaybackQuality? pickPlaybackQuality(List<PlaybackQuality> qualities, int preferredHeight) {
  if (qualities.isEmpty) return null;
  final sorted = mergePlaybackQualities(qualities);
  if (preferredHeight <= 0) return sorted.first;
  for (final q in sorted) {
    if (q.height <= preferredHeight) return q;
  }
  return sorted.last;
}

/// Parses "720p60", "1080p HDR" or "360p" into (height, fps).
({int height, int fps})? parseQualityLabel(String label, {int fallbackFps = 30}) {
  final match = RegExp(r'^(\d+)p(\d+)?').firstMatch(label.trim());
  if (match == null) return null;
  final height = int.parse(match.group(1)!);
  final fps = int.tryParse(match.group(2) ?? '') ?? fallbackFps;
  return (height: height, fps: fps);
}
