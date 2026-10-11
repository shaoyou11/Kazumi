import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Only mounted on the iOS fullscreen transport bar.
class PlayerDeviceStatus extends StatefulWidget {
  const PlayerDeviceStatus({super.key});
  @override
  State<PlayerDeviceStatus> createState() => _PlayerDeviceStatusState();
}

class _PlayerDeviceStatusState extends State<PlayerDeviceStatus> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _now = DateTime.now();
  int? _battery;
  bool _charging = false;
  static const _channel = MethodChannel('com.shaoyou11.kazumit/player');
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }
  void _start() {
    _timer?.cancel();
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => unawaited(_refresh()));
  }
  Future<void> _refresh() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('deviceStatus');
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        _battery = (result?['battery'] as num?)?.toInt();
        _charging = result?['charging'] == true;
      });
    } on PlatformException catch (_) {
      if (mounted) setState(() => _now = DateTime.now());
    } on MissingPluginException catch (_) {
      if (mounted) setState(() => _now = DateTime.now());
    }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) { _start(); } else { _timer?.cancel(); }
  }
  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final time = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    const textStyle = TextStyle(color: Colors.white, fontSize: 14,
        height: 1, fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()]);
    return Semantics(label: '时间 $time，电量 ${_battery ?? '未知'}',
      child: SizedBox(height: 44, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(time, style: textStyle),
          const SizedBox(width: 10),
          RotatedBox(quarterTurns: 1,
            child: Icon(_charging ? Icons.battery_charging_full : Icons.battery_std,
              size: 20, color: (_battery ?? 100) <= 20 ? Colors.amber : Colors.white)),
          const SizedBox(width: 3),
          Text(_battery == null || _battery! < 0 ? '—' : '$_battery%', style: textStyle),
        ]),
      )),
    );
  }
}
