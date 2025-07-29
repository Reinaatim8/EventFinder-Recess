import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/event.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  List<Event> _events = [];
  List<Event> _filteredEvents = [];
  bool _isLoading = true;
  bool _showMarkers = true;
  String _selectedCategory = 'All';
  late StreamSubscription<QuerySnapshot> _eventsSubscription;
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final TextEditingController _searchController = TextEditingController();

  // Animation controllers
  late AnimationController _fabAnimationController;
  late AnimationController _filterAnimationController;
  late Animation<double> _fabAnimation;
  late Animation<Offset> _filterSlideAnimation;

  bool _isFilterExpanded = false;
  Event? _selectedEvent;

  // Categories for filtering
  final List<String> _categories = [
    'All', 'Music', 'Sports', 'Food', 'Art', 'Technology', 'Business', 'Exhibition', 'Theatre', 'Comedy', 'Concert', 'Conference', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _subscribeToEvents();
  }

  void _initializeAnimations() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fabAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    ));

    _filterSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOut,
    ));

    // Start FAB animation after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _fabAnimationController.forward();
    });
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
        _filteredEvents = events;
        _isLoading = false;
        _updateMarkers();
      });
    }, onError: (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error fetching events: $e');
    });
  }

  void _filterEvents(String query, String category) {
    setState(() {
      _filteredEvents = _events.where((event) {
        final matchesSearch = event.title.toLowerCase().contains(query.toLowerCase()) ||
                            event.description.toLowerCase().contains(query.toLowerCase());
        final matchesCategory = category == 'All' || event.category == category;
        return matchesSearch && matchesCategory;
      }).toList();
      _updateMarkers();
    });
  }

  Future<BitmapDescriptor> _createCustomMarker(Event event) async {
    return BitmapDescriptor.defaultMarkerWithHue(_getCategoryHue(event.category));
  }

  double _getCategoryHue(String category) {
    switch (category.toLowerCase()) {
      case 'music': return BitmapDescriptor.hueViolet;
      case 'sports': return BitmapDescriptor.hueBlue;
      case 'food': return BitmapDescriptor.hueOrange;
      case 'art': return BitmapDescriptor.hueRose;
      case 'technology': return BitmapDescriptor.hueGreen;
      case 'business': return BitmapDescriptor.hueAzure;
      default: return BitmapDescriptor.hueRed;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'music': return FontAwesomeIcons.music;
      case 'sports': return FontAwesomeIcons.futbol;
      case 'food': return FontAwesomeIcons.utensils;
      case 'art': return FontAwesomeIcons.palette;
      case 'technology': return FontAwesomeIcons.laptopCode;
      case 'business': return FontAwesomeIcons.businessTime;
      default: return FontAwesomeIcons.calendarAlt;
    }
  }

  void _updateMarkers() async {
    if (!_showMarkers) {
      setState(() {
        _markers.clear();
      });
      return;
    }
    final newMarkers = <Marker>{};
    for (final event in _filteredEvents) {
      final icon = await _createCustomMarker(event);
      final marker = Marker(
        markerId: MarkerId(event.id),
        position: LatLng(event.latitude ?? 0.0, event.longitude ?? 0.0),
        icon: icon,
        onTap: () => _onMarkerTap(event),
      );
      newMarkers.add(marker);
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(newMarkers);
    });
  }

  void _onMarkerTap(Event event) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedEvent = event;
    });

    // Animate camera to marker
    _mapController.animateCamera(
      CameraUpdate.newLatLngZoom(
       LatLng(event.latitude ?? 0.0, event.longitude ?? 0.0),
        15.0,
      ),
    );

    _showEventBottomSheet(event);
  }

  void _showEventBottomSheet(Event event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEventBottomSheet(event),
    );
  }

  Widget _buildEventBottomSheet(Event event) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 50,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // Event header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    _getCategoryIcon(event.category),
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        event.category,
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (event.price > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      '\$${event.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Event details
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(FontAwesomeIcons.calendarAlt, 'Date', event.date),
                  const SizedBox(height: 12),
                  _buildDetailRow(FontAwesomeIcons.mapMarkerAlt, 'Location',
                    '${(event.latitude ?? 0.0).toStringAsFixed(4)}, ${(event.longitude ?? 0.0).toStringAsFixed(4)}'),
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(FontAwesomeIcons.alignLeft, 'Description', event.description),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/eventDetails', arguments: event);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  spreadRadius: 7,
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),

            child: TextField(
              controller: _searchController,
              onChanged: (value) => _filterEvents(value, _selectedCategory),
              decoration: InputDecoration(
                hintText: 'Search events...',
                prefixIcon: const Icon(FontAwesomeIcons.search, color: Colors.blue),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isFilterExpanded ? FontAwesomeIcons.chevronUp : FontAwesomeIcons.chevronDown,
                    color: Colors.blue,
                  ),
                  onPressed: () {
                    setState(() {
                      _isFilterExpanded = !_isFilterExpanded;
                    });
                    if (_isFilterExpanded) {
                      _filterAnimationController.forward();
                    } else {
                      _filterAnimationController.reverse();
                    }
                  },
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),

          // Filter categories
          SlideTransition(
            position: _filterSlideAnimation,
            child: _isFilterExpanded
                ? Container(
                    margin: const EdgeInsets.only(top: 8),
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = category == _selectedCategory;

                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(category),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                              _filterEvents(_searchController.text, category);
                            },
                            selectedColor: Colors.blue.withOpacity(0.2),
                            checkmarkColor: Colors.blue,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.blue : Colors.grey[600],
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _toggleMarkers() {
    HapticFeedback.lightImpact();
    setState(() {
      _showMarkers = !_showMarkers;
      _updateMarkers();
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    // Set custom map style (optional)
    _mapController.setMapStyle('''
      [
        {
          "featureType": "poi",
          "elementType": "labels",
          "stylers": [{"visibility": "off"}]
        }
      ]
    ''');
  }

  @override
  void dispose() {
    _eventsSubscription.cancel();
    _searchController.dispose();
    _fabAnimationController.dispose();
    _filterAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'EVENTS ',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: 'MAP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(FontAwesomeIcons.map, color: Colors.white, size: 28), // Map icon on the right
          ],
        ),
        backgroundColor: Colors.blue,
        toolbarHeight: 70,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),

        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
        actions: [
          ScaleTransition(
            scale: _fabAnimation,
            child: IconButton(
              icon: Icon(
                _showMarkers ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash,
                color: Colors.white,
              ),
              onPressed: _toggleMarkers,
              tooltip: _showMarkers ? 'Hide Markers' : 'Show Markers',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Container(
              color: Colors.grey[50],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading events...',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(0.347596, 32.582520), // Kampala
                    zoom: 12.0,
                  ),
                  markers: _markers,
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                ),

                // Search and filter overlay
                Positioned(
                  top: kToolbarHeight + MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: _buildSearchAndFilter(),
                ),

                // Event count indicator
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          FontAwesomeIcons.mapMarkerAlt,
                          color: Colors.blue,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_filteredEvents.length} events',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton(
          onPressed: () {
            _mapController.animateCamera(
              CameraUpdate.newLatLngZoom(
                const LatLng(0.347596, 32.582520),
                12.0,
              ),
            );
          },
          backgroundColor: Colors.blue,
          child: const Icon(FontAwesomeIcons.mapMarkerAlt, color: Colors.white),
        ),
      ),
    );
  }
}
