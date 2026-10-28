import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/provider_socket.dart';
import '../../core/network/session_manager.dart';
import '../../core/services/file_upload_service.dart';
import '../../core/services/file_access_service.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/i_auth_repository.dart';
import '../../features/auth/domain/usecases/auth_usecases.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/i_chat_repository.dart';
import '../../features/earnings/data/repositories/earnings_repository_impl.dart';
import '../../features/earnings/domain/repositories/i_earnings_repository.dart';
import '../../features/job/data/repositories/job_repository_impl.dart';
import '../../features/job/domain/repositories/i_job_repository.dart';
import '../../features/kyc/data/repositories/kyc_repository_impl.dart';
import '../../features/kyc/domain/repositories/i_kyc_repository.dart';
import '../../features/location/data/repositories/location_repository_impl.dart';
import '../../features/location/domain/repositories/i_location_repository.dart';
import '../../features/wallet/data/repositories/wallet_repository_impl.dart';
import '../../features/wallet/domain/repositories/i_wallet_repository.dart';
import 'notifiers/auth_notifier.dart';
import 'notifiers/availability_notifier.dart';
import 'notifiers/chat_notifier.dart';
import 'notifiers/earnings_notifier.dart';
import 'notifiers/job_notifier.dart';
import 'notifiers/kyc_notifier.dart';
import 'notifiers/wallet_notifier.dart';

final sessionManagerProvider = Provider<SessionManager>((ref) => SessionManager());

final dioClientProvider = Provider((ref) => DioClient());

final fileUploadServiceProvider = Provider(
  (ref) => FileUploadService(ref.read(dioClientProvider).dio),
);

final fileAccessServiceProvider = Provider(
  (ref) => FileAccessService(ref.read(dioClientProvider).dio),
);

final providerSocketProvider = Provider<ProviderSocket>((ref) {
  final socket = ProviderSocket(ref.read(sessionManagerProvider));
  ref.onDispose(socket.dispose);
  return socket;
});

final authRepositoryProvider = Provider<IAuthRepository>((ref) => AuthRepositoryImpl(
      AuthRemoteDataSource(ref.read(dioClientProvider).dio, ref.read(sessionManagerProvider)),
    ));
final kycRepositoryProvider = Provider<IKycRepository>((ref) => KycRepositoryImpl(
      KycRemoteDataSource(ref.read(dioClientProvider).dio, ref.read(fileUploadServiceProvider)),
    ));
final jobRepositoryProvider = Provider<IJobRepository>((ref) => JobRepositoryImpl(
      JobRemoteDataSource(ref.read(dioClientProvider).dio, ref.read(providerSocketProvider)),
    ));
final locationRepositoryProvider = Provider<ILocationRepository>((ref) => LocationRepositoryImpl(
      LocationRemoteDataSource(ref.read(dioClientProvider).dio, ref.read(providerSocketProvider)),
    ));
final earningsRepositoryProvider = Provider<IEarningsRepository>((ref) => EarningsRepositoryImpl(EarningsRemoteDataSource(ref.read(dioClientProvider).dio)));
final walletRepositoryProvider = Provider<IWalletRepository>((ref) => WalletRepositoryImpl(WalletRemoteDataSource(ref.read(dioClientProvider).dio)));
final chatRepositoryProvider = Provider<IChatRepository>((ref) => ChatRepositoryImpl(
      ChatRemoteDataSource(ref.read(dioClientProvider).dio, ref.read(providerSocketProvider)),
    ));

final loginUseCaseProvider = Provider((ref) => LoginUseCase(ref.read(authRepositoryProvider)));
final registerUseCaseProvider = Provider((ref) => RegisterUseCase(ref.read(authRepositoryProvider)));
final verifyOtpUseCaseProvider = Provider((ref) => VerifyOtpUseCase(ref.read(authRepositoryProvider)));
final logoutUseCaseProvider = Provider((ref) => LogoutUseCase(ref.read(authRepositoryProvider)));

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isOfflineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.maybeWhen(
    data: (results) => results.every((r) => r == ConnectivityResult.none),
    orElse: () => false,
  );
});

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
final kycNotifierProvider = AsyncNotifierProvider<KycNotifier, KycUiState>(KycNotifier.new);
final availabilityNotifierProvider = NotifierProvider<AvailabilityNotifier, bool>(AvailabilityNotifier.new);
final jobNotifierProvider = AsyncNotifierProvider<JobNotifier, JobUiState>(JobNotifier.new);
final locationStreamProvider = StreamProvider((ref) => ref.read(locationRepositoryProvider).watchCurrentLocation());
final earningsNotifierProvider = AsyncNotifierProvider<EarningsNotifier, EarningsUiState>(EarningsNotifier.new);
final walletNotifierProvider = AsyncNotifierProvider<WalletNotifier, WalletUiState>(WalletNotifier.new);
final chatNotifierProvider = AsyncNotifierProvider.family<ChatNotifier, ChatUiState, String>(ChatNotifier.new);
