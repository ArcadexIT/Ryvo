import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// After checkout the booking stack is home -> request -> estimate.
/// Continuing with pushReplacement onto a shell tab duplicates that tab's
/// page key. go() replaces the stack and does not.
void main() {
  testWidgets('leaving checkout with go does not duplicate navigator page keys', (tester) async {
    final router = _router(
      onPay: (context) => context.go('/home'),
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.push('/service-request');
    await tester.pumpAndSettle();
    router.push('/price-estimate');
    await tester.pumpAndSettle();

    await tester.tap(find.text('pay'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('home'), findsOneWidget);
  });
}

GoRouter _router({required void Function(BuildContext context) onPay}) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/service-request', builder: (_, __) => const Text('request')),
      GoRoute(
        path: '/price-estimate',
        builder: (context, __) => TextButton(
          onPressed: () => onPay(context),
          child: const Text('pay'),
        ),
      ),
      GoRoute(
        path: '/searching',
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const Text('searching'),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => shell,
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const Text('home')),
          ]),
        ],
      ),
    ],
  );
}
