import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/providers/kyc_providers.dart';
import '../../../../shared/widgets/widgets.dart';

dynamic _data(Response res) {
  final body = res.data;
  if (body is Map && body.containsKey('data')) return body['data'];
  return body;
}

String _friendlyError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String && (data['message'] as String).trim().isNotEmpty) {
      return data['message'] as String;
    }
  }
  return 'Something went wrong. Check your connection and try again.';
}

bool _isOnboardingProgram(Map<String, dynamic> program) => program['serviceCategory'] == null;

bool _isProgramReady(Map<String, dynamic> program) {
  return program['passed'] == true;
}

bool _programAttempted(Map<String, dynamic> program) {
  return program['lastScore'] != null;
}

String? _categoryName(Map<String, dynamic> program) {
  final category = program['serviceCategory'];
  if (category is Map && category['name'] != null) return '${category['name']}';
  return null;
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.hint,
    required this.color,
    required this.icon,
  });

  final String label;
  final String hint;
  final Color color;
  final IconData icon;
}

_StatusStyle _statusStyle(Map<String, dynamic> program) {
  if (_isOnboardingProgram(program)) {
    if (program['passed'] == true) {
      return const _StatusStyle(
        label: 'Passed',
        hint: 'Required training is complete.',
        color: AppColors.success,
        icon: Icons.verified_rounded,
      );
    }
    return const _StatusStyle(
      label: 'Required',
      hint: 'Pass this before you go online.',
      color: AppColors.primaryDark,
      icon: Icons.menu_book_rounded,
    );
  }

  if (program['passed'] == true) {
    return const _StatusStyle(
      label: 'Passed',
      hint: 'You can accept this job type.',
      color: AppColors.success,
      icon: Icons.check_circle_rounded,
    );
  }
  if (_programAttempted(program)) {
    return const _StatusStyle(
      label: 'Retake',
      hint: 'You didn’t pass. Review the lessons and take the test again.',
      color: AppColors.error,
      icon: Icons.refresh_rounded,
    );
  }
  return const _StatusStyle(
    label: 'Not started',
    hint: 'Take the training to unlock this job type.',
    color: AppColors.grey500,
    icon: Icons.lock_outline_rounded,
  );
}

IconData _jobTypeIcon(String? name) {
  final value = (name ?? '').toLowerCase();
  if (value.contains('jump') || value.contains('battery')) return Icons.bolt_rounded;
  if (value.contains('tow')) return Icons.local_shipping_outlined;
  if (value.contains('tyre') || value.contains('tire')) return Icons.tire_repair;
  if (value.contains('fuel') || value.contains('gas')) return Icons.local_gas_station_outlined;
  if (value.contains('lock')) return Icons.key_outlined;
  return Icons.build_circle_outlined;
}

class TrainingPage extends ConsumerStatefulWidget {
  const TrainingPage({super.key});

  @override
  ConsumerState<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends ConsumerState<TrainingPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _programs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(dioClientProvider).dio.get('/provider/training');
      final data = _data(res);
      setState(() {
        _programs = data is List
            ? data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
            : const [];
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _friendlyError(e);
        });
      }
    }
  }

  Future<void> _open(Map<String, dynamic> program) async {
    await context.push('/training/${program['id']}');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = _programs.where(_isOnboardingProgram).toList();
    final jobTypes = _programs.where((program) => !_isOnboardingProgram(program)).toList();
    final ready = _programs.where(_isProgramReady).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Training & job types', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  if (_error != null)
                    _MessageState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Couldn’t load training',
                      body: _error!,
                      actionLabel: 'Try again',
                      onAction: _load,
                    )
                  else if (_programs.isEmpty)
                    const _MessageState(
                      icon: Icons.school_outlined,
                      title: 'No training yet',
                      body: 'When onboarding or a job type needs a qualification, it will show up here.',
                    )
                  else ...[
                    _ProgressHeader(ready: ready, total: _programs.length),
                    if (onboarding.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const _SectionLabel('Required to go online'),
                      const SizedBox(height: 8),
                      ...onboarding.map((program) => _ProgramCard(program: program, onTap: () => _open(program))),
                    ],
                    if (jobTypes.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const _SectionLabel('Job types'),
                      const SizedBox(height: 8),
                      ...jobTypes.map((program) => _ProgramCard(program: program, onTap: () => _open(program))),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

class TrainingDetailPage extends ConsumerStatefulWidget {
  const TrainingDetailPage({super.key, required this.programId});

  final String programId;

  @override
  ConsumerState<TrainingDetailPage> createState() => _TrainingDetailPageState();
}

class _TrainingDetailPageState extends ConsumerState<TrainingDetailPage> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _program;
  final _answers = <String, String>{};
  final _questionKeys = <String, GlobalKey>{};
  final _testKey = GlobalKey();
  final _scroll = ScrollController();
  bool? _passed;
  num? _score;
  bool _highlightMissing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _reviewLessons() {
    setState(() {
      _passed = null;
      _score = null;
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  GlobalKey _keyFor(String id) => _questionKeys.putIfAbsent(id, GlobalKey.new);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _passed = null;
      _score = null;
      _highlightMissing = false;
    });
    try {
      final res = await ref.read(dioClientProvider).dio.get('/provider/training/${widget.programId}');
      final data = _data(res);
      setState(() {
        _program = data is Map ? data.cast<String, dynamic>() : null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _friendlyError(e);
        });
      }
    }
  }

  List<Map<String, dynamic>> get _questions {
    final raw = _program?['questions'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> _submit() async {
    if (_passed == true) {
      context.pop();
      return;
    }
    final questions = _questions;
    final missing = questions.map((q) => q['id'].toString()).where((id) => !_answers.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      setState(() => _highlightMissing = true);
      final target = _questionKeys[missing.first]?.currentContext;
      if (target != null) {
        await Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 320), alignment: 0.12);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Answer every question before submitting.', style: GoogleFonts.poppins())),
        );
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await ref.read(dioClientProvider).dio.post(
        '/provider/training/${widget.programId}/submit',
        data: {
          'answers': _answers.entries.map((e) => {'questionId': e.key, 'optionId': e.value}).toList(),
        },
      );
      final data = _data(res);
      final passed = data is Map && data['passed'] == true;
      final score = data is Map && data['score'] is num ? data['score'] as num : null;
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _passed = passed;
        _score = score;
        _highlightMissing = false;
      });
      await _showResultDialog(passed: passed, score: score);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e), style: GoogleFonts.poppins())));
      }
    }
  }

  Future<void> _showResultDialog({required bool passed, num? score}) async {
    if (!mounted) return;
    final scoreLabel = score == null
        ? null
        : (score == score.roundToDouble() ? '${score.toInt()}%' : '$score%');
    HapticFeedback.lightImpact();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final color = passed ? AppColors.success : AppColors.error;
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(passed ? Icons.check_circle_rounded : Icons.refresh_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  passed ? 'You passed' : 'Not passed',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          content: Text(
            passed
                ? 'Great work${scoreLabel == null ? '' : ' · you scored $scoreLabel'}. This qualification is updated.'
                : 'You scored ${scoreLabel ?? 'below the pass mark'}. Review the lessons and take the test again.',
            style: GoogleFonts.poppins(fontSize: 13, height: 1.45, color: AppColors.textSecondary),
          ),
          actions: passed
              ? [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
                    child: Text('Back to job types', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                    child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _reviewLessons();
                    },
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
                    child: Text('Review lessons', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ],
        );
      },
    );
    if (passed && mounted) {
      context.pop();
    }
  }

  void _select(String questionId, String optionId) {
    if (_passed == true) return;
    HapticFeedback.selectionClick();
    setState(() {
      _answers[questionId] = optionId;
      if (_questions.every((q) => _answers.containsKey(q['id'].toString()))) {
        _highlightMissing = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;
    final title = program?['title']?.toString() ?? 'Training';
    final blocks = ((program?['blocks'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    final questions = _questions;
    final answered = questions.where((q) => _answers.containsKey(q['id'].toString())).length;
    final description = program?['description']?.toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _MessageState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Couldn’t open this training',
                  body: _error!,
                  actionLabel: 'Try again',
                  onAction: _load,
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          if (program != null) _DetailIntro(program: program, lessonCount: blocks.length, questionCount: questions.length),
                          if (description != null && description.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(description, style: GoogleFonts.poppins(fontSize: 13, height: 1.45, color: AppColors.textSecondary)),
                          ],
                          if (blocks.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            const _SectionLabel('Learn'),
                            const SizedBox(height: 8),
                            ...blocks.map((block) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _LessonBlock(block: block),
                                )),
                          ],
                          const SizedBox(height: 10),
                          _SectionLabel(questions.isEmpty ? 'Test' : 'Test · $answered of ${questions.length}'),
                          const SizedBox(height: 8),
                          if (questions.isEmpty)
                            Text(
                              'This module has no questions yet.',
                              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                            )
                          else
                            ...questions.asMap().entries.map((entry) {
                              final question = entry.value;
                              final id = question['id'].toString();
                              return Padding(
                                key: _keyFor(id),
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _QuestionCard(
                                  index: entry.key + 1,
                                  question: question,
                                  selectedId: _answers[id],
                                  highlightMissing: _highlightMissing && !_answers.containsKey(id),
                                  locked: _passed == true,
                                  onSelect: (optionId) => _select(id, optionId),
                                ),
                              );
                            }),
                          if (_passed != null) ...[
                            const SizedBox(height: 4),
                            KeyedSubtree(
                              key: _testKey,
                              child: _ResultBanner(passed: _passed!, score: _score, onReview: _passed == true ? null : _reviewLessons),
                            ),
                          ] else
                            SizedBox(key: _testKey, height: 0),
                        ],
                      ),
                    ),
                    _SubmitBar(
                      passed: _passed,
                      submitting: _submitting,
                      remaining: questions.length - answered,
                      onPressed: _submit,
                    ),
                  ],
                ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.ready, required this.total});

  final int ready;
  final int total;

  @override
  Widget build(BuildContext context) {
    final complete = total > 0 && ready == total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Qualifications', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      complete ? 'All set' : '$ready of $total ready',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: complete ? AppColors.success : AppColors.primaryDark),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(complete ? Icons.verified_rounded : Icons.school_outlined, color: AppColors.primaryDark),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : ready / total,
              minHeight: 8,
              backgroundColor: AppColors.grey300,
              color: complete ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            complete
                ? 'Every listed qualification is approved. You can accept the job types shown below.'
                : 'Pass the required training before you go online. A job type stays locked until its test is passed and any equipment check is approved.',
            style: GoogleFonts.poppins(fontSize: 12, height: 1.45, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary));
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program, required this.onTap});

  final Map<String, dynamic> program;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(program);
    final onboarding = _isOnboardingProgram(program);
    final category = _categoryName(program);
    final title = program['title']?.toString() ?? 'Training';
    final icon = onboarding ? Icons.menu_book_rounded : _jobTypeIcon(category ?? title);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: style.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        if (category != null) ...[
                          const SizedBox(height: 2),
                          Text(category, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: style.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(style.label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: style.color)),
                        ),
                        const SizedBox(height: 6),
                        Text(style.hint, style: GoogleFonts.poppins(fontSize: 12, height: 1.35, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: AppColors.grey400, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailIntro extends StatelessWidget {
  const _DetailIntro({required this.program, required this.lessonCount, required this.questionCount});

  final Map<String, dynamic> program;
  final int lessonCount;
  final int questionCount;

  @override
  Widget build(BuildContext context) {
    final onboarding = _isOnboardingProgram(program);
    final category = _categoryName(program);
    final parts = <String>[
      if (lessonCount > 0) '$lessonCount ${lessonCount == 1 ? 'lesson' : 'lessons'}',
      if (questionCount > 0) '$questionCount ${questionCount == 1 ? 'question' : 'questions'}',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(onboarding ? Icons.menu_book_rounded : _jobTypeIcon(category), color: AppColors.primaryDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  onboarding ? 'Required training' : (category ?? 'Job type'),
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  parts.isEmpty ? 'Read the module, then submit when you are ready.' : '${parts.join(' · ')}. Read first, then take the test.',
                  style: GoogleFonts.poppins(fontSize: 12, height: 1.35, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonBlock extends StatelessWidget {
  const _LessonBlock({required this.block});

  final Map<String, dynamic> block;

  @override
  Widget build(BuildContext context) {
    final type = block['type']?.toString();
    final body = block['body']?.toString() ?? '';
    if (type == 'image' && body.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          body,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 180,
              color: AppColors.surface,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            );
          },
          errorBuilder: (_, __, ___) => _mediaFallback('Image couldn’t be loaded'),
        ),
      );
    }
    if (type == 'video') {
      final uri = Uri.tryParse(body);
      final canOpen = uri != null && uri.hasScheme;
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: canOpen
              ? () => launchUrl(uri, mode: LaunchMode.externalApplication)
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: AppColors.primaryDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Watch video', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        canOpen ? 'Opens in your browser' : body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (canOpen) const Icon(Icons.open_in_new, size: 18, color: AppColors.grey500),
              ],
            ),
          ),
        ),
      );
    }
    return Text(body, style: GoogleFonts.poppins(fontSize: 14, height: 1.5, color: AppColors.textPrimary));
  }
}

Widget _mediaFallback(String label) {
  return Container(
    height: 120,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Text(label, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
  );
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selectedId,
    required this.highlightMissing,
    required this.locked,
    required this.onSelect,
  });

  final int index;
  final Map<String, dynamic> question;
  final String? selectedId;
  final bool highlightMissing;
  final bool locked;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final options = ((question['options'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlightMissing ? AppColors.error : AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: highlightMissing ? AppColors.errorLight : AppColors.primary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: highlightMissing ? AppColors.error : AppColors.primaryDark),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question['prompt']?.toString() ?? '',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...options.map((option) {
            final id = option['id'].toString();
            final selected = selectedId == id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: locked ? null : () => onSelect(id),
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.divider,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          selected ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 20,
                          color: selected ? AppColors.primaryDark : AppColors.grey400,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            option['label']?.toString() ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          if (highlightMissing)
            Text('Choose an answer', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.error)),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.passed, required this.score, required this.onReview});

  final bool passed;
  final num? score;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final color = passed ? AppColors.success : AppColors.error;
    final scoreLabel = score == null
        ? null
        : (score == score!.roundToDouble() ? '${score!.toInt()}%' : '$score%');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: passed ? AppColors.successLight : AppColors.errorLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(passed ? Icons.check_circle_rounded : Icons.refresh_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passed ? 'You passed${scoreLabel == null ? '' : ' · $scoreLabel'}' : 'Not passed${scoreLabel == null ? '' : ' · $scoreLabel'}',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  passed
                      ? 'This qualification is updated. Head back to see what is still left.'
                      : 'Review the lessons, change your answers, and submit again.',
                  style: GoogleFonts.poppins(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
                ),
                if (onReview != null)
                  TextButton(
                    onPressed: onReview,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.only(top: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.primaryDark,
                    ),
                    child: Text('Review lessons', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.passed,
    required this.submitting,
    required this.remaining,
    required this.onPressed,
  });

  final bool? passed;
  final bool submitting;
  final int remaining;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = passed == true ? 'Back to job types' : (passed == false ? 'Submit again' : 'Submit test');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (passed == null && remaining > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  remaining == 1 ? '1 question left' : '$remaining questions left',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            RyvoButton(
              label: label,
              isLoading: submitting,
              onPressed: submitting ? null : onPressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.grey400),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            RyvoButton(label: actionLabel!, onPressed: onAction, width: 180),
          ],
        ],
      ),
    );
  }
}

class CompliancePage extends ConsumerStatefulWidget {
  const CompliancePage({super.key, this.focusKey});

  final String? focusKey;

  @override
  ConsumerState<CompliancePage> createState() => _CompliancePageState();
}

class _CompliancePageState extends ConsumerState<CompliancePage> {
  bool _loading = true;
  List<Map<String, dynamic>> _docs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioClientProvider).dio.get('/provider/agreements');
      final data = _data(res);
      setState(() {
        _docs = data is List ? data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final focus = widget.focusKey;
    final visible = focus == null ? _docs : _docs.where((d) => d['key'] == focus).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Agreements', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: visible
                  .map(
                    (doc) => _AgreementCard(
                      key: ValueKey('${doc['key']}-${doc['version']}'),
                      doc: doc,
                      serviceBody: _serviceBody,
                      onAccepted: _load,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  String? get _serviceBody {
    for (final doc in _docs) {
      if (doc['key'] == 'service') return doc['body']?.toString();
    }
    return null;
  }
}

List<String> _fallbackStatements(String? key) {
  switch (key) {
    case 'tax_status':
      return const [
        'I understand that I am registering with RYVO as an independent driver and not as an employee of RYVO Ltd.',
        'I understand that I am responsible for determining and meeting my own tax, National Insurance and HMRC reporting obligations where applicable.',
      ];
    case 'insurance':
      return const [
        'I confirm that I currently hold valid motor insurance that is appropriate for my use of the vehicle while providing services through RYVO.',
        'I understand that I am responsible for making sure my insurance remains valid and suitable, and I will notify RYVO if my cover expires, is cancelled or becomes unsuitable for the services I provide.',
      ];
    default:
      return const ['I have read and accept this agreement.'];
  }
}

class _AgreementCard extends ConsumerStatefulWidget {
  const _AgreementCard({super.key, required this.doc, required this.serviceBody, required this.onAccepted});

  final Map<String, dynamic> doc;
  final String? serviceBody;
  final Future<void> Function() onAccepted;

  @override
  ConsumerState<_AgreementCard> createState() => _AgreementCardState();
}

class _AgreementCardState extends ConsumerState<_AgreementCard> {
  List<bool> _checked = const [];
  bool _saving = false;

  bool get _accepted => widget.doc['accepted'] == true;

  List<String> get _statements {
    final raw = widget.doc['acknowledgements'];
    if (raw is List) {
      final items = raw.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
      if (items.isNotEmpty) return items;
    }
    return _fallbackStatements(widget.doc['key']?.toString());
  }

  @override
  void initState() {
    super.initState();
    _checked = List<bool>.filled(_statements.length, _accepted);
  }

  @override
  void didUpdateWidget(covariant _AgreementCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _statements;
    final changed = oldWidget.doc['accepted'] != widget.doc['accepted'] ||
        oldWidget.doc['version'] != widget.doc['version'] ||
        oldWidget.doc['acknowledgements'] != widget.doc['acknowledgements'] ||
        _checked.length != next.length;
    if (changed) {
      setState(() => _checked = List<bool>.filled(next.length, _accepted));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accepted = _accepted;
    final statements = _statements;
    final title = widget.doc['title']?.toString() ?? 'Agreement';
    final ready = statements.isNotEmpty &&
        _checked.length == statements.length &&
        _checked.every((value) => value);
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              widget.doc['body']?.toString() ?? '',
              style: GoogleFonts.poppins(fontSize: 13, height: 1.45, color: AppColors.textSecondary),
            ),
            if (widget.doc['key'] == 'tax_status')
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                  foregroundColor: AppColors.primary,
                ),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Driver Agreement'),
                      content: SingleChildScrollView(child: Text(widget.serviceBody ?? 'Driver agreement')),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                    ),
                  );
                },
                child: const Text('View Driver Agreement'),
              ),
            const SizedBox(height: 4),
            for (var index = 0; index < statements.length; index++)
              CheckboxListTile(
                value: index < _checked.length && _checked[index],
                onChanged: accepted || _saving
                    ? null
                    : (value) => setState(() {
                          if (_checked.length != statements.length) {
                            _checked = List<bool>.filled(statements.length, false);
                          }
                          _checked[index] = value ?? false;
                        }),
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return AppColors.primary;
                  return null;
                }),
                checkColor: Colors.white,
                side: const BorderSide(color: AppColors.grey400, width: 1.5),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                title: Text(
                  statements[index],
                  style: GoogleFonts.poppins(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
                ),
              ),
            const SizedBox(height: 12),
            if (accepted)
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 18, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text('Accepted', style: GoogleFonts.poppins(color: AppColors.success, fontWeight: FontWeight.w600)),
                ],
              )
            else
              RyvoButton(
                label: _saving ? 'Saving…' : 'Agree & Submit',
                onPressed: !ready || _saving ? null : _accept,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept() async {
    setState(() => _saving = true);
    try {
      await ref.read(dioClientProvider).dio.post('/provider/agreements/accept', data: {
        'key': widget.doc['key'],
        'version': widget.doc['version'],
        'appVersion': '1.0.0',
      });
      await widget.onAccepted();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

enum _EquipmentShot { needed, uploading, submitted, approved, rejected }

String _requirementId(Map<String, dynamic> row) {
  final id = row['id'];
  if (id != null) return id.toString();
  return row['label']?.toString() ?? '';
}

String? _nestedText(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  final doc = row['document'] ?? row['latestDocument'] ?? row['proof'];
  if (doc is Map) {
    for (final key in keys) {
      final value = doc[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
  }
  return null;
}

String? _proofStatus(Map<String, dynamic> row) => _nestedText(row, const ['status', 'documentStatus', 'reviewStatus'])?.toLowerCase();

String? _proofUrl(Map<String, dynamic> row) {
  String? pick(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  for (final key in const ['fileUrl', 'photoUrl', 'imageUrl', 'url']) {
    final value = pick(row[key]);
    if (value != null) return value;
  }
  final doc = row['document'] ?? row['latestDocument'] ?? row['proof'];
  if (doc is Map) {
    for (final key in const ['fileUrl', 'photoUrl', 'imageUrl', 'url']) {
      final value = pick(doc[key]);
      if (value != null) return value;
    }
  }
  return null;
}

class EquipmentProofPage extends ConsumerStatefulWidget {
  const EquipmentProofPage({super.key});

  @override
  ConsumerState<EquipmentProofPage> createState() => _EquipmentProofPageState();
}

class _EquipmentProofPageState extends ConsumerState<EquipmentProofPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requirements = const [];
  final _uploading = <String>{};
  final _justSubmitted = <String>{};
  final _localPreviews = <String, String>{};
  final _itemErrors = <String, String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final res = await ref.read(dioClientProvider).dio.get('/provider/equipment-requirements');
      final data = _data(res);
      if (!mounted) return;
      setState(() {
        _requirements = data is List ? data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];
        if (!silent) _justSubmitted.clear();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyError(e);
      if (silent && _requirements.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: GoogleFonts.poppins())));
      } else {
        setState(() {
          _loading = false;
          _error = message;
        });
      }
    }
  }

  _EquipmentShot _shotFor(Map<String, dynamic> row) {
    final id = _requirementId(row);
    if (_uploading.contains(id)) return _EquipmentShot.uploading;
    if (_justSubmitted.contains(id)) return _EquipmentShot.submitted;
    switch (_proofStatus(row)) {
      case 'approved':
      case 'verified':
        return _EquipmentShot.approved;
      case 'rejected':
        return _EquipmentShot.rejected;
      case 'pending':
      case 'submitted':
      case 'in_review':
      case 'review':
      case 'equipment_review':
        return _EquipmentShot.submitted;
    }
    if (_localPreviews.containsKey(id) || _proofUrl(row) != null) return _EquipmentShot.submitted;
    return _EquipmentShot.needed;
  }

  bool _countsAsSubmitted(_EquipmentShot shot) {
    return shot == _EquipmentShot.submitted || shot == _EquipmentShot.approved;
  }

  Future<void> _capture(Map<String, dynamic> requirement) async {
    final id = _requirementId(requirement);
    if (_uploading.contains(id) || _shotFor(requirement) == _EquipmentShot.approved) return;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (e) {
      if (!mounted) return;
      final text = e.toString().toLowerCase();
      setState(() {
        _itemErrors[id] = text.contains('permission') || text.contains('access_denied')
            ? 'Allow camera access to photograph your equipment.'
            : 'The camera couldn’t be opened. Try again.';
      });
      return;
    }
    if (picked == null || !mounted) return;

    setState(() {
      _uploading.add(id);
      _itemErrors.remove(id);
      _localPreviews[id] = picked!.path;
    });

    try {
      final fileUrl = await ref.read(fileUploadServiceProvider).uploadProviderFile(
            localPath: picked.path,
            folder: 'documents',
          );
      final category = requirement['serviceCategory'];
      await ref.read(dioClientProvider).dio.post('/provider/documents', data: {
        'docType': 'equipment_proof',
        'fileUrl': fileUrl,
        'serviceCategoryId': requirement['serviceCategoryId'] ?? (category is Map ? category['id'] : null),
        'equipmentRequirementId': requirement['id'],
        'equipmentLabel': requirement['label'],
      });
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _uploading.remove(id);
        _justSubmitted.add(id);
      });
      await _load(silent: true);
      if (!mounted) return;
      await ref.read(verificationProvider.notifier).load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading.remove(id);
        _localPreviews.remove(id);
        _itemErrors[id] = _friendlyError(e);
      });
    }
  }

  void _previewPhoto({required String label, String? localPath, String? remoteUrl}) {
    final file = localPath == null ? null : File(localPath);
    final hasFile = file != null && file.existsSync();
    if (!hasFile && (remoteUrl == null || remoteUrl.isEmpty)) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.grey800,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: SizedBox(
                height: 360,
                child: hasFile
                    ? Image.file(file, fit: BoxFit.contain)
                    : SecureNetworkImage(fileUrl: remoteUrl, fit: BoxFit.contain, width: double.infinity, height: 360),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in _requirements) {
      final category = row['serviceCategory'];
      final name = category is Map ? '${category['name']}' : 'Equipment';
      groups.putIfAbsent(name, () => []).add(row);
    }
    final submitted = _requirements.where((row) => _countsAsSubmitted(_shotFor(row))).length;
    final approved = _requirements.where((row) => _shotFor(row) == _EquipmentShot.approved).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Equipment proof', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  if (_error != null)
                    _MessageState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Couldn’t load equipment',
                      body: _error!,
                      actionLabel: 'Try again',
                      onAction: _load,
                    )
                  else if (_requirements.isEmpty)
                    const _MessageState(
                      icon: Icons.photo_camera_outlined,
                      title: 'No equipment required',
                      body: 'When a job type needs a photo of your kit, it will show up here.',
                    )
                  else ...[
                    _EquipmentProgress(submitted: submitted, approved: approved, total: _requirements.length),
                    const SizedBox(height: 20),
                    ...groups.entries.map((entry) {
                      final done = entry.value.where((row) => _countsAsSubmitted(_shotFor(row))).length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  done == entry.value.length ? Icons.check_circle_rounded : _jobTypeIcon(entry.key),
                                  size: 18,
                                  color: done == entry.value.length ? AppColors.success : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: _SectionLabel(entry.key)),
                                Text(
                                  '$done/${entry.value.length}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: done == entry.value.length ? AppColors.success : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...entry.value.map((row) {
                              final id = _requirementId(row);
                              final shot = _shotFor(row);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _EquipmentItem(
                                  label: row['label']?.toString() ?? 'Equipment',
                                  shot: shot,
                                  localPath: _localPreviews[id],
                                  remoteUrl: _proofUrl(row),
                                  error: _itemErrors[id],
                                  rejectionReason: shot == _EquipmentShot.rejected ? _nestedText(row, const ['rejectionReason', 'rejectReason', 'reason']) : null,
                                  onCapture: () => _capture(row),
                                  onPreview: () => _previewPhoto(
                                    label: row['label']?.toString() ?? 'Equipment',
                                    localPath: _localPreviews[id],
                                    remoteUrl: _proofUrl(row),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
    );
  }
}

class _EquipmentProgress extends StatelessWidget {
  const _EquipmentProgress({required this.submitted, required this.approved, required this.total});

  final int submitted;
  final int approved;
  final int total;

  @override
  Widget build(BuildContext context) {
    final allApproved = total > 0 && approved == total;
    final allSubmitted = total > 0 && submitted == total;
    final complete = allApproved || allSubmitted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: complete ? AppColors.successLight : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: complete ? AppColors.success.withValues(alpha: 0.35) : AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Photos', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      allApproved ? 'All $total photos approved' : '$submitted of $total photos submitted',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: complete ? AppColors.success : AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (complete ? AppColors.success : AppColors.primary).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  allApproved ? Icons.verified_rounded : complete ? Icons.cloud_done_rounded : Icons.photo_camera_outlined,
                  color: complete ? AppColors.success : AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : submitted / total,
              minHeight: 8,
              backgroundColor: AppColors.grey300,
              color: complete ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            allApproved
                ? 'Every required photo is approved.'
                : allSubmitted
                    ? 'All photos are in. A job type stays locked until these are approved.'
                    : 'Photograph each item with your camera. Gallery photos aren’t accepted.',
            style: GoogleFonts.poppins(fontSize: 12, height: 1.45, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EquipmentItem extends StatelessWidget {
  const _EquipmentItem({
    required this.label,
    required this.shot,
    required this.localPath,
    required this.remoteUrl,
    required this.error,
    required this.rejectionReason,
    required this.onCapture,
    required this.onPreview,
  });

  final String label;
  final _EquipmentShot shot;
  final String? localPath;
  final String? remoteUrl;
  final String? error;
  final String? rejectionReason;
  final VoidCallback onCapture;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final locked = shot == _EquipmentShot.approved || shot == _EquipmentShot.uploading;
    final hasPhoto = _hasLocalPhoto(localPath) || (remoteUrl != null && remoteUrl!.isNotEmpty);
    final (status, color, hint) = switch (shot) {
      _EquipmentShot.needed => ('Photo needed', AppColors.grey500, 'Tap to open the camera.'),
      _EquipmentShot.uploading => ('Uploading', AppColors.primaryDark, 'Keep this screen open.'),
      _EquipmentShot.submitted => ('Submitted', AppColors.primaryDark, 'Saved. Tap the photo to view it, or retake if it is unclear.'),
      _EquipmentShot.approved => ('Approved', AppColors.success, 'Accepted for this job type.'),
      _EquipmentShot.rejected => ('Retake', AppColors.error, rejectionReason ?? 'This photo was declined. Take a new one.'),
    };

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: locked ? (hasPhoto ? onPreview : null) : (shot == _EquipmentShot.submitted && hasPhoto ? onPreview : onCapture),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: shot == _EquipmentShot.rejected
                  ? AppColors.error
                  : shot == _EquipmentShot.approved
                      ? AppColors.success.withValues(alpha: 0.45)
                      : shot == _EquipmentShot.submitted
                          ? AppColors.primary.withValues(alpha: 0.45)
                          : AppColors.divider,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: color == AppColors.grey500 ? AppColors.divider : color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _EquipmentThumb(
                            shot: shot,
                            localPath: localPath,
                            remoteUrl: remoteUrl,
                            onPreview: hasPhoto ? onPreview : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3, color: AppColors.textPrimary)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(status, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                                ),
                                const SizedBox(height: 6),
                                Text(error ?? hint, style: GoogleFonts.poppins(fontSize: 12, height: 1.35, color: error == null ? AppColors.textSecondary : AppColors.error)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (shot == _EquipmentShot.uploading)
                            const Padding(
                              padding: EdgeInsets.only(top: 18),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              ),
                            )
                          else if (shot == _EquipmentShot.approved)
                            const Padding(
                              padding: EdgeInsets.only(top: 18),
                              child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                            )
                          else
                            IconButton(
                              onPressed: onCapture,
                              tooltip: shot == _EquipmentShot.submitted ? 'Retake photo' : 'Take photo',
                              icon: Icon(
                                shot == _EquipmentShot.submitted ? Icons.refresh_rounded : Icons.photo_camera_outlined,
                                color: shot == _EquipmentShot.rejected ? AppColors.error : AppColors.primaryDark,
                                size: 22,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _hasLocalPhoto(String? localPath) {
  if (localPath == null) return false;
  return File(localPath).existsSync();
}

class _EquipmentThumb extends StatelessWidget {
  const _EquipmentThumb({
    required this.shot,
    required this.localPath,
    required this.remoteUrl,
    required this.onPreview,
  });

  final _EquipmentShot shot;
  final String? localPath;
  final String? remoteUrl;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final file = localPath == null ? null : File(localPath!);
    final hasFile = file != null && file.existsSync();
    Widget image;
    if (hasFile) {
      image = Image.file(file, fit: BoxFit.cover);
    } else if (remoteUrl != null && remoteUrl!.isNotEmpty) {
      image = SecureNetworkImage(
        fileUrl: remoteUrl,
        fit: BoxFit.cover,
        width: 72,
        height: 72,
        errorWidget: _placeholder(),
        placeholder: _placeholder(),
      );
    } else {
      image = _placeholder();
    }

    return GestureDetector(
      onTap: onPreview,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (shot == _EquipmentShot.uploading)
                const ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                ),
              if (shot == _EquipmentShot.submitted || shot == _EquipmentShot.approved)
                const Positioned(
                  right: 4,
                  bottom: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.12),
      child: const Icon(Icons.add_a_photo_outlined, color: AppColors.primaryDark, size: 22),
    );
  }
}
