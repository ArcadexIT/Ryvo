/// A country enabled by the admin for registration/login (phone dial code + flag).
class CountryEntity {
  const CountryEntity({
    required this.name,
    required this.code,
    required this.code3,
    required this.numeric,
    required this.dialCode,
    required this.icon,
  });

  factory CountryEntity.fromJson(Map<String, dynamic> json) => CountryEntity(
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
        code3: json['code3'] as String? ?? '',
        numeric: json['numeric'] as String? ?? '',
        dialCode: json['dialCode'] as String? ?? '',
        icon: json['icon'] as String? ?? '',
      );

  final String name;
  final String code;
  final String code3;
  final String numeric;
  final String dialCode;
  final String icon;
}
