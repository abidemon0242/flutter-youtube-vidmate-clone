/// A video shown in the feed or opened in the player.
///
/// Feed items from YouTube carry a [youtubeId]; sample items used when YouTube
/// cannot be reached have no [youtubeId] and play [playbackUrl] directly.
/// Local library files set [localPath] and play from disk.
class VideoModel {
  const VideoModel({
    required this.id,
    required this.title,
    required this.channelName,
    this.views = '',
    this.duration = '',
    this.thumbnailUrl = '',
    this.channelAvatar = '',
    this.isVerified = false,
    this.category = 'Tech',
    this.published = '',
    this.youtubeId,
    this.playbackUrl,
    this.localPath,
  });

  static const String samplePlaybackUrl = 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4';

  final String id;
  final String title;
  final String channelName;
  final String views;
  final String duration;
  final String thumbnailUrl;
  final String channelAvatar;
  final bool isVerified;
  final String category;

  /// Human readable upload time, e.g. "3 days ago". Empty when unknown.
  final String published;

  /// 11-character YouTube video ID, when this item comes from YouTube.
  final String? youtubeId;

  /// Direct playback URL for sample (non-YouTube) items.
  final String? playbackUrl;

  /// Absolute path of a downloaded file for offline playback.
  final String? localPath;

  bool get isYoutube => youtubeId != null && youtubeId!.isNotEmpty;
  bool get isLocal => localPath != null && localPath!.isNotEmpty;

  /// Secondary line under a title, skipping parts that are unknown.
  String get metaLine => [views, published].where((part) => part.trim().isNotEmpty).join(' · ');

  factory VideoModel.local({required String path, required String title}) =>
      VideoModel(id: 'local:$path', title: title, channelName: 'On this device', localPath: path);

  static const demo = VideoModel(
    id: 'demo1',
    title: 'Tube Arena sample video',
    channelName: 'Tube Arena',
    views: 'Sample',
    duration: '00:05',
    thumbnailUrl: 'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?auto=format&fit=crop&w=1200&q=80',
    channelAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80',
    isVerified: true,
    playbackUrl: samplePlaybackUrl,
  );
}
