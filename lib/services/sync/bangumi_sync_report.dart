class BangumiSyncReport {
  const BangumiSyncReport({
    required this.completed,
    required this.total,
    required this.finishedAt,
    this.error,
  });

  final int completed;
  final int total;
  final DateTime finishedAt;
  final String? error;
  bool get failed => error != null;
  String get summary => failed
      ? (total > 0 ? '同步未完成 · 已完成 $completed / $total 项' : '同步未完成')
      : (total > 0 ? '同步完成 · $completed 项' : '追番状态已一致');

  Map<String, dynamic> toJson() => {
    'completed': completed,
    'total': total,
    'finishedAt': finishedAt.toIso8601String(),
    'error': error,
  };

  static BangumiSyncReport? fromJson(dynamic value) {
    if (value is! Map) return null;
    final completed = value['completed'];
    final total = value['total'];
    final date = value['finishedAt'];
    final error = value['error'];
    if (completed is! int ||
        total is! int ||
        date is! String ||
        completed < 0 ||
        total < completed ||
        (error != null && error is! String)) {
      return null;
    }
    final time = DateTime.tryParse(date);
    return time == null
        ? null
        : BangumiSyncReport(
            completed: completed,
            total: total,
            finishedAt: time,
            error: error as String?,
          );
  }
}
