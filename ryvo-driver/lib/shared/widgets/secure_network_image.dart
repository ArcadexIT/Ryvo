import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/di_providers.dart';

/// Loads a private S3 image via presigned URL from the API.
class SecureNetworkImage extends ConsumerStatefulWidget {
  final String? fileUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SecureNetworkImage({
    super.key,
    required this.fileUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  ConsumerState<SecureNetworkImage> createState() => _SecureNetworkImageState();
}

class _SecureNetworkImageState extends ConsumerState<SecureNetworkImage> {
  String? _resolvedUrl;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant SecureNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileUrl != widget.fileUrl) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final url = widget.fileUrl;
    if (url == null || url.isEmpty) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() {
        _resolvedUrl = url;
        _loading = false;
        _failed = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _failed = false;
    });

    try {
      final accessUrl = await ref.read(fileAccessServiceProvider).resolveAccessUrl(url);
      if (!mounted) return;
      setState(() {
        _resolvedUrl = accessUrl;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_loading) {
      child = widget.placeholder ??
          Container(
            color: AppColors.surface,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
    } else if (_failed || _resolvedUrl == null) {
      child = widget.errorWidget ??
          Container(
            color: AppColors.surface,
            child: const Icon(Icons.broken_image_outlined, color: AppColors.grey500),
          );
    } else {
      child = Image.network(
        _resolvedUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return widget.placeholder ??
              Container(
                color: AppColors.surface,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
        },
        errorBuilder: (_, __, ___) =>
            widget.errorWidget ??
            Container(
              color: AppColors.surface,
              child: const Icon(Icons.broken_image_outlined, color: AppColors.grey500),
            ),
      );
    }

    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }

    return SizedBox(width: widget.width, height: widget.height, child: child);
  }
}
