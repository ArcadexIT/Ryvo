import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/domain/entities/provider_entity.dart';
import '../di_providers.dart';

class AuthState {
  final ProviderEntity? user;
  const AuthState({this.user});
  bool get isAuthenticated => user != null;
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final repo = ref.read(authRepositoryProvider);
    repo.authStateChanges().listen((user) {
      state = AsyncData(AuthState(user: user));
    });
    return const AuthState();
  }

  Future<void> login(String phone, String password) async {
    state = const AsyncLoading();
    final result = await ref.read(loginUseCaseProvider)(phone: phone, password: password);
    state = result.fold(
      (f) => AsyncError(f, StackTrace.current),
      (user) => AsyncData(AuthState(user: user)),
    );
  }

  Future<void> logout() async {
    await ref.read(logoutUseCaseProvider)();
    state = const AsyncData(AuthState());
  }
}
