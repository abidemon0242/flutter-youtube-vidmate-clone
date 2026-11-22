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

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'channelName': channelName,
    'views': views,
    'duration': duration,
    'thumbnailUrl': thumbnailUrl,
    'channelAvatar': channelAvatar,
    'isVerified': isVerified,
    'category': category,
    'published': published,
    'youtubeId': youtubeId,
    'playbackUrl': playbackUrl,
    'localPath': localPath,
  };

  factory VideoModel.fromJson(Map<String, dynamic> json) => VideoModel(
    id: json['id'] as String,
    title: json['title'] as String,
    channelName: json['channelName'] as String,
    views: json['views'] as String? ?? '',
    duration: json['duration'] as String? ?? '',
    thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
    channelAvatar: json['channelAvatar'] as String? ?? '',
    isVerified: json['isVerified'] as bool? ?? false,
    category: json['category'] as String? ?? 'Tech',
    published: json['published'] as String? ?? '',
    youtubeId: json['youtubeId'] as String?,
    playbackUrl: json['playbackUrl'] as String?,
    localPath: json['localPath'] as String?,
  );

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
