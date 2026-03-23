class UserStats {
  UserStats({
    required this.total,
    required this.watching,
    required this.completed,
    required this.dropped,
    required this.planToWatch,
    required this.averageScore,
    required this.completionRate,
  });

  final int total;
  final int watching;
  final int completed;
  final int dropped;
  final int planToWatch;
  final double averageScore;
  final double completionRate;
}
