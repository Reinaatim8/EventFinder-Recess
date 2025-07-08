import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
      });
    }, onError: (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching events: $e');
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
    });
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
          : FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(0.347596, 32.582520), // Kampala
                initialZoom: 12.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.event_locator_app',
                ),
                if (_showMarkers)
                  MarkerLayer(
                    markers: _events.map((event) {
                      return Marker(
                        width: 40.0,
                        height: 40.0,
                        point: LatLng(event.latitude, event.longitude),
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
                      );
                    }).toList(),
                  ),
              ],
            ),
    );
  }
}
