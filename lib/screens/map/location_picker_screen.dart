import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({Key? key}) : super(key: key);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng _selectedLocation = LatLng(0.347596, 32.582520); // Default to Kampala
  bool _locationSelected = false;
  String? _locationName;
  bool _isLoadingLocationName = false;

  void _onTapMap(TapPosition tapPosition, LatLng latlng) async {
    setState(() {
      _selectedLocation = latlng;
      _locationSelected = true;
      _isLoadingLocationName = true;
      _locationName = null;
    });

    try {
      final name = await _reverseGeocode(latlng);
      setState(() {
        _locationName = name;
        _isLoadingLocationName = false;
      });
    } catch (e) {
      setState(() {
        _locationName = 'Unknown location';
        _isLoadingLocationName = false;
      });
    }
  }

  Future<String> _reverseGeocode(LatLng latlng) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${latlng.latitude}&lon=${latlng.longitude}');
    final response = await http.get(url, headers: {
      'User-Agent': 'EventFinderRecessApp/1.0 (your_email@example.com)'
    });
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['display_name'] ?? 'Unknown location';
    } else {
      throw Exception('Failed to reverse geocode');
    }
  }

  void _onConfirm() {
    if (_locationSelected) {
      Navigator.pop(context, _selectedLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.deepPurple),
        titleTextStyle: const TextStyle(color: Colors.deepPurple, fontSize: 20, fontWeight: FontWeight.w600),
        actionsIconTheme: const IconThemeData(color: Colors.deepPurple),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _locationSelected ? _onConfirm : null,
            tooltip: _locationSelected ? 'Confirm Location' : 'Select a location first',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: 12.0,
                onTap: _onTapMap,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.event_locator_app',
                ),
                if (_locationSelected)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(0.5),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.deepPurple,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: _isLoadingLocationName
                ? const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Loading location name...'),
                    ],
                  )
                : Text(
                    _locationName ?? 'Tap on the map to select a location',
                    style: const TextStyle(fontSize: 16),
                  ),
          ),
        ],
      ),
    );
  }
}
