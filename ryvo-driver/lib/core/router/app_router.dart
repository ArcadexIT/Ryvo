import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/earnings/presentation/pages/earnings_dashboard_page.dart';
import '../../features/earnings/presentation/pages/transaction_detail_page.dart';
import '../../features/home/presentation/pages/home_map_page.dart';
import '../../features/home/presentation/pages/shell_page.dart';
import '../../features/job_execution/presentation/pages/arrived_page.dart';
import '../../features/job_execution/presentation/pages/job_completed_page.dart';
import '../../features/job_execution/presentation/pages/service_in_progress_page.dart';
import '../../features/job_execution/presentation/pages/turn_by_turn_page.dart';
import '../../features/job_history/presentation/pages/job_history_page.dart';
import '../../features/kyc/presentation/pages/documents_verification_page.dart';
import '../../features/kyc/presentation/pages/ops_pages.dart';
import '../../features/kyc/presentation/pages/provider_agreement_page.dart';
import '../../features/kyc/presentation/pages/verification_pending_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../../features/profile/presentation/pages/help_support_page.dart';
import '../../features/support/presentation/pages/create_support_ticket_page.dart';
import '../../features/support/presentation/pages/support_ticket_detail_page.dart';
import '../../features/support/presentation/pages/support_tickets_page.dart';
import '../../features/profile/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/performance_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/personal_info_page.dart';
import '../../features/profile/presentation/pages/settings_pages.dart';
import '../../features/wallet/presentation/pages/add_bank_account_page.dart';
import '../../features/wallet/presentation/pages/wallet_page.dart';
import '../../features/wallet/presentation/pages/withdraw_funds_page.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/kyc_providers.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, anim, __, c) =>
        FadeTransition(opacity: anim, child: c),
  );
}

/// Keeps a single [GoRouter] instance while re-running [GoRouter.redirect]
/// when auth or KYC state changes (avoids rebuilding the whole navigator).
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen<bool>(isAuthenticatedProvider, (_, __) => notifyListeners());
    ref.listen<bool>(isKycApprovedProvider, (_, __) => notifyListeners());
    ref.listen<bool>(isKycInReviewProvider, (_, __) => notifyListeners());
    ref.listen<bool>(isAgreementAcceptedProvider, (_, __) => notifyListeners());
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
      final kycApproved = ref.read(isKycApprovedProvider);
      final documentsInReview = ref.read(isKycInReviewProvider);
      final agreementAccepted = ref.read(isAgreementAcceptedProvider);
      const publicPaths = {
        '/splash',
        '/onboarding',
        '/login',
        '/register',
        '/otp',
        '/reset-password'
      };
      final path = state.uri.path;
      final isPublic = publicPaths.contains(path);
      final isKycPath = path == '/kyc' ||
          path.startsWith('/kyc/') ||
          path == '/training' ||
          path.startsWith('/training/') ||
          path == '/compliance';

      if (!isAuth && !isPublic) return '/login';
      if (isAuth &&
          !agreementAccepted &&
          path != '/kyc/agreement' &&
          !isPublic) {
        return '/kyc/agreement';
      }
      if (isAuth &&
          agreementAccepted &&
          !kycApproved &&
          !isKycPath &&
          !isPublic) {
        return documentsInReview ? '/kyc/pending' : '/kyc';
      }
      // Only leave the agreement screen once it is actually accepted.
      // (KYC-approved alone must not bounce /kyc/agreement ↔ /home.)
      if (isAuth &&
          kycApproved &&
          agreementAccepted &&
          (path == '/login' ||
              path == '/onboarding' ||
              path == '/kyc/agreement' ||
              path == '/kyc' ||
              path == '/kyc/pending')) {
        return '/home';
      }
      if (isAuth &&
          agreementAccepted &&
          path == '/kyc/agreement' &&
          !kycApproved) {
        return documentsInReview ? '/kyc/pending' : '/kyc';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/otp', builder: (_, __) => const OtpPage()),
      GoRoute(
          path: '/reset-password',
          builder: (_, __) => const ResetPasswordPage()),
      GoRoute(
          path: '/kyc/agreement',
          builder: (_, __) => const ProviderAgreementPage()),
      GoRoute(
          path: '/kyc',
          builder: (_, __) =>
              const DocumentsVerificationPage(isOnboardingGate: true)),
      GoRoute(
          path: '/kyc/pending',
          builder: (_, __) => const VerificationPendingPage()),
      GoRoute(
          path: '/documents-verification',
          builder: (_, __) => const DocumentsVerificationPage()),
      GoRoute(
        path: '/kyc/document/:type',
        builder: (_, s) {
          final type = VerificationDocType.values.byName(s.pathParameters['type']!);
          if (type == VerificationDocType.equipment) return const EquipmentProofPage();
          return DocumentUploadPage(
            docType: type,
            isOnboarding: s.uri.queryParameters['onboarding'] == 'true',
          );
        },
      ),
      GoRoute(path: '/training', builder: (_, __) => const TrainingPage()),
      GoRoute(
        path: '/training/:id',
        builder: (_, s) => TrainingDetailPage(programId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/compliance',
        builder: (_, s) => CompliancePage(focusKey: s.uri.queryParameters['key']),
      ),
      GoRoute(
          path: '/navigation',
          pageBuilder: (_, s) => _fadePage(s, const TurnByTurnPage())),
      GoRoute(path: '/arrived', builder: (_, __) => const ArrivedPage()),
      GoRoute(
          path: '/in-progress',
          builder: (_, __) => const ServiceInProgressPage()),
      GoRoute(
        path: '/job-completed',
        pageBuilder: (_, s) => _fadePage(
          s,
          JobCompletedPage(jobId: s.uri.queryParameters['jobId']),
        ),
      ),
      GoRoute(
        path: '/transaction/:id',
        builder: (_, s) =>
            TransactionDetailPage(transactionId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/wallet', builder: (_, __) => const WalletPage()),
      GoRoute(path: '/withdraw', builder: (_, __) => const WithdrawFundsPage()),
      GoRoute(
          path: '/add-bank-account',
          builder: (_, __) => const AddBankAccountPage()),
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsPage()),
      GoRoute(
          path: '/performance', builder: (_, __) => const PerformancePage()),
      GoRoute(path: '/help', builder: (_, __) => const HelpSupportPage()),
      GoRoute(
          path: '/support/tickets',
          builder: (_, __) => const SupportTicketsPage()),
      GoRoute(
        path: '/support/new',
        builder: (_, s) => CreateSupportTicketPage(
          initialCategory: s.uri.queryParameters['category'],
          jobId: s.uri.queryParameters['jobId'],
        ),
      ),
      GoRoute(
        path: '/support/:id',
        builder: (_, s) =>
            SupportTicketDetailPage(ticketId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:jobId',
        builder: (_, s) => ChatPage(jobId: s.pathParameters['jobId']!),
      ),
      GoRoute(
          path: '/personal-info', builder: (_, __) => const PersonalInfoPage()),
      GoRoute(
          path: '/vehicle-info', builder: (_, __) => const VehicleInfoPage()),
      GoRoute(
          path: '/payment-methods',
          builder: (_, __) => const PaymentMethodsPage()),
      GoRoute(path: '/language', builder: (_, __) => const LanguagePage()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellPage(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeMapPage())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/earnings',
                builder: (_, __) => const EarningsDashboardPage())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/history', builder: (_, __) => const JobHistoryPage())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfilePage())
          ]),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text('Page not found: ${state.error}',
            style: TextStyle(color: AppColors.textPrimary)),
      ),
    ),
  );
});
