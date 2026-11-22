import 'package:material_ui/material_ui.dart';

import '../models/video_model.dart';
import '../services/youtube_extraction_service.dart';

/// One page of videos and, when there are more, a way to fetch the next one.
class VideoPage {
  const VideoPage(this.videos, {this.loadNext});

  const VideoPage.last(this.videos) : loadNext = null;

  final List<VideoModel> videos;

  /// Fetches the following page; returns null when there are no more results.
  final Future<VideoPage?> Function()? loadNext;

  bool get hasNext => loadNext != null;
}

/// A growing list of videos for infinite scrolling.
///
/// Pages are appended without duplicates (YouTube often repeats items across
/// pages), concurrent [loadMore] calls are ignored, and a few pages in a row
/// that add nothing new are treated as the end of the results.
class PagedFeed extends ChangeNotifier {
  PagedFeed(VideoPage first) {
    _add(first.videos);
    _next = first.loadNext;
  }

  PagedFeed.fixed(List<VideoModel> videos) {
    _add(videos);
  }

  /// Pages without new videos fetched before giving up.
  static const maxEmptyPages = 3;

  final List<VideoModel> _items = [];
  final Set<String> _keys = {};
  Future<VideoPage?> Function()? _next;
  bool _loading = false;
  String? _error;
  bool _disposed = false;

  List<VideoModel> get items => List.unmodifiable(_items);
  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get hasMore => _next != null;
  bool get isLoading => _loading;

  /// Message of the last failed [loadMore]; cleared when retrying.
  String? get error => _error;

  /// True when the UI should fetch the next page on its own.
  bool get canAutoLoad => hasMore && !_loading && _error == null;

  static String _keyOf(VideoModel v) => v.isYoutube ? v.youtubeId! : v.id;

  int _add(Iterable<VideoModel> videos) {
    var added = 0;
    for (final video in videos) {
      if (_keys.add(_keyOf(video))) {
        _items.add(video);
        added++;
      }
    }
    return added;
  }

  Future<void> loadMore() async {
    if (_loading || _next == null || _disposed) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      var emptyPages = 0;
      while (_next != null) {
        final page = await _next!();
        if (_disposed) return;
        if (page == null) {
          _next = null;
          break;
        }
        _next = page.loadNext;
        if (_add(page.videos) > 0) break;
        if (++emptyPages >= maxEmptyPages) {
          _next = null;
          break;
        }
      }
    } on YoutubeServiceException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = 'Could not load more videos.';
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
