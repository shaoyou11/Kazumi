import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/services/plugin/search_result_ranker.dart';

void main() {
  List<SearchItem> items(List<String> names) => [
    for (var i = 0; i < names.length; i++)
      SearchItem(name: names[i], src: '$i'),
  ];
  test('season overrides an exact generic alias; keeps every result', () {
    final source = items(['测试番 第一季', '测试番 剧场版', '测试番 II', '无关结果']);
    final result = rankSourceResults(source, titles: ['测试番 第二季', '测试番']);
    expect(result.first.name, '测试番 II');
    expect(result.toSet(), source.toSet());
    expect(source.first.name, '测试番 第一季');
  });
  test('aliases, punctuation and full width digits are normalized', () {
    final result = rankSourceResults(
      items(['Example Season 1', 'Example Season ２']),
      titles: ['示例 第二季', 'EXAMPLE Season 2'],
    );
    expect(result.first.name, 'Example Season ２');
  });
  test('Chinese season twelve and unicode roman numeral agree', () {
    expect(
      rankSourceResults(
        items(['动画 第三季', '动画 XII']),
        titles: ['动画 第十二季'],
      ).first.name,
      '动画 XII',
    );
    expect(
      rankSourceResults(items(['动画 I', '动画 Ⅱ']), titles: ['动画 第二期']).first.name,
      '动画 Ⅱ',
    );
  });
  test('specials rank below main series unless specifically requested', () {
    final results = items(['例子 特别篇', '例子', '例子 第二季']);
    expect(rankSourceResults(results, titles: ['例子']).first.name, '例子');
    expect(rankSourceResults(results, titles: ['例子 特別篇']).first.name, '例子 特别篇');
  });
  test('equal scores and empty queries retain site order', () {
    final source = items(['甲', '乙', '丙']);
    expect(rankSourceResults(source, titles: ['其他']).map((x) => x.src), [
      '0',
      '1',
      '2',
    ]);
    expect(rankSourceResults(source, titles: ['']).map((x) => x.src), [
      '0',
      '1',
      '2',
    ]);
  });
}
