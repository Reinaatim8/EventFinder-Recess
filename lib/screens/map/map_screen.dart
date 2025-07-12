import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/event.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> 
    with TickerProviderStateMixin {
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
    'All', 'Music', 'Sports', 'Food', 'Art', 'Technology', 'Business', 'Other'
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
    final recorder = ui.PictureRecorder();
    // Increase canvas height to accommodate text below icon
    const double width = 140;
    const double height = 140;
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    const double padding = 8;
    const double circleSize = 100;

    // Get category color
    final categoryColor = _getCategoryColor(event.category);
    
    // Draw outer circle (shadow)
    final shadowPaint = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(
      Offset(width / 2, circleSize / 2 + padding), 
      circleSize / 2 - padding + 2, 
      shadowPaint
    );

    // Draw main circle
    final circlePaint = Paint()
      ..color = categoryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(width / 2, circleSize / 2 + padding), 
      circleSize / 2 - padding, 
      circlePaint
    );

    // Draw white inner circle
    final innerCirclePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(width / 2, circleSize / 2 + padding), 
      circleSize / 2 - padding - 8, 
      innerCirclePaint
    );

    // Draw category icon
    final iconPainter = TextPainter(
      text: TextSpan(
        text: _getCategoryIcon(event.category),
        style: TextStyle(
          fontSize: 24,
          color: categoryColor,
          fontFamily: 'MaterialIcons',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        width / 2 - iconPainter.width / 2,
        circleSize / 2 + padding - iconPainter.height / 2,
      ),
    );

    // Draw pulse effect for premium events
    if (event.price > 50) {
      final pulsePaint = Paint()
        ..color = categoryColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(
        Offset(width / 2, circleSize / 2 + padding), 
        circleSize / 2 - padding + 8, 
        pulsePaint
      );
    }

    // Draw event title text below the icon
    final titlePainter = TextPainter(
      text: TextSpan(
        text: event.title.length > 15 ? event.title.substring(0, 15) + '...' : event.title,
        style: TextStyle(
          fontSize: 16,
          color: Colors.deepPurpleAccent,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          shadows: [
            Shadow(
              blurRadius: 4,
              color: Colors.white,
              offset: Offset(0, 0),
            ),
            Shadow(
              blurRadius: 6,
              color: Colors.black45,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    titlePainter.layout(minWidth: 0, maxWidth: width);
    titlePainter.paint(
      canvas,
      Offset(
        (width - titlePainter.width) / 2,
        circleSize + padding + 8,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(bytes);
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'music': return const Color(0xFF9C27B0);
      case 'sports': return const Color(0xFF2196F3);
      case 'food': return const Color(0xFFFF9800);
      case 'art': return const Color(0xFFE91E63);
      case 'technology': return const Color(0xFF4CAF50);
      case 'business': return const Color(0xFF607D8B);
      default: return const Color(0xFF673AB7);
    }
  }

  String _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'music': return '\uE405'; // music_note
      case 'sports': return '\uE52F'; // sports_soccer
      case 'food': return '\uE56C'; // restaurant
      case 'art': return '\uE3B8'; // palette
      case 'technology': return '\uE30A'; // computer
      case 'business': return '\uE54C'; // business_center
      default: return '\uE878'; // event
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
        position: LatLng(event.latitude, event.longitude),
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
        LatLng(event.latitude, event.longitude),
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
                    color: _getCategoryColor(event.category),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    _getCategoryIconData(event.category),
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
                          color: _getCategoryColor(event.category),
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
                  _buildDetailRow(Icons.calendar_today, 'Date', event.date),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.location_on, 'Location', 
                    '${event.latitude.toStringAsFixed(4)}, ${event.longitude.toStringAsFixed(4)}'),
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.description, 'Description', event.description),
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
                      foregroundColor: _getCategoryColor(event.category),
                      side: BorderSide(color: _getCategoryColor(event.category)),
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
                      backgroundColor: _getCategoryColor(event.category),
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

  IconData _getCategoryIconData(String category) {
    switch (category.toLowerCase()) {
      case 'music': return Icons.music_note;
      case 'sports': return Icons.sports_soccer;
      case 'food': return Icons.restaurant;
      case 'art': return Icons.palette;
      case 'technology': return Icons.computer;
      case 'business': return Icons.business_center;
      default: return Icons.event;
    }
  }

  Widget _buildSearchAndFilter() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _filterEvents(value, _selectedCategory),
              decoration: InputDecoration(
                hintText: 'Search events...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isFilterExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
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
                            selectedColor: const Color(0xFF673AB7).withOpacity(0.2),
                            checkmarkColor: const Color(0xFF673AB7),
                            labelStyle: TextStyle(
                              color: isSelected ? const Color(0xFF673AB7) : Colors.grey[600],
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
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Events Map'),
        backgroundColor: Colors.white.withOpacity(0.95),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF673AB7)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF673AB7),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          ScaleTransition(
            scale: _fabAnimation,
            child: IconButton(
              icon: Icon(
                _showMarkers ? Icons.visibility : Icons.visibility_off,
                color: const Color(0xFF673AB7),
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF673AB7)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading events...',
                      style: TextStyle(
                        color: Color(0xFF673AB7),
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
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          color: const Color(0xFF673AB7),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_filteredEvents.length} events',
                          style: const TextStyle(
                            color: Color(0xFF673AB7),
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
          backgroundColor: const Color(0xFF673AB7),
          child: const Icon(Icons.my_location, color: Colors.white),
        ),
      ),//j
    );
  }
}