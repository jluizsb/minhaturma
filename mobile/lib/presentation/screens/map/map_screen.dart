import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_config.dart';
import '../../../config/theme.dart';
import '../../../data/providers/auth_provider.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final hasMapKey = AppConfig.googleMapsApiKey.isNotEmpty &&
        AppConfig.googleMapsApiKey != 'placeholder';

    return Scaffold(
      appBar: AppBar(
        title: const Text('MinhaTurma'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () => context.go('/chat/group-id'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.go('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: hasMapKey
          ? const Center(child: Text('Mapa (Google Maps)'))
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map_outlined, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Olá, ${user?.name ?? 'usuário'}!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Login realizado com sucesso.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Mapa disponível após configurar\nGOOGLE_MAPS_API_KEY.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/sos'),
        backgroundColor: AppTheme.danger,
        icon: const Icon(Icons.sos),
        label: const Text('SOS'),
      ),
    );
  }
}
