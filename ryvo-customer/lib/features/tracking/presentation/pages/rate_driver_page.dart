import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/job/active_job_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../payment/presentation/customer_checkout.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';

const List<String> _positiveTags = [
  'Clean car',
  'Great navigation',
  'Polite',
];

const List<String> _improveTags = [
  'Driving',
  'Navigation',
  'Car condition',
];

const List<double> _tipPresets = [1, 3, 5];

/// Full-screen post-ride rating. Replaces the receipt-style completion page.
class RateDriverPage extends ConsumerStatefulWidget {
  const RateDriverPage({super.key});

  @override
  ConsumerState<RateDriverPage> createState() => _RateDriverPageState();
}

class _RateDriverPageState extends ConsumerState<RateDriverPage>
    with SingleTickerProviderStateMixin {
  final _commentController = TextEditingController();
  late final AnimationController _starBounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  int _rating = 0;
  int _bouncedStar = 0;
  double? _tip;
  bool _submitting = false;
  final Set<String> _compliments = {};

  @override
  void dispose() {
    _starBounce.dispose();
    _commentController.dispose();
    super.dispose();
  }

  List<String> _tagsFor(int rating) {
    if (rating >= 5) return _positiveTags;
    if (rating > 0 && rating < 4) return _improveTags;
    return const [];
  }

  void _selectRating(int value) {
    HapticFeedback.heavyImpact();
    final allowed = _tagsFor(value).toSet();
    setState(() {
      _rating = value;
      _bouncedStar = value;
      _compliments.removeWhere((tag) => !allowed.contains(tag));
    });
    _starBounce.forward(from: 0);
  }

  void _toggleTag(String tag) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_compliments.add(tag)) _compliments.remove(tag);
    });
  }

  bool _isPreset(double amount) {
    for (final preset in _tipPresets) {
      if ((preset - amount).abs() < 0.001) return true;
    }
    return false;
  }

  void _selectTip(double? amount) {
    HapticFeedback.selectionClick();
    setState(() {
      if (amount != null &&
          _tip != null &&
          (_tip! - amount).abs() < 0.001) {
        _tip = null;
      } else {
        _tip = amount;
      }
    });
  }

  Future<void> _editCustomTip() async {
    final current = _tip != null && !_isPreset(_tip!) ? _tip : null;
    final saved = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.modal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CustomTipSheet(initial: current),
    );
    if (!mounted || saved == null) return;
    HapticFeedback.selectionClick();
    setState(() => _tip = saved);
  }

  void _onCustomTip() {
    final current = _tip;
    if (current != null && !_isPreset(current)) {
      _selectTip(current);
      return;
    }
    _editCustomTip();
  }

  String? _reviewComment() {
    final note = _commentController.text.trim();
    final tags = _compliments.join(', ');
    final parts = [
      if (tags.isNotEmpty) tags,
      if (note.isNotEmpty) note,
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  Future<void> _finish(String? jobId) async {
    if (_submitting) return;
    final tip = _tip;
    setState(() => _submitting = true);
    try {
      if (tip != null && tip > 0) {
        if (jobId == null) {
          showApiError(context, 'This trip can no longer take a tip.');
          return;
        }
        final paid = await CustomerCheckout(ref).payTip(
          context: context,
          jobId: jobId,
          amount: tip,
        );
        if (!paid || !mounted) return;
      }
      if (_rating > 0 && jobId != null) {
        await ref.read(jobRepositoryProvider).rateJob(
              jobId,
              _rating,
              comment: _reviewComment(),
            );
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
      return;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    markJobSessionFinished(container, jobId: jobId);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(jobDraftProvider).activeJob;
    final rawName = job?.provider?.fullName?.trim() ?? '';
    final driverName = rawName.isEmpty ? 'your driver' : rawName;
    final headline = rawName.isEmpty
        ? 'How was your ride?'
        : 'How was your ride with $rawName?';
    final tags = _tagsFor(_rating);
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _RateMast(
                    avatarUrl: job?.provider?.avatarUrl,
                    name: driverName,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      children: [
                        Text(
                          rawName.isEmpty ? 'Your driver' : rawName,
                          textAlign: TextAlign.center,
                          style: RyvoTypography.style(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          headline,
                          textAlign: TextAlign.center,
                          style: RyvoTypography.heading(
                            fontSize: 24,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _StarRow(
                          rating: _rating,
                          bouncedStar: _bouncedStar,
                          bounce: _starBounce,
                          onSelect: _selectRating,
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.fastOutSlowIn,
                          alignment: Alignment.topCenter,
                          child: tags.isEmpty
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: _TagWrap(
                                    tags: tags,
                                    selected: _compliments,
                                    onToggle: _toggleTag,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Add a tip',
                            style: RyvoTypography.style(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _TipRow(
                          tip: _tip,
                          isPreset: _tip == null ? false : _isPreset(_tip!),
                          onPreset: _selectTip,
                          onNone: () => _selectTip(null),
                          onCustom: _onCustomTip,
                        ),
                        const SizedBox(height: 20),
                        RyvoTextField(
                          controller: _commentController,
                          hint: l10n.writeAReviewOptional,
                          maxLines: 2,
                          keyboardType: TextInputType.multiline,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: RyvoButton(
                    label: _submitting
                        ? l10n.submitting
                        : _tip == null
                            ? 'Done'
                            : 'Pay ${formatMoney(_tip!)}',
                    isLoading: _submitting,
                    onPressed: _submitting ? null : () => _finish(job?.id),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomTipSheet extends StatefulWidget {
  const _CustomTipSheet({required this.initial});

  final double? initial;

  @override
  State<_CustomTipSheet> createState() => _CustomTipSheetState();
}

class _CustomTipSheetState extends State<_CustomTipSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _controller = TextEditingController(
      text: initial == null ? '' : initial.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value < 0.5 || value > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a tip from ${formatMoney(0.5)} to ${formatMoney(500)}')),
      );
      return;
    }
    Navigator.of(context).pop((value * 100).round() / 100);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final rawInset = media.viewInsets.bottom;
    final inset = rawInset.isFinite ? rawInset.clamp(0.0, media.size.height * 0.5) : 0.0;
    final available = (media.size.height - media.padding.top - 24)
        .clamp(160.0, media.size.height);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: available),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Custom tip',
              style: RyvoTypography.heading(
                fontSize: 20,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            RyvoTextField(
              controller: _controller,
              hint: 'Amount',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            RyvoButton(
              label: 'Save',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _RateMast extends StatelessWidget {
  const _RateMast({required this.avatarUrl, required this.name});

  final String? avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: top + 200,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 44,
            child: ClipRect(
              child: ColoredBox(
                color: AppColors.surface,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.divider,
                          width: 1.5,
                        ),
                      ),
                    ),
                    Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _DriverAvatar(avatarUrl: avatarUrl, name: name),
        ],
      ),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({required this.avatarUrl, required this.name});

  final String? avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim() ?? '';
    final photo = url.startsWith('http');
    final initials = _initials(name);
    return Container(
      width: 88,
      height: 88,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.obsidian,
        border: Border.all(color: AppColors.modal, width: 3),
      ),
      child: photo
          ? Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _Initials(initials);
              },
              errorBuilder: (_, __, ___) => _Initials(initials),
            )
          : _Initials(initials),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials(this.initials);

  final String initials;

  @override
  Widget build(BuildContext context) {
    if (initials.isEmpty) {
      return const Icon(Icons.person_rounded, color: AppColors.white, size: 36);
    }
    return Center(
      child: Text(
        initials,
        style: RyvoTypography.heading(
          fontSize: 28,
          color: AppColors.white,
          letterSpacing: -0.6,
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.rating,
    required this.bouncedStar,
    required this.bounce,
    required this.onSelect,
  });

  final int rating;
  final int bouncedStar;
  final AnimationController bounce;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: bounce,
      builder: (context, _) {
        final curve = Curves.elasticOut.transform(bounce.value);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: Transform.scale(
                  scale: i == bouncedStar ? 0.84 + (0.16 * curve) : 1,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      i <= rating
                          ? CupertinoIcons.star_fill
                          : CupertinoIcons.star,
                      size: 36,
                      color: i <= rating
                          ? AppColors.warning
                          : AppColors.divider,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TagWrap extends StatelessWidget {
  const _TagWrap({
    required this.tags,
    required this.selected,
    required this.onToggle,
  });

  final List<String> tags;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags)
          _ChoicePill(
            label: tag,
            selected: selected.contains(tag),
            onTap: () => onToggle(tag),
          ),
      ],
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({
    required this.tip,
    required this.isPreset,
    required this.onPreset,
    required this.onNone,
    required this.onCustom,
  });

  final double? tip;
  final bool isPreset;
  final ValueChanged<double> onPreset;
  final VoidCallback onNone;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final customSelected = tip != null && !isPreset;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ChoicePill(
          label: 'No tip',
          selected: tip == null,
          onTap: onNone,
        ),
        for (final amount in _tipPresets)
          _ChoicePill(
            label: formatMoney(amount),
            selected: tip != null && (tip! - amount).abs() < 0.001,
            tabular: true,
            onTap: () => onPreset(amount),
          ),
        _ChoicePill(
          label: customSelected ? formatMoney(tip!) : 'Custom',
          selected: customSelected,
          tabular: customSelected,
          onTap: onCustom,
        ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.tabular = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.divider,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: RyvoTypography.style(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primaryDark : AppColors.textPrimary,
              letterSpacing: -0.2,
              tabular: tabular,
            ),
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty && part != '—')
      .toList();
  if (parts.isEmpty || parts.first.toLowerCase() == 'your') return '';
  String letter(String word) => word[0].toUpperCase();
  if (parts.length == 1) return letter(parts.first);
  return '${letter(parts.first)}${letter(parts.last)}';
}
