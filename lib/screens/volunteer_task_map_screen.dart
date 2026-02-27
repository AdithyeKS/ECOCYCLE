import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class VolunteerTaskMapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String destinationName;
  final String destinationAddress;

  const VolunteerTaskMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.destinationName,
    required this.destinationAddress,
  });

  @override
  State<VolunteerTaskMapScreen> createState() => _VolunteerTaskMapScreenState();
}

class _VolunteerTaskMapScreenState extends State<VolunteerTaskMapScreen> {
  LatLng? _currentLocation;
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;

  late LatLng _pickupLocation;

  @override
  void initState() {
    super.initState();
    _pickupLocation = LatLng(widget.latitude, widget.longitude);

    debugPrint('Init Map: Lat: ${widget.latitude}, Lng: ${widget.longitude}');
    debugPrint('Address: ${widget.destinationAddress}');

    // Check for valid destination coordinates
    if (widget.latitude == 0.0 && widget.longitude == 0.0) {
      if (widget.destinationAddress.isNotEmpty &&
          widget.destinationAddress != 'Unknown Address') {
        _geocodeAddress(widget.destinationAddress);
      } else {
        _handleMissingLocation();
      }
    } else {
      _initializeLocation();
    }
  }

  void _handleMissingLocation() {
    _isLoadingRoute = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('No GPS data available and no valid address to search.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    });
  }

  Future<void> _geocodeAddress(String address) async {
    setState(() => _isLoadingRoute = true); // Show loading while geocoding
    try {
      final url =
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1';
      debugPrint('Geocoding URL: $url');

      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'EcoCycle/1.0'});

      debugPrint('Geocoding Response: ${response.statusCode}');
      debugPrint('Geocoding Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);

          if (mounted) {
            setState(() {
              _pickupLocation = LatLng(lat, lon);
            });
            _initializeLocation(); // Proceed with normal flow
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location found from address!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }
        } else {
          debugPrint('Geocoding returned empty list');
          if (mounted) {
            setState(() => _isLoadingRoute = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Could not find location for: "${address.length > 20 ? '${address.substring(0, 20)}...' : address}"'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        // HTTP Error
        if (mounted) {
          setState(() => _isLoadingRoute = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Address search failed: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
      if (mounted) {
        setState(() => _isLoadingRoute = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching address: $e')),
        );
      }
    }
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location permissions are permanently denied.')),
        );
      }
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentLocation =
            _validateLatLng(position.latitude, position.longitude);
      });
      _fetchRoute();
      _mapController.move(_currentLocation!, 15.0);
    }

    // Listen to location changes
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentLocation =
              _validateLatLng(position.latitude, position.longitude);
        });
      }
    });
  }

  Future<void> _fetchRoute() async {
    if (_currentLocation == null) return;

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${_currentLocation!.longitude},${_currentLocation!.latitude};'
          '${_pickupLocation.longitude},${_pickupLocation.latitude}'
          '?overview=full&geometries=polyline';

      debugPrint('Fetching route from: $url');
      final response = await http.get(Uri.parse(url));
      debugPrint('Route response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          final points = _decodePolyline(geometry);
          if (mounted) {
            setState(() {
              _routePoints = points;
              _isLoadingRoute = false;
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No route found to this location.')),
            );
            setState(() => _isLoadingRoute = false);
          }
        }
      } else {
        debugPrint('Route failed: ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to load route: ${response.statusCode}')),
          );
          setState(() => _isLoadingRoute = false);
        }
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
  }

  // Simplified Polyline6 decoder for OSRM
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      // OSRM standard Polyline uses 1e5 precision
      points.add(_validateLatLng(lat / 100000.0, lng / 100000.0));
    }
    return points;
  }

  LatLng _validateLatLng(double lat, double lon) {
    // Force coordinates into valid ranges to prevent assertion failures
    double validLat = lat.clamp(-90.0, 90.0);
    double validLon = lon.clamp(-180.0, 180.0);
    return LatLng(validLat, validLon);
  }

  Future<void> _launchGoogleMaps() async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${_pickupLocation.latitude},${_pickupLocation.longitude}&travelmode=driving';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Google Maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.destinationName),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)],
            ),
          ),
        ),
        actions: [
          if (_isLoadingRoute)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRoute,
            tooltip: 'Refresh Route',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickupLocation,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.ecocycle',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.0,
                      color: Colors.green.shade700,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Pickup Marker
                  Marker(
                    point: _pickupLocation,
                    width: 80,
                    height: 80,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 4)
                            ],
                          ),
                          child: const Text(
                            'Pickup',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red),
                          ),
                        ),
                        const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ],
                    ),
                  ),
                  // Current Location Marker
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 60,
                      height: 60,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 30,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Positioned Info Bar
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'recenter',
                  onPressed: () {
                    if (_currentLocation != null) {
                      _mapController.move(_currentLocation!, 15.0);
                    }
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Colors.blue),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.red),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.destinationName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    widget.destinationAddress,
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _launchGoogleMaps,
                            icon: const Icon(Icons.navigation),
                            label: const Text('Start Navigation (Google Maps)'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
