sealed class Failure {
  const Failure(this.message);
  final String message;
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error occurred']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Cache error']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class KycFailure extends Failure {
  const KycFailure([super.message = 'KYC verification failed']);
}

class JobFailure extends Failure {
  const JobFailure([super.message = 'Job operation failed']);
}
