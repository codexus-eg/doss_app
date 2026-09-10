import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/ride/booking_screen.dart';
import '../screens/ride/searching_screen.dart';
import '../screens/ride/active_ride_screen.dart';
import '../screens/ride/ride_completed_screen.dart';
import '../screens/history/ride_history_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/kyc/kyc_screen.dart';
import '../screens/shuttle/shuttle_booking_screen.dart';

class AppRouter {
  static final _rootKey = GlobalKey<NavigatorState>();

  static AuthBloc? _authBloc;
  static final _notifier = _BlocNotifier();

  static void setAuthBloc(AuthBloc bloc) {
    _authBloc = bloc;
    bloc.stream.listen((_) => _notifier.notify());
  }

  static final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: _notifier,
    redirect: (context, state) {
      final auth     = _authBloc?.state ?? context.read<AuthBloc>().state;
      final loggedIn = auth is AuthAuthenticated;
      final loading  = auth is AuthLoading || auth is AuthInitial;
      final loc      = state.matchedLocation;
      if (loading) return loc == '/splash' ? null : '/splash';
      if (!loggedIn) return (loc == '/login' || loc == '/register') ? null : '/login';
      if (loc == '/splash' || loc == '/login' || loc == '/register') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash',   builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/home',     builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/booking',  builder: (_, __) => const BookingScreen()),
      GoRoute(path: '/shuttle',  builder: (_, __) => const ShuttleBookingScreen()),
      GoRoute(path: '/searching',builder: (_, __) => const SearchingScreen()),
      GoRoute(path: '/active-ride', builder: (_, __) => const ActiveRideScreen()),
      GoRoute(
        path: '/ride-completed',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return RideCompletedScreen(
              fareEgp: (extra?['fareEgp'] as num?)?.toDouble() ?? 0,
              isShuttle: extra?['isShuttle'] as bool? ?? false);
        },
      ),
      GoRoute(path: '/history', builder: (_, __) => const RideHistoryScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/kyc',     builder: (_, __) => const KycScreen()),
    ],
    errorBuilder: (_, state) => Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Center(child: Text('Page not found: ${state.error}',
          style: const TextStyle(color: Colors.white))),
    ),
  );
}

class _BlocNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
