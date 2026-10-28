import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/legal/presentation/pages/legal_document_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/bookings/presentation/pages/bookings_page.dart';
import '../../features/bookings/domain/customer_invoice.dart';
import '../../features/bookings/presentation/pages/invoice_detail_page.dart';
import '../../features/bookings/presentation/pages/invoices_page.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/home/presentation/pages/home_map_page.dart';
import '../../features/home/presentation/pages/shell_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../../features/payment/presentation/pages/payment_selector_page.dart';
import '../../features/payment/presentation/pages/payment_success_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/service_request/presentation/pages/price_estimate_page.dart';
import '../../features/service_request/presentation/pages/searching_page.dart';
import '../../features/service_request/presentation/pages/no_providers_page.dart';
import '../../features/service_request/presentation/pages/service_request_sheet_page.dart';
import '../../features/tracking/presentation/pages/in_progress_page.dart';
import '../../features/tracking/presentation/pages/live_tracking_page.dart';
import '../../features/tracking/presentation/pages/provider_assigned_page.dart';
import '../../features/support/presentation/pages/create_support_ticket_page.dart';
import '../../features/support/presentation/pages/help_support_page.dart';
import '../../features/support/presentation/pages/support_ticket_detail_page.dart';
import '../../features/support/presentation/pages/support_tickets_page.dart';
import '../../features/vehicle/presentation/pages/add_vehicle_page.dart';
import '../../features/wallet/presentation/pages/top_up_page.dart';
import '../../features/wallet/presentation/pages/wallet_page.dart';
import '../../data/models/app_config.dart';
import '../../shared/providers/app_providers.dart';
import '../theme/theme_sync.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen<bool>(isAuthenticatedProvider, (_, __) => notifyListeners());
    ref.listen<bool>(needsPhoneVerificationProvider, (_, __) => notifyListeners());
  }
}

final _routerRefreshProvider = Provider<_RouterRefresh>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.read(_routerRefreshProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final isAuth = ref.read(isAuthenticatedProvider);
      final needsOtp = ref.read(needsPhoneVerificationProvider);
      final publicPaths = {'/splash', '/onboarding', '/login', '/register', '/otp', '/reset-password'};
      final onPublic = publicPaths.contains(state.uri.path) || state.uri.path.startsWith('/legal/');
      if (!isAuth && !onPublic) return '/login';
      if (isAuth && needsOtp && state.uri.path != '/otp') return '/otp';
      if (isAuth && (state.uri.path == '/login' || state.uri.path == '/onboarding')) return '/home';

      final config = ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback;
      if (!config.customerWalletEnabled &&
          (state.uri.path == '/wallet' || state.uri.path == '/top-up')) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => ThemeSync(builder: (_) => SplashPage())),
      GoRoute(path: '/onboarding', builder: (_, __) => ThemeSync(builder: (_) => OnboardingPage())),
      GoRoute(path: '/login', builder: (_, __) => ThemeSync(builder: (_) => LoginPage())),
      GoRoute(path: '/register', builder: (_, __) => ThemeSync(builder: (_) => RegisterPage())),
      GoRoute(
        path: '/legal/:key',
        builder: (_, state) => ThemeSync(
          builder: (_) => LegalDocumentPage(documentKey: state.pathParameters['key']!),
        ),
      ),
      GoRoute(path: '/otp', builder: (_, __) => ThemeSync(builder: (_) => OtpPage())),
      GoRoute(path: '/reset-password', builder: (_, __) => ThemeSync(builder: (_) => ResetPasswordPage())),
      GoRoute(
        path: '/add-vehicle',
        builder: (_, s) => ThemeSync(
          builder: (_) => AddVehiclePage(vehicleId: s.uri.queryParameters['vehicleId']),
        ),
      ),
      GoRoute(path: '/service-request', builder: (_, __) => ThemeSync(builder: (_) => ServiceRequestSheetPage())),
      GoRoute(path: '/price-estimate', builder: (_, __) => ThemeSync(builder: (_) => PriceEstimatePage())),
      GoRoute(
        path: '/searching',
        builder: (_, __) => ThemeSync(builder: (_) => SearchingPage()),
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey,
          child: ThemeSync(builder: (_) => SearchingPage()),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        ),
      ),
      GoRoute(
        path: '/provider-assigned',
        builder: (_, __) => ThemeSync(builder: (_) => ProviderAssignedPage()),
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey,
          child: ThemeSync(builder: (_) => ProviderAssignedPage()),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        ),
      ),
      GoRoute(path: '/live-tracking', builder: (_, __) => ThemeSync(builder: (_) => LiveTrackingPage())),
      GoRoute(path: '/no-providers', builder: (_, __) => ThemeSync(builder: (_) => const NoProvidersPage())),
      GoRoute(path: '/in-progress', builder: (_, __) => ThemeSync(builder: (_) => InProgressPage())),
      GoRoute(path: '/payment', builder: (_, __) => ThemeSync(builder: (_) => PaymentSelectorPage())),
      GoRoute(
        path: '/payment-success',
        builder: (_, __) => ThemeSync(builder: (_) => PaymentSuccessPage()),
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey,
          child: ThemeSync(builder: (_) => PaymentSuccessPage()),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        ),
      ),
      GoRoute(path: '/top-up', builder: (_, __) => ThemeSync(builder: (_) => TopUpPage())),
      GoRoute(path: '/notifications', builder: (_, __) => ThemeSync(builder: (_) => NotificationsPage())),
      GoRoute(path: '/invoices', builder: (_, __) => ThemeSync(builder: (_) => InvoicesPage())),
      GoRoute(
        path: '/invoices/:id',
        builder: (_, state) {
          final extra = state.extra;
          return ThemeSync(
            builder: (_) => InvoiceDetailPage(
              invoiceId: state.pathParameters['id']!,
              initial: extra is CustomerInvoice ? extra : null,
            ),
          );
        },
      ),
      GoRoute(path: '/help', builder: (_, __) => ThemeSync(builder: (_) => HelpSupportPage())),
      GoRoute(path: '/support/tickets', builder: (_, __) => ThemeSync(builder: (_) => SupportTicketsPage())),
      GoRoute(
        path: '/support/new',
        builder: (_, s) => ThemeSync(
          builder: (_) => CreateSupportTicketPage(
            initialCategory: s.uri.queryParameters['category'],
            jobId: s.uri.queryParameters['jobId'],
          ),
        ),
      ),
      GoRoute(
        path: '/support/:id',
        builder: (_, s) => ThemeSync(
          builder: (_) => SupportTicketDetailPage(ticketId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/chat/:jobId',
        builder: (_, state) => ThemeSync(builder: (_) => ChatPage(jobId: state.pathParameters['jobId']!)),
      ),

      // Shell route (bottom nav)
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ThemeSync(builder: (_) => ShellPage(navigationShell: shell)),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => ThemeSync(builder: (_) => HomeMapPage()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/bookings', builder: (_, __) => ThemeSync(builder: (_) => BookingsPage()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/wallet', builder: (_, __) => ThemeSync(builder: (_) => WalletPage()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, __) => ThemeSync(builder: (_) => ProfilePage()))]),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Center(
        child: Text('Page not found: ${state.error}', style: const TextStyle(color: Colors.white)),
      ),
    ),
  );
});
