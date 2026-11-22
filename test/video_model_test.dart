import 'package:flutter_test/flutter_test.dart';
import 'package:tube_arena/models/video_model.dart';

void main() {
  test('VideoModel JSON round-trip preserves stable channel ID', () {
    const video = VideoModel(
      id: 'video-1',
      title: 'Example upload',
      channelName: 'Example Creator',
      youtubeId: 'abcdefghijk',
      channelId: 'UC1234567890',
    );

    final restored = VideoModel.fromJson(video.toJson());
    expect(restored.youtubeId, 'abcdefghijk');
    expect(restored.channelId, 'UC1234567890');
    expect(restored.channelName, 'Example Creator');
  });

  test('old serialized videos without channel ID remain readable', () {
    final restored = VideoModel.fromJson({
      'id': 'old-video',
      'title': 'Older saved video',
      'channelName': 'Creator',
      'youtubeId': 'abcdefghijk',
    });
    expect(restored.channelId, isNull);
  });
}
