import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../widgets/settings_form.dart';
import 'appearance_screen.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('连接博客'),
          actions: [
            IconButton(
              tooltip: '外观设置',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('外观设置')),
                    body: AppearanceScreen(controller: controller),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            const _Backdrop(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Icon(Icons.auto_awesome),
                                ),
                                const SizedBox(width: 14),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'StarryNote',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text('把文章写进你的星海。'),
                                  ],
                                ),
                              ],
                            ),
                            SettingsForm(
                              initialValue: controller.settings,
                              connectMode: true,
                              onSave: (settings) async {
                                try {
                                  await controller.connectRepository(settings);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text(controller.error ?? '连接失败'),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (controller.busy) const LinearProgressIndicator(),
          ],
        ),
      );
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();
  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: CustomPaint(
          painter: _StarPainter(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .13),
          ),
        ),
      );
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var i = 0; i < 70; i++) {
      final x = ((i * 83) % 997) / 997 * size.width;
      final y = ((i * i * 47) % 991) / 991 * size.height;
      canvas.drawCircle(Offset(x, y), i % 9 == 0 ? 2.2 : 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) =>
      oldDelegate.color != color;
}
