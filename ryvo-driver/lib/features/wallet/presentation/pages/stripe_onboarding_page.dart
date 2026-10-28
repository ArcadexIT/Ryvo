import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/theme/app_colors.dart';

/// Stripe hosted payout setup. Closes itself and returns to the wallet
/// when Stripe redirects to the RYVO return or refresh URL.
class StripeOnboardingPage extends StatefulWidget {
  const StripeOnboardingPage({super.key, required this.url, this.title = 'Set up payouts'});

  final String url;
  final String title;

  @override
  State<StripeOnboardingPage> createState() => _StripeOnboardingPageState();
}

class _StripeOnboardingPageState extends State<StripeOnboardingPage> {
  late final WebViewController _controller;
  var _loading = true;
  var _closed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            final handoff = _handoff(request.url);
            if (handoff == null) return NavigationDecision.navigate;
            WidgetsBinding.instance.addPostFrameCallback((_) => _finish(handoff));
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  /// True when Stripe finished onboarding, false when the link expired.
  bool? _handoff(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host != 'ryvo.arcadexit.com') return null;
    if (uri.path == '/stripe/return' || uri.path.startsWith('/stripe/return/')) return true;
    if (uri.path == '/stripe/refresh' || uri.path.startsWith('/stripe/refresh/')) return false;
    if (uri.scheme == 'ryvodriver') return true;
    return null;
  }

  void _finish(bool completed) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(completed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _finish(false),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
        ],
      ),
    );
  }
}
