import 'dart:io';

import 'package:path/path.dart' as p;

class AssetService {
  Directory directory(String repositoryPath) =>
      Directory(p.join(repositoryPath, 'public', 'images'));

  Future<List<File>> list(String repositoryPath) async {
    final root = directory(repositoryPath);
    if (!await root.exists()) return [];
    final files = await root
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return files;
  }

  Future<File> import(
    String repositoryPath,
    File source, {
    String? name,
  }) async {
    final root = directory(repositoryPath);
    await root.create(recursive: true);
    final target = File(p.join(root.path, name ?? p.basename(source.path)));
    return source.copy(target.path);
  }

  Future<void> delete(File file) => file.delete();
}
