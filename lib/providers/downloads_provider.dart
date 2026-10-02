import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DownloadEntry {
  DownloadEntry({
    required this.id,
    required this.title,
    required this.url,
    required this.size,
    required this.format,
    required this.progress,
    required this.savedPath,
    this.isAudioOnly = false,
  });

  final String id;
  final String title;
  final String url;
  final String size;
  final String format;
  final double progress;
  final String savedPath;
  final bool isAudioOnly;

  DownloadEntry copyWith({
    String? id,
    String? title,
    String? url,
    String? size,
    String? format,
    double? progress,
    String? savedPath,
    bool? isAudioOnly,
  }) {
    return DownloadEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      size: size ?? this.size,
      format: format ?? this.format,
      progress: progress ?? this.progress,
      savedPath: savedPath ?? this.savedPath,
      isAudioOnly: isAudioOnly ?? this.isAudioOnly,
    );
  }
}

class DownloadsProvider extends ChangeNotifier {
  final List<DownloadEntry> _items = [];
  final Set<String> _selectedIds = {};

  List<DownloadEntry> get items => List.unmodifiable(_items);
  List<String> get selectedIds => List.unmodifiable(_selectedIds.toList());
  bool get hasSelection => _selectedIds.isNotEmpty;

  void addDownload(DownloadEntry item) {
    _items.insert(0, item);
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  void removeSelected() {
    for (final id in List.from(_selectedIds)) {
      _items.removeWhere((item) => item.id == id);
    }
    _selectedIds.clear();
    notifyListeners();
  }

  void deleteFileFor(DownloadEntry item) {
    final file = File(item.savedPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    _items.removeWhere((entry) => entry.id == item.id);
    _selectedIds.remove(item.id);
    notifyListeners();
  }
}
