import 'package:dio/dio.dart';

/// Vehicle make/model catalog backed by the public NHTSA VPIC API.
/// https://vpic.nhtsa.dot.gov/api/
class VpicVehicleCatalogService {
  VpicVehicleCatalogService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://vpic.nhtsa.dot.gov/api/vehicles',
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: const {'Accept': 'application/json'},
              ),
            );

  final Dio _dio;

  Future<List<String>> fetchMakes(String vehicleType) async {
    final type = _normalizeType(vehicleType);
    final response = await _dio.get<Map<String, dynamic>>(
      '/GetMakesForVehicleType/$type',
      queryParameters: const {'format': 'json'},
    );
    return _extractUniqueSorted(
      response.data?['Results'],
      keys: const ['MakeName', 'Make_Name'],
    );
  }

  Future<List<String>> fetchModels(String vehicleType, String make) async {
    final type = _normalizeType(vehicleType);
    final encodedMake = Uri.encodeComponent(make.trim());
    final response = await _dio.get<Map<String, dynamic>>(
      '/GetModelsForMake/$encodedMake',
      queryParameters: const {'format': 'json'},
    );
    return _extractModels(response.data?['Results'], type);
  }

  List<String> _extractModels(dynamic results, String type) {
    if (results is! List) return const [];

    final names = <String>{};
    for (final entry in results.whereType<Map>()) {
      final typeName = (entry['VehicleTypeName'] ?? entry['vehicleTypeName'])?.toString().toLowerCase() ?? '';
      if (typeName.isNotEmpty) {
        final isMotorcycle = typeName.contains('motorcycle');
        if (type == 'motorcycle' && !isMotorcycle) continue;
        if (type != 'motorcycle' && isMotorcycle) continue;
      }
      for (final key in const ['Model_Name', 'ModelName']) {
        final value = entry[key]?.toString().trim();
        if (value != null && value.isNotEmpty) {
          names.add(value);
          break;
        }
      }
    }

    final sorted = names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  List<String> _extractUniqueSorted(dynamic results, {required List<String> keys}) {
    if (results is! List) return const [];

    final names = <String>{};
    for (final entry in results.whereType<Map>()) {
      for (final key in keys) {
        final value = entry[key]?.toString().trim();
        if (value != null && value.isNotEmpty) {
          names.add(value);
          break;
        }
      }
    }

    final sorted = names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  String _normalizeType(String vehicleType) {
    switch (vehicleType.trim().toLowerCase()) {
      case 'motorcycle':
        return 'motorcycle';
      case 'car':
      default:
        return 'car';
    }
  }
}
