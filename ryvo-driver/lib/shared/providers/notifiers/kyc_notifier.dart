import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/kyc/domain/entities/kyc_entity.dart';
import '../di_providers.dart';

class KycUiState {
  final KycStateEntity kyc;
  final bool isUploading;
  const KycUiState({this.kyc = const KycStateEntity(), this.isUploading = false});
}

class KycNotifier extends AsyncNotifier<KycUiState> {
  @override
  Future<KycUiState> build() async {
    final repo = ref.read(kycRepositoryProvider);
    repo.watchKycStatus().listen((kyc) {
      state = AsyncData(KycUiState(kyc: kyc));
    });
    return const KycUiState();
  }

  Future<void> uploadDocument(KycDocumentType type, String filePath) async {
    state = AsyncData(KycUiState(kyc: state.value?.kyc ?? const KycStateEntity(), isUploading: true));
    await ref.read(kycRepositoryProvider).uploadDocument(type: type, filePath: filePath);
    state = AsyncData(KycUiState(kyc: state.value?.kyc ?? const KycStateEntity()));
  }
}
