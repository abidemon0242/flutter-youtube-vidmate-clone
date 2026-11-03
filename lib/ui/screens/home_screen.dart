  List<VideoModel> get videos {
    final allVideos = repository.getTrendingVideos();
    final category = repository.getCategories()[selectedCategory];
    final categoryVideos = category == 'All'
        ? allVideos
        : allVideos.where((video) => video.category == category).toList();
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return categoryVideos;
    return categoryVideos.where((video) =>
      video.title.toLowerCase().contains(query) ||
      video.channelName.toLowerCase().contains(query),
    ).toList();
  }
