import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/app_settings.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key, required this.controller});
  final AppController controller;

  static const colors = <Color>[
    Color(0xff7567e8),
    Color(0xff2563eb),
    Color(0xff0891b2),
    Color(0xff059669),
    Color(0xffd97706),
    Color(0xffe11d48),
    Color(0xff9333ea),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text('外观', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        Text('主色调', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((color) {
            final selected = settings.primaryColorValue == color.toARGB32();
            return Tooltip(
              message:
                  '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => _save(
                    settings.copyWith(primaryColorValue: color.toARGB32())),
                child: CircleAvatar(
                  backgroundColor: color,
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('跟随系统外观'),
          subtitle: const Text('根据系统设置自动切换日间与夜间模式'),
          value: settings.followSystemTheme,
          onChanged: (value) =>
              _save(settings.copyWith(followSystemTheme: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('夜间模式'),
          subtitle:
              Text(settings.followSystemTheme ? '关闭“跟随系统”后可手动切换' : '使用深色界面'),
          value: settings.darkMode,
          onChanged: settings.followSystemTheme
              ? null
              : (value) => _save(settings.copyWith(darkMode: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('纯黑模式'),
          subtitle: const Text('夜间模式下使用纯黑背景，尤其适合 OLED 屏幕'),
          value: settings.pureBlackMode,
          onChanged: (value) => _save(settings.copyWith(pureBlackMode: value)),
        ),
      ],
    );
  }

  Future<void> _save(AppSettings settings) =>
      controller.updateSettings(settings);
}
