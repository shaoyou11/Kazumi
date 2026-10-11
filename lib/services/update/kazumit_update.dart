import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:url_launcher/url_launcher.dart';

class KazumiTUpdate {
  static const _key = SettingKey<String>('kazumitUpdatePortal', '', group: SettingGroup.update);
  static const _builtIn = String.fromEnvironment('KAZUMIT_UPDATE_URL');

  static Future<void> open() async {
    final stored = GStorage.getSetting(_key);
    final value = stored.isEmpty ? _builtIn : stored;
    if (value.isEmpty) { configure(); return; }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      KazumiDialog.showToast(message: '请先设置有效的 HTTPS 签名工作台地址');
      configure(); return;
    }
    final target = uri.replace(queryParameters: {...uri.queryParameters, 'app': 'KazumiT'}, fragment: 'library');
    if (!await launchUrl(target, mode: LaunchMode.externalApplication)) {
      KazumiDialog.showToast(message: '无法打开签名更新页面');
    }
  }

  static void configure() {
    KazumiDialog.show(builder: (context) => const _PortalDialog());
  }
}

class _PortalDialog extends StatefulWidget {
  const _PortalDialog();
  @override
  State<_PortalDialog> createState() => _PortalDialogState();
}
class _PortalDialogState extends State<_PortalDialog> {
  late final _input = TextEditingController(text: GStorage.getSetting(KazumiTUpdate._key));
  String? _error;
  @override
  void dispose() { _input.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('签名更新入口'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('填写自己的 HTTPS 签名工作台地址。新版由 NAS 签名，安装时需要确认系统提示。留空恢复内置入口。'),
      const SizedBox(height: 16),
      TextField(controller: _input, keyboardType: TextInputType.url, autocorrect: false,
        decoration: InputDecoration(labelText: '工作台地址', errorText: _error)),
    ]),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
      TextButton(onPressed: () async {
        final text = _input.text.trim(); final uri = Uri.tryParse(text);
        if (text.isNotEmpty && (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty)) {
          setState(() => _error = '请输入 HTTPS 地址，不要包含账号密码'); return;
        }
        await GStorage.putSetting(KazumiTUpdate._key, text);
        if (context.mounted) Navigator.pop(context);
      }, child: const Text('保存'))],
  );
}
