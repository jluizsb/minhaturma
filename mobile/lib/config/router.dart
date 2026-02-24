import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/map/map_screen.dart';
import '../presentation/screens/chat/chat_screen.dart';
import '../presentation/screens/sos/sos_screen.dart';
import '../presentation/screens/group/group_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login',    builder: (ctx, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (ctx, state) => const RegisterScreen()),
      GoRoute(path: '/map',      builder: (ctx, state) => const MapScreen()),
      GoRoute(path: '/chat/:groupId', builder: (ctx, state) => ChatScreen(groupId: state.pathParameters['groupId']!)),
      GoRoute(path: '/sos',      builder: (ctx, state) => const SOSScreen()),
      GoRoute(path: '/group',    builder: (ctx, state) => const GroupScreen()),
      GoRoute(path: '/profile',  builder: (ctx, state) => const ProfileScreen()),
    ],
  );
});
