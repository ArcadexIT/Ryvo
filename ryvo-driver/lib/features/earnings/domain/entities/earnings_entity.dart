class EarningsEntity {
  final double weeklyTotal;
  final int jobCount;
  final double averageRating;
  final List<double> dailyBreakdown;

  const EarningsEntity({
    required this.weeklyTotal,
    required this.jobCount,
    required this.averageRating,
    required this.dailyBreakdown,
  });
}

class TransactionEntity {
  final String id;
  final String title;
  final double gross;
  final double platformFee;
  final double net;
  final DateTime date;

  const TransactionEntity({
    required this.id,
    required this.title,
    required this.gross,
    required this.platformFee,
    required this.net,
    required this.date,
  });
}
