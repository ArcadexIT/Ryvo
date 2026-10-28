import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/session_manager.dart';
import '../../domain/entities/provider_entity.dart';
import '../../domain/repositories/i_auth_repository.dart';

ProviderEntity _providerFromProfile(Map<String, dynamic> data) {
  final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? const {};
  double toD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
  return ProviderEntity(
    id: data['id'] as String? ?? '',
    name: user['fullName'] as String? ?? '',
    phone: user['phone'] as String? ?? '',
    email: user['email'] as String? ?? '',
    avatarUrl: user['avatarUrl'] as String?,
    rating: toD(data['ratingAvg']),
    totalTrips: (data['totalJobs'] as num?)?.toInt() ?? 0,
    kycApproved: data['verificationStatus'] == 'approved',
    verificationStatus: data['verificationStatus'] as String? ?? 'pending',
    onlineStatus: data['onlineStatus'] as String? ?? 'offline',
    isOnline: data['onlineStatus'] == 'online' || data['onlineStatus'] == 'busy',
  );
}

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio, this._session);
  final Dio _dio;
  final SessionManager _session;

  Map<String, dynamic> _data(Response res) {
    final body = res.data;
    if (body is Map && body['data'] is Map) {
      return (body['data'] as Map).cast<String, dynamic>();
    }
    return (body as Map).cast<String, dynamic>();
  }

  Future<void> _persistTokens(Map<String, dynamic> tokens) async {
    await _session.saveTokens(
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
    );
  }

  Future<ProviderEntity> _loadProfile() async {
    final res = await _dio.get('/provider/profile');
    final data = _data(res);
    await _session.saveIds(
      providerId: data['id'] as String?,
      userId: (data['user'] as Map?)?['id'] as String?,
    );
    return _providerFromProfile(data);
  }

  Future<ProviderEntity> login({required String phone, required String password}) async {
    final res = await _dio.post('/provider/auth/login', data: {'phone': phone, 'password': password});
    await _persistTokens(_data(res));
    return _loadProfile();
  }

  Future<ProviderEntity> register({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final res = await _dio.post('/provider/auth/register', data: {
      'fullName': name,
      'phone': phone,
      if (email.isNotEmpty) 'email': email,
      'password': password,
    });
    await _persistTokens(_data(res));
    return _loadProfile();
  }

  Future<void> verifyOtp({required String phone, required String otp}) async {
    final res = await _dio.post('/provider/auth/otp/verify', data: {
      'phone': phone,
      'code': otp,
      'purpose': 'register',
    });
    final data = _data(res);
    if (data['accessToken'] != null) {
      await _persistTokens(data);
    }
  }

  Future<void> logout() async {
    final refresh = await _session.getRefreshToken();
    if (refresh != null) {
      try {
        await _dio.post('/provider/auth/logout', data: {'refreshToken': refresh});
      } catch (_) {}
    }
    await _session.clear();
  }

  Future<ProviderEntity?> currentProvider() async {
    if (!await _session.hasSession()) return null;
    try {
      return await _loadProfile();
    } catch (_) {
      return null;
    }
  }
}

class AuthRepositoryImpl implements IAuthRepository {
  AuthRepositoryImpl(this._remote);
  final AuthRemoteDataSource _remote;

  final _authState = StreamController<ProviderEntity?>.broadcast();

  Failure _map(Object e) {
    if (e is Failure) return e;
    if (e is DioException) {
      final msg = (e.response?.data is Map ? e.response?.data['message'] : null) ?? e.message;
      return AuthFailure(msg?.toString() ?? 'Authentication failed');
    }
    return AuthFailure(e.toString());
  }

  @override
  Future<Either<Failure, ProviderEntity>> login({required String phone, required String password}) async {
    try {
      final result = await _remote.login(phone: phone, password: password);
      _authState.add(result);
      return Right(result);
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, ProviderEntity>> register({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    try {
      final result = await _remote.register(name: name, phone: phone, email: email, password: password);
      _authState.add(result);
      return Right(result);
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, void>> verifyOtp({required String phone, required String otp}) async {
    try {
      await _remote.verifyOtp(phone: phone, otp: otp);
      return const Right(null);
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _remote.logout();
      _authState.add(null);
      return const Right(null);
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Stream<ProviderEntity?> authStateChanges() => _authState.stream;

  /// Resolve the currently persisted provider (used on app startup).
  Future<ProviderEntity?> currentProvider() => _remote.currentProvider();
}
