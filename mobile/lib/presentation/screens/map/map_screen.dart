import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../data/services/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _locationService = LocationService();
  GoogleMapController? _mapController;
  final Map<String, Marker> _markers = {};

  static const LatLng _initialPosition = LatLng(-23.5505, -46.6333); // São Paulo

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  void _startTracking() async {
    // TODO: obter groupId e userId do estado global (Riverpod)
    await _locationService.startTracking('group-id', 'user-id');

    _locationService.locationStream?.listen((data) {
      // Atualiza marcadores dos membros recebidos via WebSocket
      // TODO: parsear data e atualizar _markers no setState
    });
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MinhaTurma'),
        actions: [
          IconButton(icon: const Icon(Icons.chat), onPressed: () => context.go('/chat/group-id')),
          IconButton(icon: const Icon(Icons.person), onPressed: () => context.go('/profile')),
        ],
      ),
      body: GoogleMap(
        onMapCreated: (ctrl) => _mapController = ctrl,
        initialCameraPosition: const CameraPosition(target: _initialPosition, zoom: 14),
        markers: _markers.values.toSet(),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        mapToolbarEnabled: false,
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
