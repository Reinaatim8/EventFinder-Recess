import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({Key? key}) : super(key: key);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng _selectedLocation = const LatLng(0.347596, 32.582520); // Default to Kampala
  bool _locationSelected = false;
  String? _locationName;
  bool _isLoadingLocationName = false;
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};

  void _onTapMap(LatLng latlng) async {
    setState(() {
      _selectedLocation = latlng;
      _locationSelected = true;
      _isLoadingLocationName = true;
      _locationName = null;
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected-location'),
          position: latlng,
          icon: BitmapDescriptor.defaultMarkerWithHue(270.0),
        ),
      );
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
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
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _selectedLocation,
                zoom: 12.0,
              ),
              markers: _markers,
              onTap: _onTapMap,
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
