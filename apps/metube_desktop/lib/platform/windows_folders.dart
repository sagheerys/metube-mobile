import 'dart:io';

import 'package:file_selector/file_selector.dart' as selector;
import 'package:path_provider_windows/path_provider_windows.dart';

import '../data/folders_data.dart';
import 'open_with_windows.dart';

/// The Windows folders: the known Videos and Downloads (wherever OneDrive
/// or the user moved them), Windows' own folder dialog, and Explorer.
class WindowsFolders extends DesktopFolders {
  const WindowsFolders();

  static final _paths = PathProviderWindows();

  /// FOLDERID_Videos. The package names it too, but behind an import the
  /// analyzer resolves to a stub.
  static const _videos = '{18989B1D-99B5-455B-841C-AB7C74E4DDFC}';

  @override
  Future<String?> videos() => _paths.getPath(_videos);

  @override
  Future<String?> downloads() => _paths.getDownloadsPath();

  @override
  Future<String?> pick({String? initial}) => selector.getDirectoryPath(
    initialDirectory: initial != null && Directory(initial).existsSync()
        ? initial
        : null,
    canCreateDirectories: true,
  );

  @override
  Future<String?> openText({required List<String> extensions}) async {
    final file = await selector.openFile(
      acceptedTypeGroups: [selector.XTypeGroup(extensions: extensions)],
    );
    if (file == null) return null;
    try {
      return await File(file.path).readAsString();
    } on Object {
      return null;
    }
  }

  @override
  Future<List<(String, List<int>)>> openFiles({
    required List<String> extensions,
  }) async {
    final files = await selector.openFiles(
      acceptedTypeGroups: [selector.XTypeGroup(extensions: extensions)],
    );
    return [
      for (final file in files)
        if (await _bytes(file.path) case final bytes?) (file.name, bytes),
    ];
  }

  static Future<List<int>?> _bytes(String path) async {
    try {
      return await File(path).readAsBytes();
    } on Object {
      return null;
    }
  }

  @override
  Future<String?> saveText({required String name, required String text}) async {
    final place = await selector.getSaveLocation(suggestedName: name);
    if (place == null) return null;
    await File(place.path).writeAsString(text, flush: true);
    return place.path;
  }

  @override
  Future<String?> saveBytes({
    required String name,
    required List<int> bytes,
  }) async {
    final place = await selector.getSaveLocation(suggestedName: name);
    if (place == null) return null;
    await File(place.path).writeAsBytes(bytes, flush: true);
    return place.path;
  }

  // Explorer is started with its arguments as a list, never through a
  // shell, so a name with spaces or an ampersand stays one argument.
  @override
  Future<void> reveal(String path) async {
    if (!File(path).existsSync()) return open(File(path).parent.path);
    await Process.start('explorer.exe', ['/select,', path]);
  }

  @override
  Future<void> openWith(String path) async {
    if (File(path).existsSync()) await showOpenWith(path);
  }

  @override
  Future<void> open(String path) async {
    final dir = Directory(path);
    if (!dir.existsSync()) await dir.create(recursive: true);
    await Process.start('explorer.exe', [dir.path]);
  }
}
