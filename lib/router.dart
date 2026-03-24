import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'ui/screens/commission_screen.dart';
import 'ui/screens/device_detail_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (_, state) => _fade(state, const HomeScreen()),
    ),
    GoRoute(
      path: '/commission',
      pageBuilder: (_, state) => _slide(state, const CommissionScreen()),
    ),
    GoRoute(
      path: '/device/:id',
      pageBuilder: (_, state) {
        final id = state.pathParameters['id']!;
        return _slide(state, DeviceDetailScreen(deviceId: id));
      },
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (_, state) => _slide(state, const SettingsScreen()),
    ),
  ],
);

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, c) =>
          FadeTransition(opacity: animation, child: c),
    );

CustomTransitionPage<void> _slide(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, secondaryAnimation, c) {
        final tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOutCubic));
        return SlideTransition(position: animation.drive(tween), child: c);
      },
    );
