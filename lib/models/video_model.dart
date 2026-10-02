class VideoModel {
  const VideoModel({
    required this.id,
    required this.title,
    required this.channelName,
    required this.views,
    required this.duration,
    required this.thumbnailUrl,
    required this.channelAvatar,
    required this.isVerified,
  });

  final String id;
  final String title;
  final String channelName;
  final String views;
  final String duration;
  final String thumbnailUrl;
  final String channelAvatar;
  final bool isVerified;

  static const demo = VideoModel(
    id: 'demo1',
    title: 'Tube Arena Launch Demo - Build an app that feels exactly like YouTube',
    channelName: 'Tube Arena',
    views: '2.4M views',
    duration: '12:45',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?auto=format&fit=crop&w=1200&q=80',
    channelAvatar:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80',
    isVerified: true,
  );
}
