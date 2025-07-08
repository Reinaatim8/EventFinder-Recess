import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show GoogleMap, GoogleMapController, Marker, MarkerId, BitmapDescriptor, CameraPosition, LatLng, InfoWindow;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/event.dart'; //the devil is a liar

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

  Future<BitmapDescriptor> _createCustomMarker(String label) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double width = 150;
    const double height = 60;

    final paint = Paint()..color = Colors.deepPurple;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw label background
    final rect = Rect.fromLTWH(0, 0, width, height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rrect, paint);

    // Draw label text
    textPainter.text = TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout(minWidth: 0, maxWidth: width);
    textPainter.paint(canvas, const Offset(10, 15));

    // Draw marker icon (triangle pointer)
    final path = Path();
    path.moveTo(width / 2 - 10, height);
    path.lineTo(width / 2 + 10, height);
    path.lineTo(width / 2, height + 20);
    path.close();
    canvas.drawPath(path, paint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), (height + 20).toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(bytes);
  }

  void _updateMarkers() async {
    if (!_showMarkers) {
      setState(() {
        _markers.clear();
      });
      return;
    }
    final newMarkers = <Marker>{};
    for (final event in _events) {
      final icon = await _createCustomMarker(event.title);
      final marker = Marker(
        markerId: MarkerId(event.id),
        position: LatLng(event.latitude, event.longitude),
        icon: icon,
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(event.title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date: ${event.date}'),
                  Text('Category: ${event.category}'),
                  if (event.description.isNotEmpty) Text('Description: ${event.description}'),
                  if (event.price > 0) Text('Price: \$${event.price.toStringAsFixed(2)}'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/eventDetails', arguments: event);
                  },
                  child: const Text('View Details'),
                ),
              ],
            ),
          );
        },
      );
      newMarkers.add(marker);
    }
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
