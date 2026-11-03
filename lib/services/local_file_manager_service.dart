import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class LocalFile {
  LocalFile({
    required this.path,
    required this.name,
    required this.size,
    required this.createdAt,
    required this.isDirectory,
  });

  final String path;
  final String name;
  final int size;
  final DateTime createdAt;
  final bool isDirectory;

  String get sizeFormatted {
    const units = ['B', 'KB', 'MB', 'GB'];
    var bytes = size.toDouble();
    var unitIndex = 0;
    while (bytes >= 1024 && unitIndex < units.length - 1) {
      bytes /= 1024;
      unitIndex++;
    }
    return '${bytes.toStringAsFixed(2)} ${units[unitIndex]}';
  }
}

class LocalFileManagerService {
  static final LocalFileManagerService _instance =
      LocalFileManagerService._internal();

  final Logger logger = Logger();
  Directory? _baseDirectory;
  Future<void>? _initializing;

  factory LocalFileManagerService() => _instance;

  LocalFileManagerService._internal();

  Future<void> initialize() async {
    if (_baseDirectory != null) return;
    final pending = _initializing;
    if (pending != null) return pending;

    final initialization = _initialize();
    _initializing = initialization;
    try {
      await initialization;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initialize() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/TubeArena');
    await directory.create(recursive: true);
    _baseDirectory = directory;
    logger.i('File manager initialized at: ${directory.path}');
  }

  Directory get _root {
    final directory = _baseDirectory;
    if (directory == null) {
      throw StateError('LocalFileManagerService has not been initialized');
    }
    return directory;
  }

  String? _validatedFolderName(String name) {
    final value = name.trim();
    if (value.isEmpty ||
        value == '.' ||
        value == '..' ||
        value.contains('/') ||
        value.contains(r'\\') ||
        value.contains('..')) {
      return null;
    }
    if (!RegExp(r'^[A-Za-z0-9 _-]{1,50}$').hasMatch(value)) return null;
    return value;
  }

  Future<bool> createFolder(String folderName) async {
    await initialize();
    final name = _validatedFolderName(folderName);
    if (name == null) return false;
    try {
      final folder = Directory('${_root.path}/$name');
      if (await folder.exists()) return false;
      await folder.create(recursive: true);
      return true;
    } catch (error) {
      logger.e('Error creating folder: $error');
      return false;
    }
  }

  Future<bool> deleteFolder(String folderName) async {
    await initialize();
    final name = _validatedFolderName(folderName);
    if (name == null) return false;
    try {
      final folder = Directory('${_root.path}/$name');
      if (!await folder.exists()) return false;
      await folder.delete(recursive: true);
      return true;
    } catch (error) {
      logger.e('Error deleting folder: $error');
      return false;
    }
  }

  Future<bool> renameFolder(String oldName, String newName) async {
    await initialize();
    final oldValue = _validatedFolderName(oldName);
    final newValue = _validatedFolderName(newName);
    if (oldValue == null || newValue == null || oldValue == newValue) {
      return false;
    }
    try {
      final oldFolder = Directory('${_root.path}/$oldValue');
      final newFolder = Directory('${_root.path}/$newValue');
      if (!await oldFolder.exists() || await newFolder.exists()) return false;
      await oldFolder.rename(newFolder.path);
      return true;
    } catch (error) {
      logger.e('Error renaming folder: $error');
      return false;
    }
  }

  Future<List<LocalFile>> getFolders() async {
    await initialize();
    try {
      final items = await _root.list(followLinks: false).toList();
      final folders = <LocalFile>[];
      for (final item in items.whereType<Directory>()) {
        final stat = await item.stat();
        folders.add(LocalFile(
          path: item.path,
          name: item.uri.pathSegments.where((part) => part.isNotEmpty).last,
          size: 0,
          createdAt: stat.modified,
          isDirectory: true,
        ));
      }
      folders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return folders;
    } catch (error) {
      logger.e('Error getting folders: $error');
      return [];
    }
  }

  Future<List<LocalFile>> getFilesInFolder(String folderName) async {
    await initialize();
    final name = _validatedFolderName(folderName);
    if (name == null) return [];
    try {
      final folder = Directory('${_root.path}/$name');
      if (!await folder.exists()) return [];
      final items = await folder.list(followLinks: false).toList();
      final files = <LocalFile>[];
      for (final item in items.whereType<File>()) {
        final stat = await item.stat();
        files.add(LocalFile(
          path: item.path,
          name: item.uri.pathSegments.last,
          size: stat.size,
          createdAt: stat.modified,
          isDirectory: false,
        ));
      }
      files.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return files;
    } catch (error) {
      logger.e('Error getting files in $name: $error');
      return [];
    }
  }

  Future<bool> moveFile(String filePath, String targetFolder) async {
    await initialize();
    final name = _validatedFolderName(targetFolder);
    if (name == null) return false;
    try {
      final source = File(filePath);
      if (!await source.exists()) return false;
      final target = Directory('${_root.path}/$name');
      await target.create(recursive: true);
      final destination = File('${target.path}/${source.uri.pathSegments.last}');
      if (await destination.exists()) return false;
      await source.rename(destination.path);
      return true;
    } catch (error) {
      logger.e('Error moving file: $error');
      return false;
    }
  }

  Future<bool> moveFilesInBatch(List<String> filePaths, String targetFolder) async {
    var allSuccessful = true;
    for (final filePath in filePaths) {
      if (!await moveFile(filePath, targetFolder)) allSuccessful = false;
    }
    return allSuccessful;
  }

  Future<bool> deleteFile(String filePath) async {
    await initialize();
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      await file.delete();
      return true;
    } catch (error) {
      logger.e('Error deleting file: $error');
      return false;
    }
  }

  Future<bool> deleteFilesInBatch(List<String> filePaths) async {
    var allSuccessful = true;
    for (final filePath in filePaths) {
      if (!await deleteFile(filePath)) allSuccessful = false;
    }
    return allSuccessful;
  }

  Future<int> getTotalStorageSize() async {
    await initialize();
    try {
      var totalSize = 0;
      await for (final item in _root.list(recursive: true, followLinks: false)) {
        if (item is File) totalSize += await item.length();
      }
      return totalSize;
    } catch (error) {
      logger.e('Error calculating storage size: $error');
      return 0;
    }
  }

  Future<bool> clearAllDownloads() async {
    await initialize();
    try {
      final downloads = Directory('${_root.path}/Downloads');
      if (!await downloads.exists()) return true;
      await downloads.delete(recursive: true);
      await downloads.create(recursive: true);
      return true;
    } catch (error) {
      logger.e('Error clearing downloads: $error');
      return false;
    }
  }
}
