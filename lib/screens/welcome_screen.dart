import 'package:flutter/material.dart';

import '../app_controller.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pageController = PageController();
  var _page = 0;
  var _testing = false;
  String? _result;
  bool _success = false;

  static const _steps = [
    (
      '欢迎使用 StarryNote',
      '接下来会依次检查写作所需的 Git、Cloudflare R2 和 Starry Blog。所有检测都可以跳过。',
      Icons.auto_awesome
    ),
    (
      '检测 Git',
      '确认系统 Git 可用；若仓库已连接，还会读取当前分支和工作区状态。',
      Icons.account_tree_outlined
    ),
    (
      '检测 Cloudflare R2',
      '使用已保存的 R2 凭据执行只读连接检测，不会上传或删除文件。',
      Icons.cloud_outlined
    ),
    (
      '检测博客系统',
      '检查仓库中的 public/config.js、public/articles，并尝试读取文章列表。',
      Icons.language_outlined
    ),
    ('准备好了', '以后可以在“连接”中补充凭据，在“外观”中随时调整应用主题。', Icons.rocket_launch_outlined),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text('跳过向导'),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _steps.length,
                  itemBuilder: (context, index) => _step(index),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Row(
                    children: [
                      if (_page > 0)
                        TextButton(onPressed: _back, child: const Text('上一步')),
                      const Spacer(),
                      Text('${_page + 1} / ${_steps.length}'),
                      const SizedBox(width: 18),
                      if (_page > 0 && _page < _steps.length - 1)
                        OutlinedButton(
                            onPressed: _next, child: const Text('跳过此项')),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _testing ? null : _primaryAction,
                        icon: _testing
                            ? const SizedBox.square(
                                dimension: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(_page == _steps.length - 1
                                ? Icons.check
                                : _page == 0
                                    ? Icons.arrow_forward
                                    : Icons.play_arrow),
                        label: Text(_page == _steps.length - 1
                            ? '完成'
                            : _page == 0
                                ? '开始检查'
                                : '测试并继续'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _step(int index) {
    final step = _steps[index];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                children: [
                  CircleAvatar(radius: 38, child: Icon(step.$3, size: 38)),
                  const SizedBox(height: 24),
                  Text(step.$1,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  Text(step.$2,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge),
                  if (_result != null && index == _page) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (_success
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.errorContainer),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        Icon(
                            _success ? Icons.check_circle : Icons.info_outline),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_result!)),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _primaryAction() async {
    if (_page == 0) return _next();
    if (_page == _steps.length - 1) return _finish();
    setState(() {
      _testing = true;
      _result = null;
    });
    try {
      final result = switch (_page) {
        1 => await widget.controller.testGit(),
        2 => await widget.controller.testR2(),
        3 => await widget.controller.testBlog(),
        _ => '',
      };
      if (!mounted) return;
      setState(() {
        _success = true;
        _result = result;
      });
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (mounted) _next();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _success = false;
        _result = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _next() {
    if (_page >= _steps.length - 1) return;
    setState(() {
      _page++;
      _result = null;
    });
    _pageController.animateToPage(_page,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _back() {
    setState(() {
      _page--;
      _result = null;
    });
    _pageController.animateToPage(_page,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _finish() => widget.controller.completeOnboarding();
}
