import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/iterable_extensions.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class AddVehiclePage extends ConsumerStatefulWidget {
  const AddVehiclePage({super.key, this.vehicleId});

  final String? vehicleId;

  @override
  ConsumerState<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends ConsumerState<AddVehiclePage> {
  static const _otherOption = 'Other';

  final _formKey = GlobalKey<FormState>();
  final _yearController = TextEditingController();
  final _plateController = TextEditingController();
  final _customMakeController = TextEditingController();
  final _customModelController = TextEditingController();
  final _colorController = TextEditingController();
  final _engineCapacityController = TextEditingController();
  File? _vehiclePhoto;
  String? _existingPhotoUrl;
  bool _loading = false;
  bool _loadingVehicle = false;
  bool _lookingUp = false;
  bool _lookupApplied = false;

  String? _vehicleType;
  String? _selectedMake;
  String? _selectedModel;
  String? _transmission;
  String? _fuelType;

  List<String> _makes = const [];
  List<String> _models = const [];
  bool _loadingMakes = false;
  bool _loadingModels = false;

  bool get _isEditing => widget.vehicleId != null && widget.vehicleId!.isNotEmpty;
  bool get _isOtherMake => _selectedMake == _otherOption;
  bool get _isOtherModel => _isOtherMake || _selectedModel == _otherOption;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadVehicle());
    }
  }

  @override
  void dispose() {
    _yearController.dispose();
    _plateController.dispose();
    _customMakeController.dispose();
    _customModelController.dispose();
    _colorController.dispose();
    _engineCapacityController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicle() async {
    setState(() => _loadingVehicle = true);
    try {
      Vehicle? vehicle;
      final cached = ref.read(vehiclesProvider).valueOrNull;
      vehicle = cached?.where((v) => v.id == widget.vehicleId).firstOrNull;
      vehicle ??= await ref.read(vehicleRepositoryProvider).getById(widget.vehicleId!);
      if (!mounted) return;
      await _populateForm(vehicle);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loadingVehicle = false);
    }
  }

  Future<void> _populateForm(Vehicle vehicle) async {
    _vehicleType = vehicle.vehicleType == 'motorcycle' ? 'motorcycle' : 'car';
    _selectedMake = vehicle.make;
    _selectedModel = vehicle.model;
    _transmission =
        (vehicle.transmission == 'manual' || vehicle.transmission == 'auto')
            ? vehicle.transmission
            : null;
    _fuelType = (vehicle.fuelType == 'petrol' ||
            vehicle.fuelType == 'diesel' ||
            vehicle.fuelType == 'electric')
        ? vehicle.fuelType
        : null;
    _yearController.text = vehicle.year.toString();
    _plateController.text = vehicle.plateNumber;
    _colorController.text = vehicle.color ?? '';
    _engineCapacityController.text = vehicle.engineCapacity ?? '';
    _existingPhotoUrl = vehicle.photoUrl;
    setState(() {});
    await _loadMakes(preserveSelection: true);
    if (_selectedMake != null && !_isOtherMake) {
      await _loadModels(preserveSelection: true);
    }
  }

  Future<void> _onTypeChanged(String? type) async {
    if (type == null || type == _vehicleType) return;
    setState(() {
      _vehicleType = type;
      _selectedMake = null;
      _selectedModel = null;
      _makes = const [];
      _models = const [];
      _customMakeController.clear();
      _customModelController.clear();
    });
    await _loadMakes();
  }

  Future<void> _onMakeChanged(String? make) async {
    if (make == null) return;
    _customMakeController.clear();
    _customModelController.clear();
    if (make == _otherOption) {
      setState(() {
        _selectedMake = make;
        _selectedModel = _otherOption;
        _models = [_otherOption];
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
      final items = await ref.read(vehicleRepositoryProvider).fetchMakes(type);
      if (!mounted) return;
      setState(() {
        _makes = _withOther(items);
        if (preserveSelection) {
          _adoptCustomIfMissing(
            current: _selectedMake,
            catalog: items,
            onCustom: (value) {
              _customMakeController.text = value;
              _selectedMake = _otherOption;
              if (_selectedModel != null &&
                  _selectedModel!.isNotEmpty &&
                  _selectedModel != _otherOption &&
                  _customModelController.text.isEmpty) {
                _customModelController.text = _selectedModel!;
              }
              _selectedModel = _otherOption;
              _models = [_otherOption];
            },
          );
        } else {
          _selectedMake = null;
          _selectedModel = null;
          _models = const [];
          _customMakeController.clear();
          _customModelController.clear();
        }
      });
    } catch (e) {
      if (mounted) {
        showApiError(context, e);
      }
    } finally {
      if (mounted) setState(() => _loadingMakes = false);
    }
  }

  Future<void> _loadModels({bool preserveSelection = false}) async {
    final type = _vehicleType;
    final make = _selectedMake;
    if (type == null || make == null) return;
    if (make == _otherOption) {
      setState(() {
        _models = [_otherOption];
        if (_selectedModel != null &&
            _selectedModel!.isNotEmpty &&
            _selectedModel != _otherOption &&
            _customModelController.text.isEmpty) {
          _customModelController.text = _selectedModel!;
        }
        _selectedModel = _otherOption;
      });
      return;
    }

    setState(() => _loadingModels = true);
    try {
      final items = await ref.read(vehicleRepositoryProvider).fetchModels(type, make);
      if (!mounted) return;
      setState(() {
        _models = _withOther(items);
        if (preserveSelection) {
          _adoptCustomIfMissing(
            current: _selectedModel,
            catalog: items,
            onCustom: (value) {
              _customModelController.text = value;
              _selectedModel = _otherOption;
            },
          );
        } else {
          _selectedModel = null;
          _customModelController.clear();
        }
      });
    } catch (e) {
      if (mounted) {
        showApiError(context, e);
      }
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  List<String> _withOther(List<String> items) {
    final rest = items.where((item) => item != _otherOption);
    return [_otherOption, ...rest];
  }

  void _adoptCustomIfMissing({
    required String? current,
    required List<String> catalog,
    required void Function(String value) onCustom,
  }) {
    if (current == null || current.isEmpty) return;
    if (current == _otherOption || catalog.contains(current)) return;
    onCustom(current);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _vehiclePhoto = File(picked.path);
        _existingPhotoUrl = null;
      });
    }
  }

  Future<void> _findVehicle() async {
    final plate = _plateController.text.trim();
    if (plate.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a registration first.')));
      return;
    }
    setState(() => _lookingUp = true);
    try {
      final data = await ref.read(apiClientProvider).post<dynamic>(
        '/vehicle-lookup',
        data: {'registration': plate},
      );
      if (data is! Map || !mounted) return;
      final make = '${data['make'] ?? ''}'.trim();
      final model = '${data['model'] ?? ''}'.trim();
      final year = data['year'];
      final fuel = '${data['fuelType'] ?? ''}'.toLowerCase();
      final transmission = '${data['transmission'] ?? ''}'.toLowerCase();
      final vehicleType = '${data['vehicleType'] ?? ''}'.toLowerCase();
      final color = '${data['color'] ?? ''}'.trim();
      final engineCapacity = '${data['engineCapacity'] ?? ''}'.trim();
      setState(() {
        final resolved = '${data['plateNumber'] ?? plate}'.toUpperCase();
        _plateController.text = resolved;
        _lookupApplied = true;
        if (color.isNotEmpty) _colorController.text = color;
        if (engineCapacity.isNotEmpty) _engineCapacityController.text = engineCapacity;
        if (vehicleType == 'car' || vehicleType == 'motorcycle') {
          _vehicleType = vehicleType;
        }
        if (year != null && '$year' != '0' && '$year'.isNotEmpty) {
          _yearController.text = '$year';
        }
        if (fuel == 'petrol' || fuel == 'diesel' || fuel == 'electric') {
          _fuelType = fuel;
        } else if (fuel.contains('hybrid')) {
          _fuelType = fuel.contains('diesel') ? 'diesel' : 'petrol';
        } else if (fuel.contains('diesel')) {
          _fuelType = 'diesel';
        } else if (fuel.contains('petrol')) {
          _fuelType = 'petrol';
        } else if (fuel.contains('electric')) {
          _fuelType = 'electric';
        }
        if (transmission == 'manual' || transmission == 'auto') _transmission = transmission;
        if (make.isNotEmpty) {
          _selectedMake = _otherOption;
          _customMakeController.text = make;
        }
        if (model.isNotEmpty) {
          _selectedModel = _otherOption;
          _customModelController.text = model;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _lookupApplied = false);
        final message = e is ApiException ? e.message : 'Lookup failed. Enter the details manually.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(vehicleRepositoryProvider);
      String? photoUrl = _existingPhotoUrl;

      if (_vehiclePhoto != null) {
        photoUrl = await repo.uploadVehiclePhoto(_vehiclePhoto!);
      }

      final vehicleType = _vehicleType!;
      final make = _isOtherMake ? _customMakeController.text.trim() : _selectedMake!;
      final model = _isOtherModel ? _customModelController.text.trim() : _selectedModel!;
      final year = int.parse(_yearController.text.trim());
      final plateNumber = _plateController.text.trim().toUpperCase();
      final transmission = _transmission!;
      final fuelType = _fuelType!;
      final color = _colorController.text.trim();
      final engineCapacity = _engineCapacityController.text.trim();

      if (_isEditing) {
        await repo.update(
          widget.vehicleId!,
          vehicleType: vehicleType,
          make: make,
          model: model,
          year: year,
          plateNumber: plateNumber,
          transmission: transmission,
          fuelType: fuelType,
          color: color.isNotEmpty ? color : null,
          engineCapacity: engineCapacity.isNotEmpty ? engineCapacity : null,
          photoUrl: _vehiclePhoto != null ? photoUrl : null,
        );
      } else {
        await repo.create(
          vehicleType: vehicleType,
          make: make,
          model: model,
          year: year,
          plateNumber: plateNumber,
          transmission: transmission,
          fuelType: fuelType,
          color: color.isNotEmpty ? color : null,
          engineCapacity: engineCapacity.isNotEmpty ? engineCapacity : null,
          photoUrl: photoUrl,
        );
      }

      ref.invalidate(vehiclesProvider);
      ref.invalidate(profileProvider);

      final draft = ref.read(jobDraftProvider);
      if (_isEditing && draft.vehicle?.id == widget.vehicleId) {
        final updated = await repo.getById(widget.vehicleId!);
        ref.read(jobDraftProvider.notifier).state = draft.copyWith(vehicle: updated);
      }

      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing && _loadingVehicle) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(AppLocalizations.of(context).editVehicle, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          _isEditing ? AppLocalizations.of(context).editVehicle : AppLocalizations.of(context).addYourVehicle,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLookupCard(context),
                const SizedBox(height: 20),
                _buildOrDivider(),
                const SizedBox(height: 20),
                _buildPhotoPicker(context),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).vehicleType,
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
                      hint: Text(AppLocalizations.of(context).selectType, style: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 14)),
                      dropdownColor: AppColors.modal,
                      style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      items: [
                        DropdownMenuItem(value: 'car', child: Text(AppLocalizations.of(context).car)),
                        DropdownMenuItem(value: 'motorcycle', child: Text(AppLocalizations.of(context).motorcycle)),
                      ],
                      onChanged: _onTypeChanged,
                      validator: (v) => v == null ? AppLocalizations.of(context).selectVehicleType : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SearchableDropdownField(
                  label: AppLocalizations.of(context).make,
                  hint: _vehicleType == null ? AppLocalizations.of(context).selectTypeFirst : AppLocalizations.of(context).searchMake,
                  value: _selectedMake,
                  options: _makes,
                  enabled: _vehicleType != null,
                  loading: _loadingMakes,
                  pinnedOptions: const [_otherOption],
                  onChanged: _onMakeChanged,
                  validator: (v) => (v == null || v.isEmpty) ? AppLocalizations.of(context).selectAMake : null,
                ),
                if (_isOtherMake) ...[
                  const SizedBox(height: 16),
                  RyvoTextField(
                    hint: AppLocalizations.of(context).enterMake,
                    label: AppLocalizations.of(context).makeName,
                    controller: _customMakeController,
                    prefixIcon: const Icon(Icons.directions_car_outlined, size: 20),
                    validator: (v) => (v == null || v.trim().isEmpty) ? AppLocalizations.of(context).enterAMake : null,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  RyvoTextField(
                    hint: AppLocalizations.of(context).enterModel,
                    label: AppLocalizations.of(context).modelName,
                    controller: _customModelController,
                    prefixIcon: const Icon(Icons.car_repair_outlined, size: 20),
                    validator: (v) => (v == null || v.trim().isEmpty) ? AppLocalizations.of(context).enterAModel : null,
                    textInputAction: TextInputAction.next,
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  SearchableDropdownField(
                    label: AppLocalizations.of(context).model,
                    hint: _selectedMake == null ? AppLocalizations.of(context).selectMakeFirst : AppLocalizations.of(context).searchModel,
                    value: _selectedModel,
                    options: _models,
                    enabled: _selectedMake != null,
                    loading: _loadingModels,
                    pinnedOptions: const [_otherOption],
                    onChanged: (v) {
                      setState(() {
                        _selectedModel = v;
                        if (v != _otherOption) {
                          _customModelController.clear();
                        }
                      });
                    },
                    validator: (v) => (v == null || v.isEmpty) ? AppLocalizations.of(context).selectAModel : null,
                  ),
                  if (_selectedModel == _otherOption) ...[
                    const SizedBox(height: 16),
                    RyvoTextField(
                      hint: AppLocalizations.of(context).enterModel,
                      label: AppLocalizations.of(context).modelName,
                      controller: _customModelController,
                      prefixIcon: const Icon(Icons.car_repair_outlined, size: 20),
                      validator: (v) => (v == null || v.trim().isEmpty) ? AppLocalizations.of(context).enterAModel : null,
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                RyvoTextField(
                  hint: '2022',
                  label: AppLocalizations.of(context).year,
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                  validator: (v) => (v?.length ?? 0) != 4 ? AppLocalizations.of(context).enter4DigitYear : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SimpleDropdown(
                        label: AppLocalizations.of(context).transmission,
                        value: _transmission,
                        hint: AppLocalizations.of(context).select,
                        items: [
                          DropdownMenuItem(value: 'manual', child: Text(AppLocalizations.of(context).manual)),
                          DropdownMenuItem(value: 'auto', child: Text(AppLocalizations.of(context).auto)),
                        ],
                        onChanged: (v) => setState(() => _transmission = v),
                        validator: (v) => v == null ? AppLocalizations.of(context).selectTransmission : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SimpleDropdown(
                        label: AppLocalizations.of(context).fuelType,
                        value: _fuelType,
                        hint: AppLocalizations.of(context).select,
                        items: [
                          DropdownMenuItem(value: 'petrol', child: Text(AppLocalizations.of(context).petrol)),
                          DropdownMenuItem(value: 'diesel', child: Text(AppLocalizations.of(context).diesel)),
                          DropdownMenuItem(value: 'electric', child: Text(AppLocalizations.of(context).electric)),
                        ],
                        onChanged: (v) => setState(() => _fuelType = v),
                        validator: (v) => v == null ? AppLocalizations.of(context).selectFuelType : null,
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
                        controller: _colorController,
                        prefixIcon: const Icon(Icons.palette_outlined, size: 20),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: RyvoTextField(
                        hint: '1998',
                        label: 'Engine Capacity (cc)',
                        controller: _engineCapacityController,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.speed_outlined, size: 20),
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                RyvoButton(
                  label: _loading
                      ? (_vehiclePhoto != null ? AppLocalizations.of(context).uploadingPhoto : AppLocalizations.of(context).saving)
                      : _isEditing
                          ? AppLocalizations.of(context).updateVehicle
                          : AppLocalizations.of(context).saveVehicle,
                  onPressed: _loading ? null : _save,
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 16),
                  RyvoButton(
                    label: AppLocalizations.of(context).skipForNow,
                    variant: RyvoButtonVariant.ghost,
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLookupCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find your vehicle',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the registration and we\'ll fill in make, model and year.',
            style: GoogleFonts.poppins(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          RyvoTextField(
            hint: l10n.abc1234,
            label: l10n.licensePlate,
            controller: _plateController,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: const [UpperCaseTextFormatter()],
            prefixIcon: const Icon(Icons.badge_outlined, size: 20),
            validator: (v) => (v?.isEmpty ?? true) ? l10n.enterPlate : null,
            textInputAction: TextInputAction.search,
            onFieldSubmitted: (_) => _findVehicle(),
            onChanged: (_) {
              if (_lookupApplied) setState(() => _lookupApplied = false);
            },
          ),
          const SizedBox(height: 12),
          RyvoButton(
            label: _lookingUp ? 'Looking up…' : 'Find my vehicle',
            height: 48,
            isLoading: _lookingUp,
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.black),
            onPressed: _lookingUp ? null : _findVehicle,
          ),
          if (_lookupApplied) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Details filled in. Check them below before saving.',
                    style: GoogleFonts.poppins(fontSize: 12, height: 1.35, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.divider, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or enter the details yourself',
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint),
          ),
        ),
        Expanded(child: Divider(color: AppColors.divider, height: 1)),
      ],
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

class _SimpleDropdown extends StatelessWidget {
  const _SimpleDropdown({
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
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
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
