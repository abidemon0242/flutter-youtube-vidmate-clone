import 'package:flutter_test/flutter_test.dart';
import 'package:tube_arena/services/background_download_service.dart';

void main() {
  group('Button-phone download metadata', () {
    test('persists compatibility mode and converting status', () {
      final task = AppDownloadTask(
        id: 'video-1',
        title: 'Test video',
        videoUrl: 'https://example.com/video',
        audioUrl: '',
        savePath: '/downloads/video.3gp',
        quality: '240p',
        format: '3GP H.263/AMR-NB',
        isAudioOnly: false,
        buttonPhoneCompatible: true,
        status: DownloadStatus.converting,
      );

      final restored = AppDownloadTask.fromJson(task.toJson());

      expect(restored.buttonPhoneCompatible, isTrue);
      expect(restored.status, DownloadStatus.converting);
      expect(restored.savePath, '/downloads/video.3gp');
    });

    test('keeps older download metadata compatible by default', () {
      final restored = AppDownloadTask.fromJson({
        'id': 'legacy-video',
        'title': 'Legacy video',
        'videoUrl': 'https://example.com/video',
        'audioUrl': '',
        'savePath': '/downloads/legacy.mp4',
        'quality': '240p',
        'format': 'MP4',
        'isAudioOnly': false,
      });

      expect(restored.buttonPhoneCompatible, isFalse);
    });
  });
}
