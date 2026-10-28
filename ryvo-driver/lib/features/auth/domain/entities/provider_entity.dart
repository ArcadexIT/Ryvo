class ProviderEntity {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String? avatarUrl;
  final double rating;
  final int totalTrips;
  final bool kycApproved;
  final String verificationStatus;
  final bool isOnline;
  final String onlineStatus;

  const ProviderEntity({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.avatarUrl,
    this.rating = 0,
    this.totalTrips = 0,
    this.kycApproved = false,
    this.verificationStatus = 'pending',
    this.isOnline = false,
    this.onlineStatus = 'offline',
  });
}
