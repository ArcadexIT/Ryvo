import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class VehicleInfoPage extends ConsumerStatefulWidget {
  const VehicleInfoPage({super.key});

  @override
  ConsumerState<VehicleInfoPage> createState() => _VehicleInfoPageState();
}

class _VehicleInfoPageState extends ConsumerState<VehicleInfoPage> {
  static const _otherOption = 'Other';

  final _formKey = GlobalKey<FormState>();
  final _year = TextEditingController();
  final _plate = TextEditingController();
  final _customMake = TextEditingController();
  final _customModel = TextEditingController();
  final _color = TextEditingController();
  final _engineCapacity = TextEditingController();
  File? _vehiclePhoto;
  String? _existingPhotoUrl;
  bool _initialized = false;
  bool _hasExisting = false;
  bool _saving = false;

  String? _vehicleType;
  String? _selectedMake;
  String? _selectedModel;
  String? _transmission;
  String? _fuelType;
  List<String> _makes = const [];
  List<String> _models = const [];
  List<Map<String, String>> _rideClassOptions = const [];
  final Set<String> _rideClasses = {};
  bool _loadingMakes = false;
  bool _loadingModels = false;

  bool get _isOtherMake => _selectedMake == _otherOption;
  bool get _isOtherModel => _isOtherMake || _selectedModel == _otherOption;

  @override
  void dispose() {
    _year.dispose();
    _plate.dispose();
    _customMake.dispose();
    _customModel.dispose();
    _color.dispose();
    _engineCapacity.dispose();
    super.dispose();
  }

  Future<void> _initFromVehicle(Map<String, dynamic>? v) async {
    if (_initialized) return;
    _initialized = true;
    _vehicleType = (v?['vehicleType']?.toString() == 'motorcycle') ? 'motorcycle' : (v != null ? 'car' : null);
    _selectedMake = v?['make']?.toString();
    _selectedModel = v?['model']?.toString();
    final transmission = v?['transmission']?.toString();
    _transmission = (transmission == 'manual' || transmission == 'auto') ? transmission : null;
    final fuelType = v?['fuelType']?.toString();
    _fuelType = (fuelType == 'petrol' || fuelType == 'diesel' || fuelType == 'electric') ? fuelType : null;
    _hasExisting = v != null;
    final year = v?['year']?.toString() ?? '';
    _year.text = year == '0' ? '' : year;
    _plate.text = (v?['plateNumber']?.toString() ?? '').toUpperCase();
    _color.text = v?['color']?.toString() ?? '';
    _engineCapacity.text = v?['engineCapacity']?.toString() ?? '';
    final photo = v?['photoUrl']?.toString();
    _existingPhotoUrl = (photo == null || photo.isEmpty) ? null : photo;
    _rideClasses
      ..clear()
      ..addAll(_capabilitySlugs(v?['serviceCapabilities']));
    await _loadRideClasses();
    _keepActiveRideClasses();
    if (_vehicleType != null) {
      await _loadMakes(preserveSelection: true);
      if (_selectedMake != null && _selectedMake!.isNotEmpty) {
        await _loadModels(preserveSelection: true);
      }
    }
    if (mounted) setState(() {});
  }

  Iterable<String> _capabilitySlugs(dynamic raw) {
    if (raw is List) return raw.map((e) => '$e'.trim()).where((e) => e.isNotEmpty);
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    }
    return const [];
  }

  void _keepActiveRideClasses() {
    if (_rideClassOptions.isEmpty) return;
    final allowed = _rideClassOptions.map((item) => item['slug']!).toSet();
    _rideClasses.removeWhere((slug) => !allowed.contains(slug));
  }

  List<String> _selectedRideClassSlugs() {
    final allowed = _rideClassOptions.map((item) => item['slug']!).toSet();
    return _rideClasses.where(allowed.contains).toList();
  }

  Future<void> _loadRideClasses() async {
    try {
      final res = await ref.read(dioClientProvider).dio.get('/provider/ride-classes');
      final body = res.data;
      final data = body is Map && body['data'] is List ? body['data'] as List : body;
      if (data is! List) return;
      _rideClassOptions = data.whereType<Map>().map((item) {
        final map = item.cast<String, dynamic>();
        return {'slug': '${map['slug'] ?? ''}', 'name': '${map['name'] ?? map['slug'] ?? ''}'};
      }).where((item) => item['slug']!.isNotEmpty).toList();
    } catch (_) {}
  }

  Future<void> _onTypeChanged(String? type) async {
    if (type == null || type == _vehicleType) return;
    setState(() {
      _vehicleType = type;
      _selectedMake = null;
      _selectedModel = null;
      _makes = const [];
      _models = const [];
      _customMake.clear();
      _customModel.clear();
    });
    await _loadMakes();
  }

  Future<void> _onMakeChanged(String? make) async {
    if (make == null) return;
    _customMake.clear();
    _customModel.clear();
    if (make == _otherOption) {
      setState(() {
        _selectedMake = _otherOption;
        _selectedModel = _otherOption;
        _models = const [_otherOption];
      });
      return;
    }
    setState(() {
      _selectedMake = make;
      _selectedModel = null;
      _models = const [];
    });
    await _loadModels();
  }

  Future<void> _loadMakes({bool preserveSelection = false}) async {
    final type = _vehicleType;
    if (type == null) return;
    setState(() => _loadingMakes = true);
    try {
      final res = await ref.read(dioClientProvider).dio.get(
        '/vehicle-catalog/makes',
        queryParameters: {'type': type},
      );
      final body = res.data;
      final data = body is Map && body.containsKey('data') ? body['data'] : body;
      final items = _withOther(_catalogItems(data));
      if (!mounted) return;
      setState(() {
        _makes = items;
        if (preserveSelection) {
          _adoptCustomMake(items);
        } else {
          _selectedMake = null;
          _selectedModel = null;
          _customMake.clear();
          _models = const [];
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).couldNotLoadMakes, style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMakes = false);
    }
  }

  Future<void> _loadModels({bool preserveSelection = false}) async {
    final type = _vehicleType;
    final make = _selectedMake;
    if (type == null || make == null || make.isEmpty || make == _otherOption) {
      if (make == _otherOption && mounted) {
        setState(() {
          _models = const [_otherOption];
          if (_selectedModel != null &&
              _selectedModel != _otherOption &&
              _selectedModel!.isNotEmpty) {
            _customModel.text = _selectedModel!;
          }
          _selectedModel = _otherOption;
        });
      }
      return;
    }
    setState(() => _loadingModels = true);
    try {
      final res = await ref.read(dioClientProvider).dio.get(
        '/vehicle-catalog/models',
        queryParameters: {'type': type, 'make': make},
      );
      final body = res.data;
      final data = body is Map && body.containsKey('data') ? body['data'] : body;
      final items = _withOther(_catalogItems(data));
      if (!mounted) return;
      setState(() {
        _models = items;
        if (preserveSelection) {
          _adoptCustomModel(items);
        } else {
          _selectedModel = null;
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).couldNotLoadModels, style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  List<String> _catalogItems(dynamic data) {
    if (data is Map && data['items'] is List) {
      return (data['items'] as List).whereType<String>().toList();
    }
    return const [];
  }

  List<String> _withOther(List<String> items) {
    final rest = items.where((item) => item != _otherOption);
    return [_otherOption, ...rest];
  }

  void _adoptCustomMake(List<String> catalog) {
    final current = _selectedMake;
    if (current == null || current.isEmpty || current == _otherOption || catalog.contains(current)) return;
    _customMake.text = current;
    _selectedMake = _otherOption;
  }

  void _adoptCustomModel(List<String> catalog) {
    final current = _selectedModel;
    if (current == null || current.isEmpty || current == _otherOption || catalog.contains(current)) return;
    _customModel.text = current;
    _selectedModel = _otherOption;
  }

  String? _savedMake() => _isOtherMake ? _customMake.text.trim() : _selectedMake;

  String? _savedModel() => _isOtherModel ? _customModel.text.trim() : _selectedModel;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _vehiclePhoto = File(picked.path);
        _existingPhotoUrl = null;
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final rideClassSlugs = _selectedRideClassSlugs();
    if (rideClassSlugs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one ride class.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      String? photoUrl = _existingPhotoUrl;
      if (_vehiclePhoto != null) {
        try {
          photoUrl = await ref.read(fileUploadServiceProvider).uploadProviderFile(
            localPath: _vehiclePhoto!.path,
            folder: 'vehicles',
          );
        } catch (_) {
          // Photo upload failure is non-fatal — continue without a new photo.
        }
      }
      await ref.read(dioClientProvider).dio.patch('/provider/vehicle', data: {
        'vehicleType': _vehicleType,
        'make': _savedMake(),
        'model': _savedModel(),
        'year': int.tryParse(_year.text.trim()) ?? 0,
        'plateNumber': _plate.text.trim().toUpperCase(),
        'transmission': _transmission,
        'fuelType': _fuelType,
        if (_color.text.trim().isNotEmpty) 'color': _color.text.trim(),
        if (_engineCapacity.text.trim().isNotEmpty)
          'engineCapacity': _engineCapacity.text.trim(),
        if (_vehiclePhoto != null && photoUrl != null) 'photoUrl': photoUrl,
        'rideClassSlugs': rideClassSlugs,
      });
      ref.invalidate(providerVehicleProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).vehicleUpdated, style: GoogleFonts.poppins()), backgroundColor: AppColors.success),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final failure = e is DioException ? e.error : null;
      final message = failure is Failure && failure.message.trim().isNotEmpty
          ? failure.message
          : AppLocalizations.of(context).couldNotSaveVehicle;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message, style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vehicle = ref.watch(providerVehicleProvider);
    final hasExisting = vehicle.maybeWhen(data: (v) => v != null, orElse: () => _hasExisting);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          hasExisting ? l10n.editVehicle : l10n.addYourVehicle,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
        ),
      ),
      body: vehicle.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(l10n.couldNotLoadVehicle, style: GoogleFonts.poppins(color: AppColors.textSecondary))),
        data: (v) {
          if (!_initialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _initFromVehicle(v));
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPhotoPicker(context),
                    const SizedBox(height: 24),
                    RyvoTextField(
                      hint: l10n.abc1234,
                      label: l10n.licensePlate,
                      controller: _plate,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: const [UpperCaseTextFormatter()],
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                      validator: (v) => (v?.isEmpty ?? true) ? l10n.enterPlate : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 24),
                    Text('Ride classes', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in _rideClassOptions)
                          FilterChip(
                            label: Text(option['name'] ?? option['slug']!),
                            selected: _rideClasses.contains(option['slug']),
                            onSelected: (selected) {
                              setState(() {
                                final slug = option['slug']!;
                                if (selected) {
                                  _rideClasses.add(slug);
                                } else {
                                  _rideClasses.remove(slug);
                                }
                              });
                            },
                          ),
                        if (_rideClassOptions.isEmpty)
                          Text('Ride classes appear once the API is running.', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.vehicleType,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          key: ValueKey('vehicle-type-$_vehicleType'),
                          initialValue: _vehicleType,
                          hint: Text(l10n.selectType, style: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 14)),
                          dropdownColor: AppColors.modal,
                          style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 15),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.divider),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.divider),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          items: [
                            DropdownMenuItem(value: 'car', child: Text(l10n.car)),
                            DropdownMenuItem(value: 'motorcycle', child: Text(l10n.motorcycle)),
                          ],
                          onChanged: _onTypeChanged,
                          validator: (val) => val == null ? l10n.selectVehicleType : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SearchableDropdownField(
                      label: l10n.make,
                      hint: _vehicleType == null ? l10n.selectTypeFirst : l10n.searchMake,
                      value: _selectedMake,
                      options: _makes,
                      pinnedOptions: const [_otherOption],
                      enabled: _vehicleType != null,
                      loading: _loadingMakes,
                      onChanged: _onMakeChanged,
                      validator: (val) => (val == null || val.isEmpty) ? l10n.selectAMake : null,
                    ),
                    if (_isOtherMake) ...[
                      const SizedBox(height: 16),
                      RyvoTextField(
                        hint: l10n.enterMake,
                        label: l10n.makeName,
                        controller: _customMake,
                        prefixIcon: const Icon(Icons.directions_car_outlined, size: 20),
                        validator: (v) => (v == null || v.trim().isEmpty) ? l10n.enterAMake : null,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      RyvoTextField(
                        hint: l10n.enterModel,
                        label: l10n.modelName,
                        controller: _customModel,
                        prefixIcon: const Icon(Icons.car_repair_outlined, size: 20),
                        validator: (v) => (v == null || v.trim().isEmpty) ? l10n.enterAModel : null,
                        textInputAction: TextInputAction.next,
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      SearchableDropdownField(
                        label: l10n.model,
                        hint: _selectedMake == null ? l10n.selectMakeFirst : l10n.searchModel,
                        value: _selectedModel,
                        options: _models,
                        pinnedOptions: const [_otherOption],
                        enabled: _selectedMake != null,
                        loading: _loadingModels,
                        onChanged: (val) {
                          setState(() {
                            _selectedModel = val;
                            if (val != _otherOption) {
                              _customModel.clear();
                            }
                          });
                        },
                        validator: (val) => (val == null || val.isEmpty) ? l10n.selectAModel : null,
                      ),
                      if (_selectedModel == _otherOption) ...[
                        const SizedBox(height: 16),
                        RyvoTextField(
                          hint: l10n.enterModel,
                          label: l10n.modelName,
                          controller: _customModel,
                          prefixIcon: const Icon(Icons.car_repair_outlined, size: 20),
                          validator: (v) => (v == null || v.trim().isEmpty) ? l10n.enterAModel : null,
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    RyvoTextField(
                      hint: '2022',
                      label: l10n.year,
                      controller: _year,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                      validator: (v) => (v?.length ?? 0) != 4 ? l10n.enter4DigitYear : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _VehicleSimpleDropdown(
                            label: l10n.transmission,
                            value: _transmission,
                            hint: l10n.select,
                            items: [
                              DropdownMenuItem(value: 'manual', child: Text(l10n.manual)),
                              DropdownMenuItem(value: 'auto', child: Text(l10n.auto)),
                            ],
                            onChanged: (val) => setState(() => _transmission = val),
                            validator: (val) => val == null ? l10n.selectTransmission : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _VehicleSimpleDropdown(
                            label: l10n.fuelType,
                            value: _fuelType,
                            hint: l10n.select,
                            items: [
                              DropdownMenuItem(value: 'petrol', child: Text(l10n.petrol)),
                              DropdownMenuItem(value: 'diesel', child: Text(l10n.diesel)),
                              DropdownMenuItem(value: 'electric', child: Text(l10n.electric)),
                            ],
                            onChanged: (val) => setState(() => _fuelType = val),
                            validator: (val) => val == null ? l10n.selectFuelType : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: RyvoTextField(
                            hint: 'Black',
                            label: 'Colour',
                            controller: _color,
                            prefixIcon: const Icon(Icons.palette_outlined, size: 20),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: RyvoTextField(
                            hint: '1998',
                            label: 'Engine Capacity (cc)',
                            controller: _engineCapacity,
                            keyboardType: TextInputType.number,
                            prefixIcon: const Icon(Icons.speed_outlined, size: 20),
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    RyvoButton(
                      label: _saving
                          ? (_vehiclePhoto != null ? l10n.uploadingPhoto : l10n.saving)
                          : (v != null ? l10n.updateVehicle : l10n.saveVehicle),
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotoPicker(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasPhoto = _vehiclePhoto != null || _existingPhotoUrl != null;

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: hasPhoto ? 160 : null,
        padding: hasPhoto ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasPhoto ? AppColors.primary : AppColors.divider,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasPhoto
            ? Stack(
                fit: StackFit.expand,
                children: [
                  if (_vehiclePhoto != null)
                    Image.file(_vehiclePhoto!, fit: BoxFit.cover)
                  else
                    Image.network(_existingPhotoUrl!, fit: BoxFit.cover),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      color: Colors.black.withValues(alpha: 0.45),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Tap to change photo',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined, color: AppColors.primaryDark, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.addVehiclePhoto,
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                        ),
                        Text(
                          l10n.optional,
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.grey400, size: 22),
                ],
              ),
      ),
    );
  }
}

class _VehicleSimpleDropdown extends StatelessWidget {
  const _VehicleSimpleDropdown({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    required this.validator,
  });

  final String label;
  final String? value;
  final String hint;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey('$label-$value'),
          initialValue: value,
          hint: Text(hint, style: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 14)),
          dropdownColor: AppColors.modal,
          style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: items,
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }
}

class PaymentMethodsPage extends ConsumerWidget {
  const PaymentMethodsPage({super.key});

  Future<void> _setPrimary(WidgetRef ref, BuildContext context, String id) async {
    try {
      await ref.read(dioClientProvider).dio.patch('/provider/bank-accounts/$id/primary');
      ref.invalidate(bankAccountsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).primaryAccountUpdated, style: GoogleFonts.poppins()), backgroundColor: AppColors.success),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).couldNotUpdateAccount, style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteAccount(WidgetRef ref, BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(AppLocalizations.of(context).removeBankAccount, style: GoogleFonts.poppins(color: AppColors.textPrimary)),
        content: Text(AppLocalizations.of(context).thisAccountWillBeRemovedFromYourPayoutMethods, style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context).cancel, style: GoogleFonts.poppins(color: AppColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(context).remove, style: GoogleFonts.poppins(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(dioClientProvider).dio.delete('/provider/bank-accounts/$id');
      ref.invalidate(bankAccountsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).bankAccountRemoved, style: GoogleFonts.poppins()), backgroundColor: AppColors.success),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).couldNotRemoveAccount, style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(bankAccountsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppLocalizations.of(context).paymentMethods2, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-bank-account'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context).addAccount, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(AppLocalizations.of(context).couldNotLoadAccounts, style: GoogleFonts.poppins(color: AppColors.textSecondary))),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_outlined, color: AppColors.textSecondary, size: 48),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context).noPayoutMethodAddedYet,
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text(AppLocalizations.of(context).addABankAccountToReceiveYourEarningsWhenYouWithd,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 24),
                    RyvoButton(label: AppLocalizations.of(context).addBankAccount, onPressed: () => context.push('/add-bank-account')),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final account = items[i];
              final id = account['id']?.toString() ?? '';
              final bankName = account['bankName']?.toString() ?? AppLocalizations.of(context).bank;
              final lastFour = account['lastFour']?.toString() ?? '----';
              final holder = account['accountHolder']?.toString() ?? '';
              final isPrimary = account['isPrimary'] == true;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isPrimary ? AppColors.primary : AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: AppColors.info.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.account_balance, color: AppColors.info),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(bankName, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              Text('•••• $lastFour', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                              if (holder.isNotEmpty)
                                Text(holder, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint)),
                            ],
                          ),
                        ),
                        if (isPrimary)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                            child: Text(AppLocalizations.of(context).primary, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ),
                      ],
                    ),
                    if (!isPrimary) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => _setPrimary(ref, context, id),
                            child: Text(AppLocalizations.of(context).setAsPrimary, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.primary)),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => _deleteAccount(ref, context, id),
                            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => _deleteAccount(ref, context, id),
                          icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: Text(AppLocalizations.of(context).languageRegion)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _LangTile(
            label: AppLocalizations.of(context).english,
            selected: Localizations.localeOf(context).languageCode == 'en',
          ),
        ],
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  final String label;
  final bool selected;
  const _LangTile({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
      ),
      child: ListTile(
        title: Text(label, style: GoogleFonts.poppins(color: AppColors.textPrimary)),
        trailing: selected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
      ),
    );
  }
}
