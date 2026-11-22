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
  Future<void>? _ready;

  static const downloadsFolderName = 'Downloads';

  /// App-managed media folders cannot be renamed or deleted.
  static const _builtInFolders = {'downloads', 'videos', 'audio', 'shorts', 'important shorts'};
  static bool isProtectedFolder(String name) => _builtInFolders.contains(name.trim().toLowerCase());

  static const _hiddenSuffixes = ['.part', '.tmp', '.json'];

  factory LocalFileManagerService() {
    return _instance;
  }

  LocalFileManagerService._internal();

  /// A separate instance rooted at [baseDirectory] (the TubeArena folder).
  /// Used by tests; the app uses the shared default instance.
  LocalFileManagerService.withBaseDirectory(Directory baseDirectory) {
    _ready = () async {
      await Directory('${baseDirectory.path}/$downloadsFolderName').create(recursive: true);
      _baseDirectory = baseDirectory;
    }();
  }

  /// Initialize file manager with base directory. Safe to call repeatedly;
  /// every public method waits for it, so nothing runs before it is ready.
  Future<void> initialize() => _ready ??= _initialize();

  Future<void> _initialize() async {
    try {
      logger.i('Initializing LocalFileManagerService...');
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final tubeArenaDir = Directory('${documentsDirectory.path}/TubeArena');
      await tubeArenaDir.create(recursive: true);
      await Directory('${tubeArenaDir.path}/$downloadsFolderName').create(recursive: true);
      _baseDirectory = tubeArenaDir;
      logger.i('Tube Arena base directory is ready');
      logger.i('File manager initialized at: ${_baseDirectory.path}');
    } catch (e) {
      logger.e('Error initializing file manager: $e');
      _ready = null; // allow a later retry
      rethrow;
    }
  }

  Future<bool> _isManagedDirectory(Directory directory) async {
    final basePath = await _baseDirectory.resolveSymbolicLinks();
    final targetPath = await directory.resolveSymbolicLinks();
    return targetPath.startsWith('$basePath${Platform.pathSeparator}');
  }

  String? _validatedFolderName(String name) {
    final value = name.trim();
    if (value.isEmpty ||
        value == '.' ||
        value == '..' ||
        value.contains('/') ||
        value.contains('\\') ||
        value.contains(RegExp(r'[\x00-\x1F]'))) {
      return null;
    }
    return value;
  }

  /// Create a custom folder
  Future<bool> createFolder(String folderName) async {
    try {
      await initialize();
      final safeName = _validatedFolderName(folderName);
      if (safeName == null || isProtectedFolder(safeName)) return false;
      final folder = Directory('${_baseDirectory.path}/$safeName');
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
      await initialize();
      final safeName = _validatedFolderName(folderName);
      if (safeName == null || isProtectedFolder(safeName)) return false;
      final folder = Directory('${_baseDirectory.path}/$safeName');
      if (folder.existsSync() && await _isManagedDirectory(folder)) {
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
      await initialize();
      final safeOldName = _validatedFolderName(oldName);
      final safeNewName = _validatedFolderName(newName);
      if (safeOldName == null ||
          safeNewName == null ||
          safeOldName == safeNewName ||
          isProtectedFolder(safeOldName) ||
          isProtectedFolder(safeNewName)) {
        return false;
      }
      final oldFolder = Directory('${_baseDirectory.path}/$safeOldName');
      final newFolder = Directory('${_baseDirectory.path}/$safeNewName');

      if (oldFolder.existsSync() && await _isManagedDirectory(oldFolder) && !newFolder.existsSync()) {
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
      await initialize();
      final items = await _baseDirectory.list(followLinks: false).toList();
      final folders = <LocalFile>[];
      for (final item in items.whereType<Directory>()) {
        if (!await _isManagedDirectory(item)) continue;
        final stat = item.statSync();
        folders.add(
          LocalFile(
            path: item.path,
            name: item.path.split(Platform.pathSeparator).last,
            size: 0,
            createdAt: stat.modified,
            isDirectory: true,
          ),
        );
      }

      // Built-in folders first, with Downloads as the primary folder.
      folders.sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        if (aName == bName) return 0;
        if (aName == 'downloads') return -1;
        if (bName == 'downloads') return 1;
        final aBuiltIn = isProtectedFolder(a.name);
        final bBuiltIn = isProtectedFolder(b.name);
        if (aBuiltIn != bBuiltIn) return aBuiltIn ? -1 : 1;
        return aName.compareTo(bName);
      });
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
      await initialize();
      final safeName = _validatedFolderName(folderName);
      if (safeName == null) return [];
      final folder = Directory('${_baseDirectory.path}/$safeName');
      if (!folder.existsSync() || !await _isManagedDirectory(folder)) {
        return [];
      }

      final items = await folder.list(followLinks: false).toList();
      final files = <LocalFile>[];
      for (final item in items.whereType<File>()) {
        final name = item.uri.pathSegments.last;
        if (name.startsWith('.') || _hiddenSuffixes.any(name.endsWith)) continue;
        final stat = await item.stat();
        files.add(
          LocalFile(path: item.path, name: name, size: stat.size, createdAt: stat.modified, isDirectory: false),
        );
      }
      files.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      logger.i('Found ${files.length} files in $folderName');
      return files;
    } catch (e) {
      logger.e('Error getting files: $e');
      return [];
    }
  }

  /// Move file to different folder
  Future<bool> moveFile(String filePath, String targetFolder) async => await moveFileTo(filePath, targetFolder) != null;

  /// Moves a Library file into [targetFolder] (created if missing) and
  /// returns its new path, or null when it can't be moved. A name that is
  /// already taken in the target folder gets a " (2)" style suffix.
  Future<String?> moveFileTo(String filePath, String targetFolder) async {
    try {
      await initialize();
      final safeTarget = _validatedFolderName(targetFolder);
      if (safeTarget == null) return null;
      final file = File(filePath);
      if (!await file.exists()) return null;
      final basePath = await _baseDirectory.resolveSymbolicLinks();
      final sourcePath = await file.resolveSymbolicLinks();
      if (!sourcePath.startsWith('$basePath${Platform.pathSeparator}')) return null;
      final target = Directory('${_baseDirectory.path}/$safeTarget');
      await target.create(recursive: true);
      if (!await _isManagedDirectory(target)) return null;
      final targetPath = await target.resolveSymbolicLinks();
      if (file.parent.absolute.path == target.absolute.path || File(sourcePath).parent.path == targetPath) {
        return null;
      }
      final fileName = file.uri.pathSegments.last;
      final dot = fileName.lastIndexOf('.');
      final base = dot > 0 ? fileName.substring(0, dot) : fileName;
      final extension = dot > 0 ? fileName.substring(dot) : '';
      var newPath = '${target.path}/$fileName';
      for (var n = 2; await File(newPath).exists(); n++) {
        newPath = '${target.path}/$base ($n)$extension';
      }
      try {
        await file.rename(newPath);
      } on FileSystemException {
        // Different volume: fall back to copy + delete.
        await file.copy(newPath);
        await file.delete();
      }
      logger.i('File moved: $filePath -> $newPath');
      return newPath;
    } catch (e) {
      logger.e('Error moving file: $e');
      return null;
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
      await initialize();
      final file = File(filePath);
      if (await file.exists()) {
        final basePath = await _baseDirectory.resolveSymbolicLinks();
        final filePathResolved = await file.resolveSymbolicLinks();
        final allowedPrefix = '$basePath${Platform.pathSeparator}';
        if (!filePathResolved.startsWith(allowedPrefix)) {
          logger.w('Refusing to delete a file outside the Tube Arena library.');
          return false;
        }
        await file.delete();
        logger.i('File deleted from library: $filePathResolved');
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
      await initialize();
      final downloadsDirectory = Directory('${_baseDirectory.path}/Downloads');
      if (!await downloadsDirectory.exists() || !await _isManagedDirectory(downloadsDirectory)) {
        return 0;
      }
      final items = downloadsDirectory.listSync(recursive: true, followLinks: false);
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
      await initialize();
      final downloadsDirectory = Directory('${_baseDirectory.path}/Downloads');
      if (!await downloadsDirectory.exists()) return true;
      if (!await _isManagedDirectory(downloadsDirectory)) return false;
      final items = downloadsDirectory.listSync(followLinks: false);
      for (final item in items) {
        if (item is Directory) {
          await item.delete(recursive: true);
        } else if (item is File || item is Link) {
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
