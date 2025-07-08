import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show GoogleMap, GoogleMapController, Marker, MarkerId, BitmapDescriptor, CameraPosition, LatLng, InfoWindow;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/event.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Event> _events = [];
  bool _isLoading = true;
  bool _showMarkers = true;
  late StreamSubscription<QuerySnapshot> _eventsSubscription;
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    _eventsSubscription = FirebaseFirestore.instance
        .collection('events')
        .snapshots()
        .listen((snapshot) {
      final events = snapshot.docs
          .map((doc) => Event.fromFirestore(doc))
          .where((event) => event.latitude != 0.0 && event.longitude != 0.0)
          .toList();
      setState(() {
        _events = events;
        _isLoading = false;
        _updateMarkers();
      });
    }, onError: (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching events: $e');
    });
  }

  void _updateMarkers() {
    if (!_showMarkers) {
      setState(() {
        _markers.clear();
      });
      return;
    }
    final newMarkers = _events.map((event) {
      return Marker(
        markerId: MarkerId(event.id),
        position: LatLng(event.latitude, event.longitude),
        infoWindow: InfoWindow(title: event.title),
        icon: BitmapDescriptor.defaultMarkerWithHue(270.0),
      );
    }).toSet();
    setState(() {
      _markers
        ..clear()
        ..addAll(newMarkers);
    });
  }

  @override
  void dispose() {
    _eventsSubscription.cancel();
    super.dispose();
  }

  void _toggleMarkers() {
    setState(() {
      _showMarkers = !_showMarkers;
      _updateMarkers();
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Events Map'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.deepPurple),
        titleTextStyle: const TextStyle(color: Colors.deepPurple, fontSize: 20, fontWeight: FontWeight.w600),
        actionsIconTheme: const IconThemeData(color: Colors.deepPurple),
        actions: [
          IconButton(
            icon: Icon(_showMarkers ? Icons.visibility : Icons.visibility_off, color: Colors.deepPurple),
            onPressed: _toggleMarkers,
            tooltip: _showMarkers ? 'Hide Markers' : 'Show Markers',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: const CameraPosition(
                target: LatLng(0.347596, 32.582520), // Kampala
                zoom: 12.0,
              ),
              markers: _markers,
            ),
    );
  }
}
