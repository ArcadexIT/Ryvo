import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../features/wallet/domain/entities/wallet_entity.dart';
import '../di_providers.dart';

class WalletUiState {
  final WalletEntity? wallet;
  final bool isWithdrawing;
  const WalletUiState({this.wallet, this.isWithdrawing = false});
}

class WalletNotifier extends AsyncNotifier<WalletUiState> {
  @override
  Future<WalletUiState> build() async {
    return const WalletUiState();
  }

  Future<void> loadBalance() async {
    state = const AsyncLoading();
    final result = await ref.read(walletRepositoryProvider).getBalance();
    state = result.fold(
      (f) => AsyncError(f, StackTrace.current),
      (w) => AsyncData(WalletUiState(wallet: w)),
    );
  }

  Future<void> withdraw(double amount, String bankAccountId) async {
    final previous = state.value?.wallet;
    state = AsyncData(WalletUiState(wallet: previous, isWithdrawing: true));
    final result = await ref.read(walletRepositoryProvider).withdraw(
      WithdrawRequest(amount: amount, bankAccountId: bankAccountId),
    );
    await result.fold(
      (f) async {
        state = AsyncData(WalletUiState(wallet: previous, isWithdrawing: false));
        throw f;
      },
      (_) => loadBalance(),
    );
  }
}
