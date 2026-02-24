import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers/auth_provider.dart';
import '../data/providers/group_provider.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/map/map_screen.dart';
import '../presentation/screens/chat/chat_screen.dart';
import '../presentation/screens/sos/sos_screen.dart';
import '../presentation/screens/group/group_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';

// Ponte entre Riverpod e GoRouter
class _AuthRouterNotifier extends ChangeNotifier {
  final Ref _ref;
  _AuthRouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
    _ref.listen<GroupState>(groupProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRouterNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final groupState = ref.read(groupProvider);

      // Aguarda inicialização
      if (authState.isLoading) return null;

      final isLoggedIn = authState.isLoggedIn;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isGroupRoute = state.matchedLocation == '/group';

      if (!isLoggedIn && !isAuthRoute) return '/login';

      if (isLoggedIn && isAuthRoute) {
        // Usuário logado mas sem grupo → vai para /group
        return groupState.groups.isEmpty ? '/group' : '/map';
      }

      // Logado, não em rota de auth; se estiver em /map mas sem grupo → /group
      if (isLoggedIn && !isAuthRoute && !isGroupRoute) {
        if (groupState.groups.isEmpty && state.matchedLocation == '/map') {
          return '/group';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login',    builder: (ctx, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (ctx, state) => const RegisterScreen()),
      GoRoute(path: '/map',      builder: (ctx, state) => const MapScreen()),
      GoRoute(
        path: '/chat/:groupId',
        builder: (ctx, state) =>
            ChatScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(path: '/sos',     builder: (ctx, state) => const SOSScreen()),
      GoRoute(path: '/group',   builder: (ctx, state) => const GroupScreen()),
      GoRoute(path: '/profile', builder: (ctx, state) => const ProfileScreen()),
    ],
  );
});
