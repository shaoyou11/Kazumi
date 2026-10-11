import 'dart:async';
import 'package:dlna_dart/dlna.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';

class RemotePlay {
  Future<bool> castVideo(String video, String referer) async {
    if (!['http', 'https'].contains(Uri.tryParse(video)?.scheme)) {
      KazumiDialog.showToast(message: '本地缓存暂不支持 DLNA，请使用 AirPlay');
      return false;
    }
    return await KazumiDialog.show<bool>(
      builder: (_) => _CastDialog(video: video, needsReferer: referer.isNotEmpty),
    ) ?? false;
  }
}

class _CastDialog extends StatefulWidget {
  const _CastDialog({required this.video, required this.needsReferer});
  final String video;
  final bool needsReferer;
  @override
  State<_CastDialog> createState() => _CastDialogState();
}

class _CastDialogState extends State<_CastDialog> {
  final _searcher = DLNAManager();
  StreamSubscription<Map<String, DLNADevice>>? _subscription;
  List<DLNADevice> _devices = [];
  Timer? _timeout;
  String _status = '正在寻找同一 Wi-Fi 下的电视…';
  bool _connecting = false;
  bool _starting = false;

  @override
  void initState() { super.initState(); unawaited(_search()); }

  Future<void> _search() async {
    if (_starting || _connecting) return;
    _starting = true;
    _timeout?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    if (!mounted) { _starting = false; return; }
    setState(() { _devices = []; _status = '正在寻找同一 Wi-Fi 下的电视…'; });
    try {
      final manager = await _searcher.start(reusePort: true);
      if (!mounted) { _searcher.stop(); return; }
      void update(Map<String, DLNADevice> devices) {
        if (!mounted) return;
        setState(() {
          _devices = devices.values.where((d) => d.info.deviceType.contains(':MediaRenderer:')).toList();
          if (_devices.isNotEmpty) _status = '选择电视开始播放';
        });
      }
      _subscription = manager.devices.stream.listen(update);
      update(manager.deviceList);
      _timeout = Timer(const Duration(seconds: 15), () {
        if (mounted && _devices.isEmpty) setState(() => _status = '未发现电视。请确认同一 Wi-Fi、电视投屏功能和本地网络权限；iOS 也可尝试 AirPlay。');
      });
    } catch (_) {
      _searcher.stop();
      if (mounted) setState(() => _status = '无法搜索设备，请检查本地网络权限与 Wi-Fi 后重试');
    } finally {
      _starting = false;
    }
  }

  Future<void> _cast(DLNADevice device) async {
    if (_connecting) return;
    setState(() { _connecting = true; _status = '正在连接 ${device.info.friendlyName}…'; });
    try {
      await device.setUrl(widget.video).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      await device.play().timeout(const Duration(seconds: 15));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _status = '投屏失败。电视可能不支持此片源的格式或访问限制，可换线路或尝试 AirPlay。');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    unawaited(_subscription?.cancel());
    _searcher.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('DLNA 投屏'),
    content: SizedBox(width: 320, child: SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_status),
        if (widget.needsReferer) const Padding(padding: EdgeInsets.only(top: 12),
          child: Text('电视直接读取片源，部分需来源验证的线路可能无法播放。', style: TextStyle(fontSize: 12))),
        ..._devices.map((device) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cast_connected),
          title: Text(device.info.friendlyName),
          enabled: !_connecting,
          onTap: () => _cast(device),
        )),
      ],
    ))),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('关闭')),
      TextButton(onPressed: _connecting ? null : _search, child: const Text('重新搜索')),
    ],
  );
}
