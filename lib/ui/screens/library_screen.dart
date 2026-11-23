import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/video_model.dart';
import '../../providers/downloads_provider.dart';
import '../../services/device_storage_service.dart';
import '../../services/local_file_manager_service.dart';
import '../widgets/file_actions.dart';
import '../widgets/folder_card.dart';
import '../widgets/theme_mode_button.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final LocalFileManagerService _files = context.read<LocalFileManagerService>();
  late final DownloadsProvider _downloads = context.read<DownloadsProvider>();
  List<String> _folders = [];
  final Map<String, int> _counts = {};
  final Set<String> _selected = {};
  bool _loading = true;
  int _completedSeen = -1;

  @override
  void initState() {
    super.initState();
    _downloads.addListener(_onDownloadsChanged);
    _load();
  }

  @override
  void dispose() {
    _downloads.removeListener(_onDownloadsChanged);
    super.dispose();
  }

  // Refresh file counts when a download finishes or is deleted.
  void _onDownloadsChanged() {
    final completed = _downloads.items.where((e) => e.status == DownloadStatus.completed).length;
    if (completed != _completedSeen) {
      _completedSeen = completed;
      _load();
    }
  }

  Future<void> _load() async {
    final items = await _files.getFolders();
    final counts = <String, int>{};
    for (final folder in items) {
      counts[folder.name] = (await _files.getFilesInFolder(folder.name)).length;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _folders = items.map((item) => item.name).toList();
      _counts
        ..clear()
        ..addAll(counts);
      _selected.removeWhere((name) => !_folders.contains(name));
    });
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<String?> _askName(String title, String action, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: Text(action)),
        ],
      ),
    );
    controller.dispose();
    return (name == null || name.isEmpty) ? null : name;
  }

  Future<void> _createFolder() async {
    final name = await _askName('New folder', 'Create');
    if (name == null) return;
    if (LocalFileManagerService.isProtectedFolder(name)) {
      _snack('Downloads is a built-in folder. Choose another name.');
      return;
    }
    final created = await _files.createFolder(name);
    if (!mounted) return;
    if (!created) _snack('A folder with that name already exists or the name is not allowed.');
    await _load();
  }

  Future<void> _renameSelected() async {
    final old = _selected.single;
    final name = await _askName('Rename folder', 'Rename', initial: old);
    if (name == null || name == old) return;
    if (LocalFileManagerService.isProtectedFolder(name)) {
      _snack('Downloads is a built-in folder. Choose another name.');
      return;
    }
    final existing = (await _files.getFolders()).where((folder) => folder.name == old).firstOrNull;
    final ok = await _files.renameFolder(old, name);
    if (ok && existing != null) {
      final renamed = (await _files.getFolders()).where((folder) => folder.name == name).firstOrNull;
      if (renamed != null) _downloads.updateFolderPath(existing.path, renamed.path);
    }
    if (!mounted) return;
    _snack(ok ? 'Folder renamed.' : 'Could not rename. The name may already be in use.');
    _selected.clear();
    await _load();
  }

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $count folder(s)?'),
        content: const Text('All files inside will be deleted from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    var failed = 0;
    for (final name in _selected.toList()) {
      if (!await _files.deleteFolder(name)) failed++;
    }
    if (!mounted) return;
    _snack(failed == 0 ? 'Deleted.' : '$failed folder(s) could not be deleted.');
    _selected.clear();
    await _load();
  }

  void _toggle(String folder) {
    if (LocalFileManagerService.isProtectedFolder(folder)) {
      _snack('This is a built-in Tube Arena media folder and cannot be renamed or deleted.');
      return;
    }
    setState(() => _selected.contains(folder) ? _selected.remove(folder) : _selected.add(folder));
  }

  Future<void> _open(String folder) async {
    await context.push('/library/${Uri.encodeComponent(folder)}');
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final selecting = _selected.isNotEmpty;
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: selecting
            ? AppBar(
                leading: IconButton(
                  tooltip: 'Cancel selection',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(_selected.clear),
                ),
                title: Text('${_selected.length} selected'),
                actions: [
                  if (_selected.length == 1)
                    IconButton(tooltip: 'Rename', onPressed: _renameSelected, icon: const Icon(Icons.edit_rounded)),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: _deleteSelected,
                    icon: const Icon(Icons.delete_rounded, color: AppColors.danger),
                  ),
                ],
              )
            : AppBar(
                automaticallyImplyLeading: false,
                title: const Text('My Library'),
                actions: [
                  IconButton(
                    onPressed: _createFolder,
                    icon: const Icon(Icons.create_new_folder_rounded),
                    tooltip: 'Create folder',
                  ),
                  const ThemeModeButton(),
                ],
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: _folders.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemBuilder: (context, index) {
                    final folder = _folders[index];
                    return FolderCard(
                      folderName: folder,
                      fileCount: _counts[folder] ?? 0,
                      isSelected: _selected.contains(folder),
                      onTap: () => selecting ? _toggle(folder) : _open(folder),
                      onLongPress: () => _toggle(folder),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class LibraryFolderScreen extends StatefulWidget {
  const LibraryFolderScreen({super.key, required this.folderName});

  final String folderName;

  @override
  State<LibraryFolderScreen> createState() => _LibraryFolderScreenState();
}

class _LibraryFolderScreenState extends State<LibraryFolderScreen> {
  late final LocalFileManagerService _files = context.read<LocalFileManagerService>();
  late Future<List<LocalFile>> _future = _files.getFilesInFolder(widget.folderName);

  void _reload() => setState(() => _future = _files.getFilesInFolder(widget.folderName));

  Future<void> _delete(LocalFile file) async {
    final downloads = context.read<DownloadsProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this file?'),
        content: Text(file.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = await _files.deleteFile(file.path);
    if (deleted) downloads.markFileRemoved(file.path);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(deleted ? 'File deleted.' : 'Could not delete the file.')));
    _reload();
  }

  static bool _isAudio(String name) => isAudioFile(name);

  /// Asks for a destination: an existing folder or a new one. Returns its name.
  Future<String?> _pickFolder() async {
    final folders = (await _files.getFolders()).map((f) => f.name).where((name) => name != widget.folderName).toList();
    if (!mounted) return null;
    const newFolder = '\u0000new';
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Move to folder', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            for (final name in folders)
              ListTile(
                leading: const Icon(Icons.folder_rounded),
                title: Text(name),
                onTap: () => Navigator.pop(sheetContext, name),
              ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_rounded),
              title: const Text('New folder...'),
              onTap: () => Navigator.pop(sheetContext, newFolder),
            ),
          ],
        ),
      ),
    );
    if (choice != newFolder || !mounted) return choice;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return null;
    if (LocalFileManagerService.isProtectedFolder(name) || folders.any((f) => f.toLowerCase() == name.toLowerCase())) {
      return folders.firstWhere((f) => f.toLowerCase() == name.toLowerCase(), orElse: () => name);
    }
    if (!await _files.createFolder(name)) {
      if (mounted) _snack('That folder name is not allowed.');
      return null;
    }
    return name;
  }

  Future<void> _move(LocalFile file) async {
    final downloads = context.read<DownloadsProvider>();
    final target = await _pickFolder();
    if (target == null || target == widget.folderName) return;
    final newPath = await _files.moveFileTo(file.path, target);
    if (newPath != null) downloads.updatePath(file.path, newPath);
    if (!mounted) return;
    _snack(newPath != null ? 'Moved to $target.' : 'Could not move the file.');
    _reload();
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.folderName)),
      body: FutureBuilder<List<LocalFile>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not read this folder.'),
                  TextButton(onPressed: _reload, child: const Text('Try again')),
                ],
              ),
            );
          }
          final files = snapshot.data ?? const <LocalFile>[];
          if (files.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('This folder is empty.')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                return ListTile(
                  leading: Icon(_isAudio(file.name) ? Icons.audiotrack_rounded : Icons.movie_rounded),
                  title: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(file.sizeFormatted),
                  onTap: () => context.push(
                    '/watch',
                    extra: VideoModel.local(path: file.path, title: file.name),
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'File options',
                    onSelected: (action) => switch (action) {
                      'move' => _move(file),
                      'save' => saveFileToPhone(context, file.path),
                      'share' => shareFile(context, file.path, title: file.name),
                      _ => _delete(file),
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'move', child: Text('Move to folder')),
                      PopupMenuItem(value: 'save', child: Text('Save to phone')),
                      PopupMenuItem(value: 'share', child: Text('Share')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
