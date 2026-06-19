import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../app_controller.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  List<File> _files = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final files = await widget.controller.assetService.list(
      widget.controller.settings.repositoryPath,
    );
    if (mounted) setState(() => _files = files);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Text('固有静态资源', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            FilledButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('导入文件'),
            ),
          ],
        ),
      ),
      Expanded(
        child: _files.isEmpty
            ? const Center(child: Text('public/images 里还没有资源'))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 250,
                  mainAxisExtent: 230,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Expanded(
                          child: _isRaster(file.path)
                              ? Image.file(
                                  file,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.broken_image_outlined,
                                    size: 60,
                                  ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.insert_drive_file_outlined,
                                    size: 60,
                                  ),
                                ),
                        ),
                        ListTile(
                          dense: true,
                          title: Text(
                            p.basename(file.path),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('/images/${p.basename(file.path)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(file),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    ],
  );

  bool _isRaster(String path) => [
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.gif',
    '.bmp',
  ].contains(p.extension(path).toLowerCase());
  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    final source = picked?.files.single.path;
    if (source == null) return;
    try {
      await widget.controller.assetService.import(
        widget.controller.settings.repositoryPath,
        File(source),
      );
      if (await widget.controller.gitService.isAvailable) {
        await widget.controller.gitService.saveCommit(
          widget.controller.settings.repositoryPath,
          message: 'assets: add ${p.basename(source)}',
        );
      }
      await _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _delete(File file) async {
    await widget.controller.assetService.delete(file);
    if (await widget.controller.gitService.isAvailable) {
      await widget.controller.gitService.saveCommit(
        widget.controller.settings.repositoryPath,
        message: 'assets: remove ${p.basename(file.path)}',
      );
    }
    await _load();
  }
}
