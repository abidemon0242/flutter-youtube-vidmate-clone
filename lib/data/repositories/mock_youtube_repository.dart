import 'package:flutter/material.dart';

import '../models/video_model.dart';

class MockYouTubeRepository {
  List<VideoModel> getTrendingVideos() {
    return [
      const VideoModel(
        id: 'v1',
        title: 'Top 10 hidden features in Android apps that developers do not show',
        channelName: 'AppFlow',
        views: '1.9M views',
        duration: '08:11',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=1200&q=80',
        channelAvatar:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
        isVerified: true,
      ),
      const VideoModel(
        id: 'v2',
        title: 'How to build a beautiful modern dashboard in Flutter in 20 minutes',
        channelName: 'Flutter Craft',
        views: '845K views',
        duration: '14:02',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1522542550221-31fd19575a2d?auto=format&fit=crop&w=1200&q=80',
        channelAvatar:
            'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=200&q=80',
        isVerified: false,
      ),
      const VideoModel(
        id: 'v3',
        title: 'Mastering Figma for mobile product design with real workflow tips',
        channelName: 'Design Lens',
        views: '3.1M views',
        duration: '18:34',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80',
        channelAvatar:
            'https://images.unsplash.com/photo-1521119989659-a83eee488004?auto=format&fit=crop&w=200&q=80',
        isVerified: true,
      ),
      const VideoModel(
        id: 'v4',
        title: 'How to organize files, folders, and downloads for a clean media library',
        channelName: 'Tube Arena Docs',
        views: '520K views',
        duration: '09:50',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&w=1200&q=80',
        channelAvatar:
            'https://images.unsplash.com/photo-1504593811423-6dd665756598?auto=format&fit=crop&w=200&q=80',
        isVerified: true,
      ),
    ];
  }

  List<String> getCategories() {
    return [
      'All',
      'Music',
      'Tech',
      'Movies',
      'Tutorials',
      'Live',
      'News',
      'Gaming',
      'Design',
    ];
  }
}
