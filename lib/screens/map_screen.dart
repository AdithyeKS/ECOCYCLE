import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng _center = const LatLng(9.9312, 76.2673); // Kochi default
  LatLng? _me;
  final _controller = MapController();

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) return;

    final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _me = LatLng(p.latitude, p.longitude);
      _center = _me!;
    });
    _controller.move(_center, 15);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eco Map (OpenStreetMap)'),
        actions: [
          IconButton(icon: const Icon(Icons.my_location), onPressed: _locate),
        ],
      ),
      body: FlutterMap(
        mapController: _controller,
        options: MapOptions(initialCenter: _center, initialZoom: 12),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.ecocycle_1',
          ),
          if (_me != null)
            MarkerLayer(markers: [
              Marker(
                point: _me!,
                width: 50,
                height: 50,
                child: const Icon(Icons.location_on, size: 42, color: Colors.red),
              ),
            ]),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _locate,
        label: const Text('My location'),
        icon: const Icon(Icons.near_me),
      ),
    );
  }
}
