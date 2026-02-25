import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../config/app_config.dart';
import '../../../config/theme.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/group_provider.dart';
import '../../../data/providers/location_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;

  static const _defaultPosition = CameraPosition(
    target: LatLng(-23.5505, -46.6333), // São Paulo
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  Future<void> _connect() async {
    final authState = ref.read(authProvider);
    final groupState = ref.read(groupProvider);

    if (authState.user == null || groupState.groups.isEmpty) return;

    final token = await ref.read(authServiceProvider).getAccessToken();
    if (token == null) return;

    final groupId = groupState.groups.first.id;
    final userId = authState.user!.id;

    await ref
        .read(locationProvider.notifier)
        .connect(token, groupId, userId);
  }

  @override
  void dispose() {
    ref.read(locationProvider.notifier).disconnect();
    _mapController?.dispose();
    super.dispose();
  }

  Set<Marker> _buildMarkers(LocationState locState, String? myUserId) {
    final markers = <Marker>{};

    // Marcador próprio (azul)
    if (locState.myPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('me'),
        position: LatLng(locState.myPosition!.lat, locState.myPosition!.lng),
        infoWindow: InfoWindow(title: 'Você'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    // Marcadores de outros membros (hue derivado do userId)
    for (final entry in locState.members.entries) {
      final loc = entry.value;
      final hue = (loc.userId.hashCode.abs() % 360).toDouble();
      markers.add(Marker(
        markerId: MarkerId(loc.userId),
        position: LatLng(loc.lat, loc.lng),
        infoWindow: InfoWindow(title: loc.userName),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      ));
    }

    return markers;
  }

  void _moveCameraToMe(LocationState locState) {
    if (_mapController == null || locState.myPosition == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(locState.myPosition!.lat, locState.myPosition!.lng),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final groupState = ref.watch(groupProvider);
    final locState = ref.watch(locationProvider);
    final hasMapKey = AppConfig.googleMapsApiKey.isNotEmpty &&
        AppConfig.googleMapsApiKey != 'placeholder';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          groupState.groups.isNotEmpty ? groupState.groups.first.name : 'MinhaTurma',
        ),
        actions: [
          if (locState.isConnected)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.wifi, color: Colors.green, size: 18),
            ),
          IconButton(
            icon: const Icon(Icons.group),
            tooltip: 'Grupos',
            onPressed: () => context.push('/group'),
          ),
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: 'Chat',
            onPressed: () => groupState.groups.isNotEmpty
                ? context.push('/chat/${groupState.groups.first.id}')
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(locationProvider.notifier).disconnect();
              ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: hasMapKey
          ? GoogleMap(
              initialCameraPosition: _defaultPosition,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              markers: _buildMarkers(locState, user?.id),
              onMapCreated: (controller) {
                _mapController = controller;
                _moveCameraToMe(locState);
              },
            )
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
                  if (locState.isConnected) ...[
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi, color: Colors.green, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'WebSocket conectado',
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sos'),
        backgroundColor: AppTheme.danger,
        icon: const Icon(Icons.sos),
        label: const Text('SOS'),
      ),
    );
  }
}
