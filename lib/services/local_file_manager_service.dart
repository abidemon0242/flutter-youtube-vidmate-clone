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
  static final LocalFileManagerService _instance = LocalFileManagerService._internal();
  final logger = Logger();

  late Directory _baseDirectory;

  factory LocalFileManagerService() {
    return _instance;
  }

  LocalFileManagerService._internal();

  /// Initialize file manager with base directory
  Future<void> initialize() async {
    try {
      logger.i('Initializing LocalFileManagerService...');
      _baseDirectory = (await getApplicationDocumentsDirectory());
      final tubeArenaDir = Directory('${_baseDirectory.path}/TubeArena');

      if (!tubeArenaDir.existsSync()) {
        await tubeArenaDir.create(recursive: true);
        logger.i('Created Tube Arena base directory');
      }

      _baseDirectory = tubeArenaDir;
      logger.i('File manager initialized at: ${_baseDirectory.path}');
    } catch (e) {
      logger.e('Error initializing file manager: $e');
    }
  }

  /// Create a custom folder
  Future<bool> createFolder(String folderName) async {
    try {
      final folder = Directory('${_baseDirectory.path}/$folderName');
      if (!folder.existsSync()) {
        await folder.create(recursive: true);
        logger.i('Folder created: $folderName');
        return true;
      }
      return false;
    } catch (e) {
      logger.e('Error creating folder: $e');
      return false;
    }
  }

  /// Delete a folder
  Future<bool> deleteFolder(String folderName) async {
    try {
      final folder = Directory('${_baseDirectory.path}/$folderName');
      if (folder.existsSync()) {
        await folder.delete(recursive: true);
        logger.i('Folder deleted: $folderName');
        return true;
      }
      return false;
    } catch (e) {
      logger.e('Error deleting folder: $e');
      return false;
    }
  }

  /// Rename a folder
  Future<bool> renameFolder(String oldName, String newName) async {
    try {
      final oldFolder = Directory('${_baseDirectory.path}/$oldName');
      final newFolder = Directory('${_baseDirectory.path}/$newName');

      if (oldFolder.existsSync()) {
        await oldFolder.rename(newFolder.path);
        logger.i('Folder renamed: $oldName -> $newName');
        return true;
      }
      return false;
    } catch (e) {
      logger.e('Error renaming folder: $e');
      return false;
    }
  }

  /// Get all folders
  Future<List<LocalFile>> getFolders() async {
    try {
      final items = _baseDirectory.listSync();
      final folders = items
          .where((item) => item is Directory)
          .map((item) {
            final stat = item.statSync();
            return LocalFile(
              path: item.path,
              name: item.path.split('/').last,
              size: 0,
              createdAt: stat.modified,
              isDirectory: true,
            );
          })
          .toList();

      logger.i('Found ${folders.length} folders');
      return folders;
    } catch (e) {
      logger.e('Error getting folders: $e');
      return [];
    }
  }

  /// Get files in a folder
  Future<List<LocalFile>> getFilesInFolder(String folderName) async {
    try {
      final folder = Directory('${_baseDirectory.path}/$folderName');
      if (!folder.existsSync()) {
        return [];
      }

      final items = folder.listSync();
      final files = items
          .where((item) => item is File)
          .map((item) {
            final stat = item.statSync();
            return LocalFile(
              path: item.path,
              name: item.path.split('/').last,
              size: stat.size,
              createdAt: stat.modified,
              isDirectory: false,
            );
          })
          .toList();

      logger.i('Found ${files.length} files in $folderName');
      return files;
    } catch (e) {
      logger.e('Error getting files: $e');
      return [];
    }
  }

  /// Move file to different folder
  Future<bool> moveFile(String filePath, String targetFolder) async {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        final fileName = filePath.split('/').last;
        final newPath = '${_baseDirectory.path}/$targetFolder/$fileName';
        await file.rename(newPath);
        logger.i('File moved: $filePath -> $newPath');
        return true;
      }
      return false;
    } catch (e) {
      logger.e('Error moving file: $e');
      return false;
    }
  }

  /// Move multiple files to folder
  Future<bool> moveFilesInBatch(List<String> filePaths, String targetFolder) async {
    try {
      bool allSuccessful = true;
      for (final filePath in filePaths) {
        final success = await moveFile(filePath, targetFolder);
        if (!success) allSuccessful = false;
      }
      logger.i('Batch move completed. Success: $allSuccessful');
      return allSuccessful;
    } catch (e) {
      logger.e('Error in batch move: $e');
      return false;
    }
  }

  /// Delete a file
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        await file.delete();
        logger.i('File deleted: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      logger.e('Error deleting file: $e');
      return false;
    }
  }

  /// Delete multiple files
  Future<bool> deleteFilesInBatch(List<String> filePaths) async {
    try {
      bool allSuccessful = true;
      for (final filePath in filePaths) {
        final success = await deleteFile(filePath);
        if (!success) allSuccessful = false;
      }
      logger.i('Batch delete completed. Success: $allSuccessful');
      return allSuccessful;
    } catch (e) {
      logger.e('Error in batch delete: $e');
      return false;
    }
  }

  /// Get total storage size of all downloaded files
  Future<int> getTotalStorageSize() async {
    try {
      final items = _baseDirectory.listSync(recursive: true, followLinks: false);
      int totalSize = 0;
      for (final item in items) {
        if (item is File) {
          totalSize += item.lengthSync();
        }
      }
      logger.i('Total storage size: ${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB');
      return totalSize;
    } catch (e) {
      logger.e('Error calculating storage size: $e');
      return 0;
    }
  }

  /// Clear all downloads
  Future<bool> clearAllDownloads() async {
    try {
      final items = _baseDirectory.listSync();
      for (final item in items) {
        if (item is Directory) {
          await item.delete(recursive: true);
        } else if (item is File) {
          await item.delete();
        }
      }
      logger.i('All downloads cleared');
      return true;
    } catch (e) {
      logger.e('Error clearing downloads: $e');
      return false;
    }
  }
}
