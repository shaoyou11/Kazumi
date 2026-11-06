import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:dlna_dart/xmlParser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/services/player/remote.dart';

class FakeManager extends DLNAManager {
  final sessions = <DeviceManager>[];
  int stops = 0;

  @override
  Future<DeviceManager> start({reusePort = false}) async {
    if (sessions.isNotEmpty) sessions.last.dispose();
    final session = DeviceManager();
    sessions.add(session);
    return session;
  }

  @override
  void stop() {
    super.stop();
    stops++;
    if (sessions.isNotEmpty) sessions.last.dispose();
  }
}

class FakeDevice extends DLNADevice {
  FakeDevice(String name, {bool transport = true, String type = 'BasicDevice'})
    : super(
        DeviceInfo(
          'http://tv.test',
          'urn:schemas-upnp-org:device:$type:1',
          name,
          [
            if (transport) {'serviceId': 'urn:upnp-org:serviceId:AVTransport'},
          ],
        ),
      );

  final calls = <String>[];
  Completer<String>? pendingUrl;
  bool fail = false;

  @override
  Future<String> setUrl(
    String url, {
    String title = '',
    PlayType type = VideoMime.any,
  }) async {
    calls.add('url:$url title:$title');
    if (fail) throw StateError('unreachable');
    return pendingUrl == null ? '' : await pendingUrl!.future;
  }

  @override
  Future<String> play() async {
    calls.add('play');
    return '';
  }
}

void main() {
  late FakeManager manager;
  late RemotePlay remote;

  setUp(() {
    manager = FakeManager();
    remote = RemotePlay(createManager: () => manager);
  });
  tearDown(() => manager.stop());

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        navigatorObservers: [KazumiDialog.observer],
        home: const Scaffold(body: Text('home')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'filters by AVTransport, refreshes empty lists and retries discovery',
    (tester) async {
      await mount(tester);
      final result = remote.castVideo(
        'https://video.test/1',
        '',
        title: 'Episode 1',
      );
      await tester.pumpAndSettle();
      final tv = FakeDevice('Castable basic device');
      final nonCastable = FakeDevice(
        'Renderer without transport',
        transport: false,
        type: 'MediaRenderer',
      );
      manager.sessions.last.devices.add({'tv': tv, 'other': nonCastable});
      await tester.pumpAndSettle();
      expect(find.text('Castable basic device'), findsOneWidget);
      expect(find.text('Renderer without transport'), findsNothing);
      manager.sessions.last.devices.add({});
      await tester.pumpAndSettle();
      expect(find.text('Castable basic device'), findsNothing);
      // StreamSubscription.cancel completes outside the fake frame clock.
      await tester.runAsync(() => tester.tap(find.text('重新搜索')));
      await tester.pumpAndSettle();
      expect(manager.sessions, hasLength(2));
      manager.sessions.last.devices.add({'tv': tv});
      await tester.pumpAndSettle();
      expect(find.text('Castable basic device'), findsOneWidget);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
      expect(manager.stops, greaterThan(0));
    },
  );

  testWidgets('sends title and waits for setUrl before play and success', (
    tester,
  ) async {
    await mount(tester);
    final result = remote.castVideo(
      'https://video.test/1',
      'https://source.test',
      title: 'Anime · Episode 1',
    );
    await tester.pumpAndSettle();
    final tv = FakeDevice('TV')..pendingUrl = Completer<String>();
    manager.sessions.last.devices.add({'tv': tv});
    await tester.pumpAndSettle();
    await tester.tap(find.text('TV'));
    await tester.pumpAndSettle();
    expect(tv.calls, ['url:https://video.test/1 title:Anime · Episode 1']);
    expect(find.text('DLNA 投屏'), findsOneWidget);
    tv.pendingUrl!.complete('');
    await tester.pumpAndSettle();
    expect(tv.calls.last, 'play');
    expect(await result, isTrue);
  });

  testWidgets('failed connection stays retryable and closing returns false', (
    tester,
  ) async {
    await mount(tester);
    final result = remote.castVideo(
      'https://video.test/1',
      '',
      title: 'Episode',
    );
    await tester.pumpAndSettle();
    final tv = FakeDevice('TV')..fail = true;
    manager.sessions.last.devices.add({'tv': tv});
    await tester.pumpAndSettle();
    await tester.tap(find.text('TV'));
    await tester.pumpAndSettle();
    expect(tv.calls, hasLength(1));
    expect(find.textContaining('投屏失败'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('closing while setUrl is pending prevents play', (tester) async {
    await mount(tester);
    final result = remote.castVideo(
      'https://video.test/1',
      '',
      title: 'Episode',
    );
    await tester.pumpAndSettle();
    final tv = FakeDevice('TV')..pendingUrl = Completer<String>();
    manager.sessions.last.devices.add({'tv': tv});
    await tester.pumpAndSettle();
    await tester.tap(find.text('TV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    tv.pendingUrl!.complete('');
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    expect(tv.calls, hasLength(1));
  });

  testWidgets('local URLs do not start network discovery', (tester) async {
    await mount(tester);
    expect(
      await remote.castVideo('file:///video.mp4', '', title: 'Offline'),
      isFalse,
    );
    await tester.pumpAndSettle();
    expect(manager.sessions, isEmpty);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
