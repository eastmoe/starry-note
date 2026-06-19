import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/app_settings.dart';

class SettingsForm extends StatefulWidget {
  const SettingsForm({
    super.key,
    required this.initialValue,
    required this.onSave,
    this.connectMode = false,
  });
  final AppSettings initialValue;
  final Future<void> Function(AppSettings value) onSave;
  final bool connectMode;

  @override
  State<SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> c;
  bool _showSecrets = false;

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    c = {
      'gitUrl': TextEditingController(text: value.gitUrl),
      'repositoryPath': TextEditingController(text: value.repositoryPath),
      'gitAuthorName': TextEditingController(text: value.gitAuthorName),
      'gitAuthorEmail': TextEditingController(text: value.gitAuthorEmail),
      'gitUsername': TextEditingController(text: value.gitUsername),
      'gitToken': TextEditingController(text: value.gitToken),
      'supabaseUrl': TextEditingController(text: value.supabaseUrl),
      'supabaseKey': TextEditingController(text: value.supabaseKey),
      'r2AccountId': TextEditingController(text: value.r2AccountId),
      'r2AccessKeyId': TextEditingController(text: value.r2AccessKeyId),
      'r2SecretAccessKey': TextEditingController(text: value.r2SecretAccessKey),
      'r2Bucket': TextEditingController(text: value.r2Bucket),
      'r2PublicBaseUrl': TextEditingController(text: value.r2PublicBaseUrl),
    };
  }

  @override
  void dispose() {
    for (final controller in c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section('Git 仓库', '支持 HTTPS URL。私有仓库可填写用户名和 PAT；凭据不会写入博客仓库。'),
            _field(
              'gitUrl',
              '项目 Git URL',
              hint: 'https://github.com/you/starry-blog.git',
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: c['repositoryPath'],
                decoration: InputDecoration(
                  labelText: '已有本地仓库目录（可选）',
                  hintText: r'E:\Starry-Blog',
                  suffixIcon: IconButton(
                    tooltip: '选择目录',
                    onPressed: () async {
                      final path = await FilePicker.getDirectoryPath();
                      if (path != null) c['repositoryPath']!.text = path;
                    },
                    icon: const Icon(Icons.folder_open_outlined),
                  ),
                ),
              ),
            ),
            _row([
              _field('gitAuthorName', '提交者名称'),
              _field('gitAuthorEmail', '提交者邮箱'),
            ]),
            _row([
              _field('gitUsername', 'Git 用户名'),
              _field('gitToken', 'Personal Access Token', secret: true),
            ]),
            _section(
              'Supabase 评论',
              '删除评论需要 service_role key；只读可使用 anon key。请勿把 service_role key 写入网页 config.js。',
            ),
            _field('supabaseUrl', 'Supabase URL',
                hint: 'https://xxxx.supabase.co'),
            _field('supabaseKey', '管理 API Key', secret: true),
            _section(
              'Cloudflare R2',
              '请填写“R2 对象存储 API 令牌”生成的 S3 Access Key ID 和 Secret Access Key，不要填写普通 Cloudflare API Token。令牌需要目标 Bucket 的对象读写权限。',
            ),
            _row([
              _field('r2AccountId', 'Account ID'),
              _field('r2Bucket', 'Bucket'),
            ]),
            _row([
              _field(
                'r2AccessKeyId',
                'R2 Access Key ID',
                hint: 'R2 API 令牌生成的 S3 Access Key ID',
                secret: true,
              ),
              _field(
                'r2SecretAccessKey',
                'R2 Secret Access Key',
                hint: '创建 R2 API 令牌时显示一次',
                secret: true,
              ),
            ]),
            _field(
              'r2PublicBaseUrl',
              '公开访问基础 URL',
              hint: 'https://assets.example.com',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('显示凭据'),
              value: _showSecrets,
              onChanged: (value) => setState(() => _showSecrets = value),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submit,
              icon: Icon(widget.connectMode ? Icons.link : Icons.save_outlined),
              label: Text(widget.connectMode ? '连接并打开博客' : '保存连接设置'),
            ),
          ],
        ),
      );

  Widget _section(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );

  Widget _row(List<Widget> children) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 620) return Column(children: children);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children
                .map(
                  (item) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: item == children.last ? 0 : 12,
                      ),
                      child: item,
                    ),
                  ),
                )
                .toList(),
          );
        },
      );

  Widget _field(
    String key,
    String label, {
    String? hint,
    bool secret = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c[key],
          obscureText: secret && !_showSecrets,
          autocorrect: !secret,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final value = widget.initialValue.copyWith(
      gitUrl: c['gitUrl']!.text.trim(),
      repositoryPath: c['repositoryPath']!.text.trim(),
      gitAuthorName: c['gitAuthorName']!.text.trim(),
      gitAuthorEmail: c['gitAuthorEmail']!.text.trim(),
      gitUsername: c['gitUsername']!.text.trim(),
      gitToken: c['gitToken']!.text.trim(),
      supabaseUrl: c['supabaseUrl']!.text.trim(),
      supabaseKey: c['supabaseKey']!.text.trim(),
      r2AccountId: c['r2AccountId']!.text.trim(),
      r2AccessKeyId: c['r2AccessKeyId']!.text.trim(),
      r2SecretAccessKey: c['r2SecretAccessKey']!.text.trim(),
      r2Bucket: c['r2Bucket']!.text.trim(),
      r2PublicBaseUrl: c['r2PublicBaseUrl']!.text.trim(),
    );
    await widget.onSave(value);
  }
}
