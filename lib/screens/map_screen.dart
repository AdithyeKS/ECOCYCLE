import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class MapCenter {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final String address;
  final String type; // NGO / Govt
  MapCenter(
      {required this.id,
      required this.name,
      required this.lat,
      required this.lon,
      required this.address,
      required this.type});
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng _center = const LatLng(9.9312, 76.2673); // Kochi default
  LatLng? _me;
  final _controller = MapController();

  // Hardcoded centers (replace with API or DB later)
  final List<MapCenter> _centers = [
    MapCenter(
        id: 'c1',
        name: 'GreenEarth NGO',
        lat: 9.9400,
        lon: 76.2600,
        address: 'MG Road, Kochi',
        type: 'NGO'),
    MapCenter(
        id: 'c2',
        name: 'Kochi E-Waste Hub',
        lat: 9.9280,
        lon: 76.2560,
        address: 'Ernakulam Market',
        type: 'Government Approved'),
    MapCenter(
        id: 'c3',
        name: 'RecycleCare Center',
        lat: 9.9350,
        lon: 76.2700,
        address: 'Kacheripady',
        type: 'NGO'),
    MapCenter(
        id: 'c4',
        name: 'Municipal Collection Point',
        lat: 9.9200,
        lon: 76.2800,
        address: 'South Coast Road',
        type: 'Government Approved'),
  ];

  List<MapCenter> _nearest = [];

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      // show a message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Location services are disabled. Please enable them in settings.')));
      }
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Location permission denied. Please grant permission in app settings.')));
      }
      return;
    }

    try {
      final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final me = LatLng(p.latitude, p.longitude);
      setState(() {
        _me = me;
        _center = me;
      });
      _controller.move(_center, 15);
      _computeNearest();
      // automatically show nearest list for convenience
      if (mounted) {
        Future.delayed(
            const Duration(milliseconds: 400), () => _showNearestSheet());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error getting location: $e')));
      }
    }
  }

  void _computeNearest() {
    if (_me == null) return;
    final Distance dist = Distance();
    final List<MapCenter> sorted = List.from(_centers);
    sorted.sort((a, b) {
      final da = dist.distance(_me!, LatLng(a.lat, a.lon));
      final db = dist.distance(_me!, LatLng(b.lat, b.lon));
      return da.compareTo(db);
    });
    setState(() {
      _nearest = sorted.take(5).toList();
    });
  }

  Future<void> _launchNavigation(MapCenter c) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${c.lat},${c.lon}&travelmode=driving');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open maps')));
      }
    }
  }

  void _showNearestSheet() {
    if (_nearest.isEmpty) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const Icon(Icons.location_pin),
                  const SizedBox(width: 8),
                  const Text('Nearest collection centers',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ..._nearest.map((c) {
              final dist = Distance().distance(_me!, LatLng(c.lat, c.lon));
              final km = (dist / 1000).toStringAsFixed(2);
              return ListTile(
                leading: Icon(c.type.toLowerCase().contains('gov')
                    ? Icons.apartment
                    : Icons.volunteer_activism),
                title: Text(c.name),
                subtitle: Text('${c.address} • $km km'),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _controller.move(LatLng(c.lat, c.lon), 16);
                    _launchNavigation(c);
                  },
                  child: const Text('Navigate'),
                ),
              );
            }),
            const SizedBox(height: 12)
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    for (final c in _centers) {
      markers.add(Marker(
        point: LatLng(c.lat, c.lon),
        width: 48,
        height: 48,
        child: GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              builder: (ctx) => Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(c.address),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _launchNavigation(c);
                          },
                          icon: const Icon(Icons.directions),
                          label: const Text('Navigate'),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _controller.move(LatLng(c.lat, c.lon), 16);
                          },
                          child: const Text('View on map'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
          child: Icon(
              c.type.toLowerCase().contains('gov')
                  ? Icons.location_city
                  : Icons.volunteer_activism,
              color: c.type.toLowerCase().contains('gov')
                  ? Colors.blue
                  : Colors.green,
              size: 30),
        ),
      ));
    }

    if (_me != null) {
      markers.add(Marker(
        point: _me!,
        width: 56,
        height: 56,
        child: const Icon(Icons.my_location, size: 40, color: Colors.red),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eco Map (OpenStreetMap)'),
        actions: [
          IconButton(icon: const Icon(Icons.my_location), onPressed: _locate),
          IconButton(
              icon: const Icon(Icons.list), onPressed: _showNearestSheet),
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
          MarkerLayer(markers: markers),
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () =>
                    launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
              ),
            ],
          ),
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
