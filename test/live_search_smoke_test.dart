import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

// Opt-in integration check against the public official API. No user credentials.
void main() {
  test(
    'personal build finds 李熊猫 with default mirror preference',
    () async {
      Logger.level = Level.off;
      final directory = await Directory.systemTemp.createTemp(
        'kazumit_live_search_',
      );
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      Hive.init(directory.path);
      await GStorage.init();
      try {
        await GStorage.putSetting(SettingsKeys.enableBangumiProxy, true);
        await GStorage.putSetting(SettingsKeys.bangumiAcceleration, 'mirror');
        await GStorage.putSetting(SettingsKeys.bangumiSyncEnable, false);
        await GStorage.putSetting(SettingsKeys.bangumiAccessToken, '');
        final results = await BangumiApi.bangumiSearch('李熊猫');
        expect(results, isNotNull);
        expect(
          results!.items.any(
            (item) => item.id == 642666 && item.nameCn == '李熊猫',
          ),
          isTrue,
        );
        final other = await BangumiApi.bangumiSearch('葬送的芙莉莲');
        expect(other, isNotNull);
        expect(other!.items, isNotEmpty);
      } finally {
        DioFactory.bangumiDio.close(force: true);
        DioFactory.reset();
        await Hive.close();
        PathProviderPlatform.instance = original;
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_BANGUMI'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}
