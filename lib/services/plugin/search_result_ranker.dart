import 'dart:math' as math;

import 'package:kazumi/modules/search/plugin_search_module.dart';

/// Reorders suggestions only: never hides a source or selects a result for the
/// user. Ties retain the site's order. Season hints outrank a generic alias.
List<SearchItem> rankSourceResults(
  List<SearchItem> items, {
  required List<String> titles,
}) {
  final references = titles
      .where((s) => s.trim().isNotEmpty)
      .map(_Title.parse)
      .where((t) => t.base.isNotEmpty)
      .toList();
  if (references.isEmpty) return List.of(items);
  final seasons = references.map((t) => t.season).whereType<int>().toSet();
  final wantedSeason = seasons.length == 1 ? seasons.single : null;
  final kinds = references.map((t) => t.kind).whereType<String>().toSet();
  final ranked =
      items.asMap().entries.map((entry) {
        final candidate = _Title.parse(entry.value.name);
        var score = references
            .map((r) => _similarity(r.base, candidate.base))
            .reduce(math.max);
        if (wantedSeason != null && candidate.season != null) {
          score *= wantedSeason == candidate.season ? 1.0 : 0.25;
        } else if (wantedSeason != null && wantedSeason != 1) {
          score *= 0.8;
        } else if (wantedSeason == null &&
            candidate.season != null &&
            candidate.season != 1) {
          score *= 0.8;
        }
        if (candidate.kind != null && !kinds.contains(candidate.kind)) {
          score *= 0.6;
        }
        if (kinds.isNotEmpty && candidate.kind == null) score *= 0.8;
        return (index: entry.key, item: entry.value, score: score);
      }).toList()..sort((a, b) {
        final compared = b.score.compareTo(a.score);
        return compared == 0 ? a.index.compareTo(b.index) : compared;
      });
  return ranked.map((r) => r.item).toList();
}

double _similarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  if (a == b) return 1;
  if (a.contains(b) || b.contains(a)) {
    return 0.75 +
        0.2 * math.min(a.length, b.length) / math.max(a.length, b.length);
  }
  Set<String> pairs(String s) => s.length < 2
      ? {s}
      : {for (var i = 0; i < s.length - 1; i++) s.substring(i, i + 2)};
  final left = pairs(a);
  final right = pairs(b);
  return 2 * left.intersection(right).length / (left.length + right.length);
}

class _Title {
  const _Title(this.base, this.season, this.kind);
  final String base;
  final int? season;
  final String? kind;

  static _Title parse(String text) {
    var title = text.toLowerCase().replaceAllMapped(
      RegExp('[０-９]'),
      (m) => '${m[0]!.codeUnitAt(0) - 0xff10}',
    );
    const romans = {
      'ⅰ': 'i',
      'ⅱ': 'ii',
      'ⅲ': 'iii',
      'ⅳ': 'iv',
      'ⅴ': 'v',
      'ⅵ': 'vi',
      'ⅶ': 'vii',
      'ⅷ': 'viii',
      'ⅸ': 'ix',
      'ⅹ': 'x',
    };
    for (final entry in romans.entries) {
      title = title.replaceAll(entry.key, ' ${entry.value} ');
    }
    final kindMatch = RegExp(r'剧场版|劇場版|特别篇|特別篇|\b(?:ova|oad|movie|special)\b')
        .firstMatch(title);
    final rawKind = kindMatch?[0];
    final kind = switch (rawKind) {
      '剧场版' || '劇場版' || 'movie' => 'movie',
      '特别篇' || '特別篇' || 'special' => 'special',
      _ => rawKind,
    };
    final match = RegExp(
      r'第\s*([0-9一二三四五六七八九十两兩]+)\s*[季期]|\b(?:season\s*|s)(\d+)\b|\b([ivx]+)\s*$',
    ).firstMatch(title);
    int? season;
    if (match != null) {
      season = _number(match[1] ?? match[2] ?? match[3]!);
      if (season != null) {
        title = title.replaceRange(match.start, match.end, '');
      }
    }
    title = title.replaceAll(
      RegExp(r'剧场版|劇場版|特别篇|特別篇|\b(?:ova|oad|movie|special)\b'),
      '',
    );
    return _Title(
      title.replaceAll(RegExp(r'[^a-z0-9\u3040-\u30ff\u3400-\u9fff]'), ''),
      season,
      kind,
    );
  }

  static int? _number(String value) {
    final arabic = int.tryParse(value);
    if (arabic != null) return arabic;
    const roman = {
      'i': 1,
      'ii': 2,
      'iii': 3,
      'iv': 4,
      'v': 5,
      'vi': 6,
      'vii': 7,
      'viii': 8,
      'ix': 9,
      'x': 10,
      'xi': 11,
      'xii': 12,
    };
    if (roman.containsKey(value)) return roman[value];
    const chinese = {
      '一': 1,
      '二': 2,
      '两': 2,
      '兩': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };
    if (value == '十') return 10;
    if (chinese.containsKey(value)) return chinese[value];
    final parts = value.split('十');
    if (parts.length != 2) return null;
    final tens = parts[0].isEmpty ? 1 : chinese[parts[0]];
    final ones = parts[1].isEmpty ? 0 : chinese[parts[1]];
    return tens == null || ones == null ? null : tens * 10 + ones;
  }
}
