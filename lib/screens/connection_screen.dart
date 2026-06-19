import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../widgets/settings_form.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text('连接与凭据', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '敏感字段由系统安全存储保存，不会进入 Git 提交。',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          SettingsForm(
            initialValue: controller.settings,
            onTestGit: controller.testGitSettings,
            onTestR2: controller.testR2Settings,
            onTestBlog: controller.testBlogSettings,
            onSave: (value) async {
              try {
                await controller.updateSettings(value);
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('连接设置已保存。')));
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$error')));
                }
              }
            },
          ),
        ],
      );
}
