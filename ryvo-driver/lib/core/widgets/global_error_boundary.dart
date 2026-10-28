import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class GlobalErrorBoundary extends StatefulWidget {
  final Widget child;
  const GlobalErrorBoundary({super.key, required this.child});

  @override
  State<GlobalErrorBoundary> createState() => _GlobalErrorBoundaryState();
}

class _GlobalErrorBoundaryState extends State<GlobalErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: _ErrorCatcher(
        onError: (e) => setState(() => _error = e),
        child: _error != null ? _ErrorView(error: _error!, onRetry: () => setState(() => _error = null)) : widget.child,
      ),
    );
  }
}

class _ErrorCatcher extends StatelessWidget {
  final Widget child;
  final ValueChanged<Object> onError;

  const _ErrorCatcher({required this.child, required this.onError});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context).somethingWentWrong, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(error.toString(), style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onRetry, child: Text(AppLocalizations.of(context).tryAgain)),
            ],
          ),
        ),
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  final bool isOffline;
  const OfflineBanner({super.key, required this.isOffline});

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();
    return Material(
      color: AppColors.error,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context).noInternetConnection, style: GoogleFonts.poppins(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class AppErrorObserver {
  static void log(Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('App error: $error\n$stack');
    }
  }
}
