import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/ad_blocker_service.dart';
import '../../services/background_download_service.dart';
import '../../services/media_session_service.dart';

class DownloadQualityModal extends StatefulWidget {
  const DownloadQualityModal({
    super.key,
    required this.videoTitle,
    required this.onDownloadAudio,
    required this.onDownloadVideo,
  });

  final String videoTitle;
  final Function(String format, String bitrate) onDownloadAudio;
  final Function(String quality, String format) onDownloadVideo;

  @override
  State<DownloadQualityModal> createState() => _DownloadQualityModalState();
}

class _DownloadQualityModalState extends State<DownloadQualityModal> {
  String selectedTab = 'video';

  final audioOptions = [
    {'format': 'MP3', 'bitrate': '128 kbps', 'size': '2.8 MB'},
    {'format': 'MP3', 'bitrate': '192 kbps', 'size': '4.2 MB'},
    {'format': 'MP3', 'bitrate': '320 kbps', 'size': '7.1 MB'},
    {'format': 'M4A', 'bitrate': '128 kbps', 'size': '2.6 MB'},
    {'format': 'M4A', 'bitrate': '256 kbps', 'size': '5.2 MB'},
  ];

  final videoOptions = [
    {'quality': '360p', 'format': 'mp4', 'size': '5.3 MB', 'fps': '24'},
    {'quality': '480p', 'format': 'mp4', 'size': '9.4 MB', 'fps': '24'},
    {'quality': '720p', 'format': 'mp4', 'size': '18 MB', 'fps': '30'},
    {'quality': '1080p', 'format': 'mp4', 'size': '34 MB', 'fps': '30'},
    {'quality': '2K', 'format': 'mp4', 'size': '58 MB', 'fps': '60'},
    {'quality': '4K', 'format': 'mp4', 'size': '92 MB', 'fps': '60'},
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A2330),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Download Quality',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabButton('Video', 'video'),
                      const SizedBox(width: 8),
                      _buildTabButton('Audio', 'audio'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: selectedTab == 'video' ? videoOptions.length : audioOptions.length,
                  itemBuilder: (context, index) {
                    if (selectedTab == 'video') {
                      final option = videoOptions[index];
                      return _buildVideoOption(context, option);
                    } else {
                      final option = audioOptions[index];
                      return _buildAudioOption(context, option);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabButton(String label, String value) {
    final isSelected = selectedTab == value;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? const Color(0xFF1DA1F2) : const Color(0xFF202A38),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF9AA9BF),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoOption(BuildContext context, Map<String, String> option) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF202A38),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option['quality']!,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                '${option['size']} • ${option['fps']} fps',
                style: const TextStyle(color: Color(0xFF9AA9BF), fontSize: 12),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              widget.onDownloadVideo(option['quality']!, option['format']!);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DA1F2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioOption(BuildContext context, Map<String, String> option) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF202A38),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option['format']!,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                '${option['bitrate']} • ${option['size']}',
                style: const TextStyle(color: Color(0xFF9AA9BF), fontSize: 12),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              widget.onDownloadAudio(option['format']!, option['bitrate']!);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DA1F2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }
}
