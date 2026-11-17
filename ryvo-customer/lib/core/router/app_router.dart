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
import '../../features/tracking/presentation/pages/rate_driver_page.dart';
import '../../features/profile/presentation/pages/appearance_page.dart';
import '../../features/profile/presentation/pages/delete_account_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/payment_methods_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/safety_page.dart';
import '../../features/profile/presentation/pages/saved_places_page.dart';
import '../../features/service_request/presentation/pages/searching_page.dart';
import '../../features/service_request/presentation/pages/no_providers_page.dart';
import '../../features/service_request/presentation/pages/service_request_sheet_page.dart';
import '../../features/tracking/presentation/pages/in_progress_page.dart';
import '../../features/tracking/presentation/pages/live_tracking_page.dart';
import '../../features/support/presentation/pages/create_support_ticket_page.dart';
import '../../features/support/presentation/pages/help_support_page.dart';
import '../../features/support/presentation/pages/support_ticket_detail_page.dart';
import '../../features/support/presentation/pages/support_tickets_page.dart';
import '../../features/vehicle/presentation/pages/add_vehicle_page.dart';
import '../../features/wallet/presentation/pages/top_up_page.dart';
import '../../features/wallet/presentation/pages/wallet_page.dart';
import '../../data/models/app_config.dart';
import '../../shared/providers/app_providers.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen<bool>(isAuthenticatedProvider, (_, __) => notifyListeners());
    ref.listen<bool>(
        needsPhoneVerificationProvider, (_, __) => notifyListeners());
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
      final publicPaths = {
        '/splash',
        '/onboarding',
        '/login',
        '/register',
        '/otp',
        '/reset-password'
      };
      final onPublic = publicPaths.contains(state.uri.path) ||
          state.uri.path.startsWith('/legal/');
      if (!isAuth && !onPublic) return '/login';
      if (isAuth && needsOtp && state.uri.path != '/otp') return '/otp';
      if (isAuth &&
          (state.uri.path == '/login' || state.uri.path == '/onboarding'))
        return '/home';

      final config =
          ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback;
      if (!config.customerWalletEnabled &&
          (state.uri.path == '/wallet' || state.uri.path == '/top-up')) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(
        path: '/legal/:key',
        pageBuilder: (_, state) => _fullscreenPage(
          state,
          LegalDocumentPage(documentKey: state.pathParameters['key']!),
        ),
      ),
      GoRoute(path: '/otp', builder: (_, __) => const OtpPage()),
      GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordPage()),
      GoRoute(
        path: '/add-vehicle',
        builder: (_, s) =>
            AddVehiclePage(vehicleId: s.uri.queryParameters['vehicleId']),
      ),
      GoRoute(
          path: '/service-request',
          builder: (_, __) => const ServiceRequestSheetPage()),
      GoRoute(
        path: '/searching',
        builder: (_, __) => const SearchingPage(),
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SearchingPage(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      ),
      GoRoute(path: '/live-tracking', builder: (_, __) => const LiveTrackingPage()),
      GoRoute(
          path: '/no-providers', builder: (_, __) => const NoProvidersPage()),
      GoRoute(path: '/in-progress', builder: (_, __) => const InProgressPage()),
      GoRoute(
        path: '/payment-success',
        pageBuilder: (_, state) =>
            _fullscreenPage(state, const RateDriverPage()),
      ),
      GoRoute(path: '/top-up', builder: (_, __) => const TopUpPage()),
      GoRoute(
        path: '/profile/delete-account',
        pageBuilder: (_, state) =>
            _fullscreenPage(state, const DeleteAccountPage()),
      ),
      GoRoute(
        path: '/profile/edit',
        pageBuilder: (_, state) =>
            _fullscreenPage(state, const EditProfilePage()),
      ),
      GoRoute(
        path: '/profile/appearance',
        pageBuilder: (_, state) =>
            _fullscreenPage(state, const AppearancePage()),
      ),
      GoRoute(
        path: '/profile/places',
        pageBuilder: (_, state) =>
            _fullscreenPage(state, const SavedPlacesPage()),
      ),
      GoRoute(
        path: '/profile/payment',
        pageBuilder: (_, state) =>
            _fullscreenPage(state, const PaymentMethodsPage()),
      ),
      GoRoute(
        path: '/profile/safety',
        pageBuilder: (_, state) => _fullscreenPage(state, const SafetyPage()),
      ),
      GoRoute(
        path: '/profile/wallet',
        pageBuilder: (_, state) => _fullscreenPage(
          state,
          const WalletPage(showClose: true),
        ),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (_, state) =>
            _fullscreenPage(state, const NotificationsPage()),
      ),
      GoRoute(
        path: '/invoices',
        pageBuilder: (_, state) => _fullscreenPage(state, const InvoicesPage()),
      ),
      GoRoute(
        path: '/invoices/:id',
        pageBuilder: (_, state) {
          final extra = state.extra;
          return _fullscreenPage(
            state,
            InvoiceDetailPage(
              invoiceId: state.pathParameters['id']!,
              initial: extra is CustomerInvoice ? extra : null,
            ),
          );
        },
      ),
      GoRoute(
        path: '/help',
        pageBuilder: (_, state) =>
            _fullscreenPage(state, const HelpSupportPage()),
      ),
      GoRoute(
        path: '/support/tickets',
        pageBuilder: (_, state) =>
            _fullscreenPage(state, const SupportTicketsPage()),
      ),
      GoRoute(
        path: '/support/new',
        pageBuilder: (_, state) => _fullscreenPage(
          state,
          CreateSupportTicketPage(
            initialCategory: state.uri.queryParameters['category'],
            initialSubject: state.uri.queryParameters['subject'],
            initialMessage: state.uri.queryParameters['message'],
            jobId: state.uri.queryParameters['jobId'],
          ),
        ),
      ),
      GoRoute(
        path: '/support/:id',
        pageBuilder: (_, state) => _fullscreenPage(
          state,
          SupportTicketDetailPage(ticketId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/chat/:jobId',
        builder: (_, state) => ChatPage(jobId: state.pathParameters['jobId']!),
      ),

      // Shell route (bottom nav)
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellPage(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeMapPage())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/bookings', builder: (_, __) => const BookingsPage())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/wallet', builder: (_, __) => const WalletPage())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfilePage())
          ]),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Center(
        child: Text('Page not found: ${state.error}',
            style: const TextStyle(color: Colors.white)),
      ),
    ),
  );
});

/// Profile and account screens rise from the bottom and drop back down on close.
Page<void> _fullscreenPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    fullscreenDialog: true,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    child: child,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.fastOutSlowIn,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}
