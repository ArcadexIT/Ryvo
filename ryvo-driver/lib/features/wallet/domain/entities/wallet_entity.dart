class WalletEntity {
  final double availableBalance;
  final double pendingBalance;

  const WalletEntity({required this.availableBalance, required this.pendingBalance});
}

class WithdrawRequest {
  final double amount;
  final String bankAccountId;

  const WithdrawRequest({required this.amount, required this.bankAccountId});
}
