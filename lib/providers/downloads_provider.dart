import 'dart:io';

import 'package:flutter/material.dart';

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
    _items.removeWhere((existing) => existing.id == item.id);
    _items.insert(0, item);
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (!_items.any((item) => item.id == id)) return;
    if (!_selectedIds.add(id)) _selectedIds.remove(id);
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedIds.isEmpty) return;
    _selectedIds.clear();
    notifyListeners();
  }

  /// Removes selected records without deleting their files.
  void removeSelected() {
    _items.removeWhere((item) => _selectedIds.contains(item.id));
    _selectedIds.clear();
    notifyListeners();
  }

  Future<bool> deleteFileFor(DownloadEntry item) async {
    try {
      final path = item.savedPath.trim();
      if (path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      _items.removeWhere((entry) => entry.id == item.id);
      _selectedIds.remove(item.id);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> deleteSelectedFiles() async {
    final selected = _items
        .where((item) => _selectedIds.contains(item.id))
        .toList(growable: false);
    var removed = 0;
    for (final item in selected) {
      if (await deleteFileFor(item)) removed++;
    }
    _selectedIds.removeWhere((id) => !_items.any((item) => item.id == id));
    notifyListeners();
    return removed;
  }
}
