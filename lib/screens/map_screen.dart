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
  // Use const distance object for efficiency
  final Distance _distance = const Distance();

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
  
  // FIX: Refactored _locate() function for robust permission and service checks
  Future<void> _locate() async {
    // 1. Check if location services (GPS) are enabled on the device.
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (mounted) {
        // The exact error message you reported! Use an alert to guide the user.
        _showAlertDialog(
          title: 'Location Services Disabled',
          content: 'The device location services (GPS) are currently disabled. Please enable them in your phone settings to show your current position.',
        );
      }
      return;
    }

    // 2. Check for app permissions.
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission if initially denied.
      permission = await Geolocator.requestPermission();
    }
    
    // 3. Handle denial states.
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
         _showAlertDialog(
          title: 'Permission Permanently Denied',
          content: 'Location permission has been permanently denied. You must grant access in the app settings.',
        );
      }
      return;
    }
    if (permission == LocationPermission.denied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permission denied. Cannot locate you.')));
      }
      return;
    }

    // 4. Get position and update map.
    try {
      final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final me = LatLng(p.latitude, p.longitude);
      
      if (mounted) {
        setState(() {
          _me = me;
          _center = me;
        });
      }
      
      _controller.move(_center, 15);
      _computeNearest();
      
      // Automatically show nearest list for convenience after locating
      if (mounted) {
        Future.delayed(
            const Duration(milliseconds: 400), () => _showNearestSheet());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error getting location: ${e.toString().contains('Timeout') ? 'Location request timed out or failed to get position.' : e.toString()}')));
      }
    }
  }

  // Helper function to show alerts (replacing snackbars for critical messages)
  void _showAlertDialog({required String title, required String content}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          // Optionally guide user to settings if permission/service is denied/disabled
          if (title.contains('Disabled') || title.contains('Permanently Denied'))
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Geolocator.openLocationSettings();
              },
              child: const Text('Go to Settings'),
            ),
        ],
      ),
    );
  }

  void _computeNearest() {
    if (_me == null) return;
    final List<MapCenter> sorted = List.from(_centers);
    sorted.sort((a, b) {
      final da = _distance.distance(_me!, LatLng(a.lat, a.lon));
      final db = _distance.distance(_me!, LatLng(b.lat, b.lon));
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
              final dist = _distance.distance(_me!, LatLng(c.lat, c.lon));
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
          // FIX: Use Theme colors for better light/dark mode compatibility
          child: Icon(
              c.type.toLowerCase().contains('gov')
                  ? Icons.location_city
                  : Icons.volunteer_activism,
              color: c.type.toLowerCase().contains('gov')
                  ? Theme.of(context).colorScheme.primary
                  : Colors.green.shade700,
              size: 30),
        ),
      ));
    }

    if (_me != null) {
      markers.add(Marker(
        point: _me!,
        width: 56,
        height: 56,
        // FIX: Use theme primary color, not hardcoded red, for location
        child: Icon(Icons.my_location, size: 40, color: Theme.of(context).colorScheme.secondary),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eco Map (OpenStreetMap)'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)],
            ),
          ),
        ),
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