import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/earnings/domain/entities/earnings_entity.dart';
import '../di_providers.dart';

class EarningsUiState {
  final EarningsEntity? earnings;
  final List<TransactionEntity> history;
  const EarningsUiState({this.earnings, this.history = const []});
}

class EarningsNotifier extends AsyncNotifier<EarningsUiState> {
  @override
  Future<EarningsUiState> build() async {
    return const EarningsUiState();
  }

  Future<void> load() async {
    state = const AsyncLoading();
    final repo = ref.read(earningsRepositoryProvider);
    final weekly = await repo.getWeeklyEarnings();
    final history = await repo.getEarningsHistory();
    state = weekly.fold(
      (f) => AsyncError(f, StackTrace.current),
      (e) => AsyncData(EarningsUiState(
        earnings: e,
        history: history.fold((_) => const [], (h) => h),
      )),
    );
  }

  Future<void> loadWeekly() => load();
}
