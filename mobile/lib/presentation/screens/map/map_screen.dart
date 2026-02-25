import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

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
  bool _locationPermissionGranted = false;
  MapType _mapType = MapType.normal;
  bool _trafficEnabled = false;

  static const _defaultPosition = CameraPosition(
    target: LatLng(-23.5505, -46.6333), // São Paulo
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestLocationPermission();
      await _connect();
    });
  }

  Future<void> _requestLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) return;
    setState(() {
      _locationPermissionGranted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    });
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
    // Captura o notifier antes de chamar super.dispose() para evitar
    // uso de ref após o widget ser desmontado.
    final locNotifier = ref.read(locationProvider.notifier);
    _mapController?.dispose();
    super.dispose();
    locNotifier.disconnect();
  }

  Set<Marker> _buildMarkers(LocationState locState, String? myUserId) {
    final markers = <Marker>{};

    if (locState.myPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('me'),
        position: LatLng(locState.myPosition!.lat, locState.myPosition!.lng),
        infoWindow: const InfoWindow(title: 'Você'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

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

  void _goToMyLocation(LocationState locState) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          groupState.groups.isNotEmpty ? groupState.groups.first.name : 'MinhaTurma',
        ),
        actions: [
          if (locState.isConnected)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.wifi, color: Colors.green, size: 18),
            ),
          IconButton(
            icon: const Icon(Icons.sos),
            tooltip: 'SOS',
            color: AppTheme.danger,
            onPressed: () => context.push('/sos'),
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
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _defaultPosition,
            mapType: _mapType,
            trafficEnabled: _trafficEnabled,
            myLocationEnabled: _locationPermissionGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _buildMarkers(locState, user?.id),
            onMapCreated: (controller) {
              _mapController = controller;
              _goToMyLocation(locState);
            },
          ),
          // Botões de controle (lado direito)
          Positioned(
            right: 12,
            bottom: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapIconButton(
                  icon: Icons.my_location,
                  tooltip: 'Minha localização',
                  onPressed: () => _goToMyLocation(locState),
                ),
                const SizedBox(height: 8),
                _MapIconButton(
                  icon: Icons.add,
                  tooltip: 'Aproximar',
                  onPressed: () =>
                      _mapController?.animateCamera(CameraUpdate.zoomIn()),
                ),
                const SizedBox(height: 4),
                _MapIconButton(
                  icon: Icons.remove,
                  tooltip: 'Afastar',
                  onPressed: () =>
                      _mapController?.animateCamera(CameraUpdate.zoomOut()),
                ),
                const SizedBox(height: 8),
                _MapIconButton(
                  icon: Icons.satellite_alt,
                  tooltip: _mapType == MapType.satellite
                      ? 'Mapa normal'
                      : 'Visão satélite',
                  active: _mapType == MapType.satellite,
                  onPressed: () => setState(() {
                    _mapType = _mapType == MapType.satellite
                        ? MapType.normal
                        : MapType.satellite;
                  }),
                ),
                const SizedBox(height: 4),
                _MapIconButton(
                  icon: Icons.traffic,
                  tooltip: _trafficEnabled ? 'Ocultar tráfego' : 'Ver tráfego',
                  active: _trafficEnabled,
                  onPressed: () =>
                      setState(() => _trafficEnabled = !_trafficEnabled),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão quadrado estilo Google Maps. Quando [active] é true fica azul.
class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  const _MapIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? Colors.blue : Colors.white;
    final fg = active ? Colors.white : Colors.black87;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        elevation: 2,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 22, color: fg),
          ),
        ),
      ),
    );
  }
}
