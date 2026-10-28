import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/kyc_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/document_verification_card.dart';
import '../widgets/verification_progress_card.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class DocumentsVerificationPage extends ConsumerStatefulWidget {
  final bool isOnboardingGate;

  const DocumentsVerificationPage({super.key, this.isOnboardingGate = false});

  @override
  ConsumerState<DocumentsVerificationPage> createState() => _DocumentsVerificationPageState();
}

class _DocumentsVerificationPageState extends ConsumerState<DocumentsVerificationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(verificationProvider.notifier).load();
      ref.invalidate(providerProfileProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final kyc = ref.watch(verificationProvider);
    final isOnboardingGate = widget.isOnboardingGate;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: isOnboardingGate
            ? null
            : IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
              ),
        title: Text(
          AppLocalizations.of(context).documentsVerification,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        centerTitle: true,
        actions: isOnboardingGate
            ? [
                TextButton(
                  onPressed: () async {
                    await providerSignOut(ref);
                    if (!context.mounted) return;
                    context.go('/login');
                  },
                  child: Text(
                    AppLocalizations.of(context).logout,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (kyc.hasRejected)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context).oneOrMoreDocumentsWereRejectedTapReUploadOnEachR,
                                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    VerificationProgressCard(kycState: kyc),
                    const SizedBox(height: 22),
                    const _SectionLabel('Agreements'),
                    _SetupGroup(
                      items: [
                        _SetupItem(
                          icon: Icons.account_balance_outlined,
                          title: 'Tax responsibilities',
                          subtitle: 'Confirm you are an independent driver',
                          onTap: () => context.push('/compliance?key=tax_status'),
                        ),
                        _SetupItem(
                          icon: Icons.shield_outlined,
                          title: 'Insurance & cover',
                          subtitle: 'Confirm your motor insurance',
                          onTap: () => context.push('/compliance?key=insurance'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _SectionLabel('Documents'),
                    _DocumentGroup(
                      children: [
                        for (final doc in kyc.documents)
                          DocumentVerificationCard(
                            document: doc,
                            onAction: () => context.push(
                              '/kyc/document/${doc.type.name}${isOnboardingGate ? '?onboarding=true' : ''}',
                            ),
                          ),
                      ],
                    ),
                    if (kyc.documents.any((doc) => doc.status == VerificationDocStatus.pending) || kyc.allSubmitted) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context).verificationMayTakeUpTo48HoursYouLlBeNotifiedOnc,
                                style: GoogleFonts.poppins(fontSize: 13, height: 1.45, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isOnboardingGate && kyc.allSubmitted)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: RyvoButton(
                  label: AppLocalizations.of(context).viewVerificationStatus,
                  onPressed: () => context.go('/kyc/pending'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      ),
    );
  }
}

class _DocumentGroup extends StatelessWidget {
  const _DocumentGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SetupItem {
  const _SetupItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _SetupGroup extends StatelessWidget {
  const _SetupGroup({required this.items});

  final List<_SetupItem> items;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.divider),
            InkWell(
              onTap: items[i].onTap,
              borderRadius: BorderRadius.vertical(
                top: i == 0 ? const Radius.circular(16) : Radius.zero,
                bottom: i == items.length - 1 ? const Radius.circular(16) : Radius.zero,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(items[i].icon, color: AppColors.primaryDark, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].title,
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[i].subtitle,
                            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.grey400, size: 22),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _LicenseSide { front, back }

class DocumentUploadPage extends ConsumerStatefulWidget {
  final VerificationDocType docType;
  final bool isOnboarding;

  const DocumentUploadPage({super.key, required this.docType, this.isOnboarding = false});

  @override
  ConsumerState<DocumentUploadPage> createState() => _DocumentUploadPageState();
}

class _DocumentUploadPageState extends ConsumerState<DocumentUploadPage> {
  static const _maxEquipmentPhotos = 5;

  String? _previewName;
  String? _filePath;
  String? _frontPath;
  String? _frontName;
  String? _backPath;
  String? _backName;
  final List<String> _equipmentPaths = [];
  bool _uploading = false;

  bool get _isLicense => widget.docType == VerificationDocType.license;
  bool get _isSelfie => widget.docType == VerificationDocType.selfie;
  bool get _isEquipment => widget.docType == VerificationDocType.equipment;

  Future<void> _pick(ImageSource source, {_LicenseSide? side}) async {
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
      maxHeight: 1600,
      preferredCameraDevice: _isSelfie ? CameraDevice.front : CameraDevice.rear,
    );
    if (file == null) return;

    setState(() {
      if (side == _LicenseSide.front) {
        _frontPath = file.path;
        _frontName = file.name;
      } else if (side == _LicenseSide.back) {
        _backPath = file.path;
        _backName = file.name;
      } else if (_isEquipment) {
        if (_equipmentPaths.length >= _maxEquipmentPhotos) return;
        _equipmentPaths.add(file.path);
      } else {
        _previewName = file.name;
        _filePath = file.path;
      }
    });
  }

  Future<void> _submit() async {
    if (_uploading) return;

    final notifier = ref.read(verificationProvider.notifier);
    setState(() => _uploading = true);

    final ({bool success, String? error}) outcome;
    if (_isLicense) {
      final front = _frontPath;
      final back = _backPath;
      if (front == null || back == null) {
        setState(() => _uploading = false);
        return;
      }
      outcome = await notifier.uploadLicenseSides(frontPath: front, backPath: back);
    } else if (_isEquipment) {
      if (_equipmentPaths.isEmpty) {
        setState(() => _uploading = false);
        return;
      }
      outcome = await notifier.uploadEquipmentImages(List<String>.from(_equipmentPaths));
    } else {
      final path = _filePath;
      if (path == null) {
        setState(() => _uploading = false);
        return;
      }
      outcome = await notifier.uploadDocument(widget.docType, path);
    }

    if (!mounted) return;
    setState(() => _uploading = false);

    if (!outcome.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome.error ?? AppLocalizations.of(context).uploadFailedPleaseTryAgain,
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    final docTitle = ref.read(verificationProvider).doc(widget.docType).title;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$docTitle uploaded successfully',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );

    final kyc = ref.read(verificationProvider);
    if (kyc.allSubmitted) {
      ref.read(isKycInReviewProvider.notifier).state = true;
      context.go('/kyc/pending');
      return;
    }
    context.pop();
  }

  bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        !lower.contains('.');
  }

  Widget _buildImagePreview({
    required String? localPath,
    required String? remoteUrl,
    required String emptyLabel,
    required String filledLabel,
    required bool isViewOnly,
    required VoidCallback? onClear,
  }) {
    final hasLocal = localPath != null && _isImagePath(localPath);
    final hasRemote = remoteUrl != null &&
        (remoteUrl.startsWith('http://') || remoteUrl.startsWith('https://'));
    final hasPreview = hasLocal || hasRemote;

    Widget content;
    if (hasLocal) {
      content = Image.file(
        File(localPath),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _sidePlaceholder(filledLabel, hasFile: true),
      );
    } else if (hasRemote) {
      content = SecureNetworkImage(
        fileUrl: remoteUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorWidget: _sidePlaceholder(filledLabel, hasFile: true),
      );
    } else {
      content = _sidePlaceholder(emptyLabel, hasFile: false);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPreview ? AppColors.primary.withValues(alpha: 0.5) : AppColors.divider,
          width: hasPreview ? 2 : 1.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: content,
            ),
          ),
          if (hasPreview && !isViewOnly && onClear != null)
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sidePlaceholder(String label, {required bool hasFile}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          hasFile ? Icons.description_outlined : Icons.cloud_upload_outlined,
          size: hasFile ? 40 : 36,
          color: hasFile ? AppColors.primary.withValues(alpha: 0.7) : AppColors.grey500,
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: hasFile ? FontWeight.w500 : FontWeight.normal,
              color: hasFile ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildSideSlot({
    required String title,
    required _LicenseSide side,
    required String? localPath,
    required String? localName,
    required String? remoteUrl,
    required bool isViewOnly,
  }) {
    final hasLocal = localPath != null;
    final hasRemote = remoteUrl != null &&
        (remoteUrl.startsWith('http://') || remoteUrl.startsWith('https://'));
    final hasPreview = hasLocal || hasRemote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildImagePreview(
            localPath: localPath,
            remoteUrl: remoteUrl,
            emptyLabel: 'Upload $title',
            filledLabel: localName ??
                (hasRemote ? AppLocalizations.of(context).previouslyUploaded : 'Upload $title'),
            isViewOnly: isViewOnly,
            onClear: () => setState(() {
              if (side == _LicenseSide.front) {
                _frontPath = null;
                _frontName = null;
              } else {
                _backPath = null;
                _backName = null;
              }
            }),
          ),
        ),
        if (!isViewOnly) ...[
          const SizedBox(height: 10),
          RyvoButton(
            label: AppLocalizations.of(context).takePhoto,
            variant: RyvoButtonVariant.outline,
            prefixIcon: const Icon(Icons.camera_alt_outlined, size: 16),
            onPressed: _uploading ? null : () => _pick(ImageSource.camera, side: side),
          ),
        ],
        if (hasPreview && !isViewOnly) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.check_circle, size: 14, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                '$title ready',
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.success),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSinglePreview(VerificationDocument doc) {
    final localPath = _filePath;
    if (localPath != null && _isImagePath(localPath)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(
          File(localPath),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _sidePlaceholder(
            _previewName ?? AppLocalizations.of(context).documentReady,
            hasFile: true,
          ),
        ),
      );
    }

    final remoteUrl = doc.fileName;
    if (remoteUrl != null && (remoteUrl.startsWith('http://') || remoteUrl.startsWith('https://'))) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SecureNetworkImage(
          fileUrl: remoteUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorWidget: _sidePlaceholder('Previously uploaded', hasFile: true),
        ),
      );
    }

    return _sidePlaceholder(
      _previewName ??
          (doc.fileName != null && doc.fileName!.startsWith('http')
              ? AppLocalizations.of(context).previouslyUploaded
              : doc.fileName) ??
          AppLocalizations.of(context).uploadAClearPhoto,
      hasFile: _previewName != null || doc.fileName != null,
    );
  }

  Widget _buildEquipmentGrid(VerificationDocument doc, bool isViewOnly) {
    final remoteUrls = [
      if (doc.fileName != null && doc.fileName!.startsWith('http')) doc.fileName!,
      ...doc.extraFileNames.where((u) => u.startsWith('http')),
    ];
    final showRemote = _equipmentPaths.isEmpty && remoteUrls.isNotEmpty;
    final count = showRemote ? remoteUrls.length : _equipmentPaths.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          showRemote
              ? '$count uploaded photo${count == 1 ? '' : 's'}'
              : '${_equipmentPaths.length}/$_maxEquipmentPhotos selected',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            itemCount: count + (!isViewOnly && !showRemote && _equipmentPaths.length < _maxEquipmentPhotos ? 1 : 0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final isAddTile = !showRemote && index >= _equipmentPaths.length;
              if (isAddTile) {
                return InkWell(
                  onTap: _uploading ? null : () => _pick(ImageSource.camera),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider, width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 28),
                        const SizedBox(height: 8),
                        Text(AppLocalizations.of(context).addPhoto, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }

              if (showRemote) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SecureNetworkImage(
                    fileUrl: remoteUrls[index],
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                );
              }

              return Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_equipmentPaths[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (!isViewOnly)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () => setState(() => _equipmentPaths.removeAt(index)),
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(verificationProvider).doc(widget.docType);
    final isViewOnly = doc.status == VerificationDocStatus.verified;

    final canSubmit = !_uploading &&
        (_isLicense
            ? (_frontPath != null && _backPath != null)
            : _isEquipment
                ? _equipmentPaths.isNotEmpty
                : _filePath != null);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(doc.title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doc.subtitle,
                style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
              if (_isLicense) ...[
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context).bothSidesAreRequiredBeforeYouCanSubmit,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint, height: 1.4),
                ),
              ],
              if (_isSelfie) ...[
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context).takeAClearSelfieThisPhotoIsUsedForIdentityChecks,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint, height: 1.4),
                ),
              ],
              if (_isEquipment) ...[
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context).addAtLeastOneClearPhotoOfYourServiceEquipment,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint, height: 1.4),
                ),
              ],
              if (doc.statusDetail != null) ...[
                const SizedBox(height: 8),
                Text(doc.statusDetail!, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.primary)),
              ],
              if (doc.status == VerificationDocStatus.rejected &&
                  doc.rejectionReason != null &&
                  doc.rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: AppColors.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          doc.rejectionReason!,
                          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.error, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (_isLicense)
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildSideSlot(
                          title: AppLocalizations.of(context).front,
                          side: _LicenseSide.front,
                          localPath: _frontPath,
                          localName: _frontName,
                          remoteUrl: doc.fileName,
                          isViewOnly: isViewOnly,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildSideSlot(
                          title: AppLocalizations.of(context).back,
                          side: _LicenseSide.back,
                          localPath: _backPath,
                          localName: _backName,
                          remoteUrl: doc.backFileName,
                          isViewOnly: isViewOnly,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_isEquipment)
                Expanded(child: _buildEquipmentGrid(doc, isViewOnly))
              else ...[
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (_filePath != null || doc.fileName != null)
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.divider,
                        width: (_filePath != null || doc.fileName != null) ? 2 : 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(child: _buildSinglePreview(doc)),
                        if (_filePath != null && !isViewOnly)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Material(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                onTap: () => setState(() {
                                  _filePath = null;
                                  _previewName = null;
                                }),
                                borderRadius: BorderRadius.circular(20),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.close, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_filePath != null && !isViewOnly) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).previewReadyTapUploadToSubmit,
                          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.success),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 20),
              if (!isViewOnly) ...[
                if (!_isLicense) ...[
                  if (_isSelfie) ...[
                    RyvoButton(
                      label: AppLocalizations.of(context).takeSelfie,
                      variant: RyvoButtonVariant.outline,
                      prefixIcon: const Icon(Icons.camera_alt_outlined, size: 18),
                      onPressed: _uploading ? null : () => _pick(ImageSource.camera),
                    ),
                    const SizedBox(height: 8),
                  ] else if (_isEquipment) ...[
                    Row(
                      children: [
                        Expanded(
                          child: RyvoButton(
                            label: AppLocalizations.of(context).camera,
                            variant: RyvoButtonVariant.outline,
                            prefixIcon: const Icon(Icons.camera_alt_outlined, size: 18),
                            onPressed: _uploading || _equipmentPaths.length >= _maxEquipmentPhotos
                                ? null
                                : () => _pick(ImageSource.camera),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: RyvoButton(
                            label: AppLocalizations.of(context).camera,
                            variant: RyvoButtonVariant.outline,
                            prefixIcon: const Icon(Icons.camera_alt_outlined, size: 18),
                            onPressed: _uploading ? null : () => _pick(ImageSource.camera),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
                RyvoButton(
                  label: _uploading
                      ? AppLocalizations.of(context).uploading
                      : doc.status == VerificationDocStatus.notUploaded
                          ? (_isLicense
                              ? AppLocalizations.of(context).uploadBothSides
                              : _isEquipment
                                  ? AppLocalizations.of(context).uploadPhotos
                                  : _isSelfie
                                      ? AppLocalizations.of(context).uploadSelfie
                                      : AppLocalizations.of(context).uploadDocument)
                          : (_isLicense
                              ? AppLocalizations.of(context).reUploadBothSides
                              : _isEquipment
                                  ? AppLocalizations.of(context).reUploadPhotos
                                  : AppLocalizations.of(context).reUploadDocument),
                  onPressed: canSubmit ? _submit : null,
                ),
              ] else
                RyvoButton(label: AppLocalizations.of(context).back, variant: RyvoButtonVariant.outline, onPressed: () => context.pop()),
            ],
          ),
        ),
      ),
    );
  }
}
