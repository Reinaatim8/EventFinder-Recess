
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/event.dart';
import '../../models/booking.dart';
import '../../services/booking_service.dart';

class AddEventScreen extends StatefulWidget {
  final VoidCallback onEventAdded;

  const AddEventScreen({Key? key, required this.onEventAdded}) : super(key: key);

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedCategory = 'Concert';
  File? _imageFile;
  bool _isLoading = false;

  final List<String> _categories = [
    'Concert',
    'Conference',
    'Workshop',
    'Sports',
    'Festival',
    'Networking',
    'Exhibition',
    'Theater',
    'Comedy',
    'Other'
  ];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(String eventId) async {
    if (_imageFile == null) return null;
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('events')
          .child('$eventId.jpg');
      await storageRef.putFile(_imageFile!);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _addEvent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final eventId = FirebaseFirestore.instance.collection('events').doc().id;
      final imageUrl = await _uploadImage(eventId);

      final event = Event(
        id: eventId,
        title: _titleController.text,
        category: _selectedCategory,
        date: _dateController.text,
        location: _locationController.text,
        description: _descriptionController.text,
        imageUrl: imageUrl,
        organizerId: authProvider.user!.uid,
        price: _priceController.text.toLowerCase() == 'free'
            ? 0.0
            : double.parse(_priceController.text),
        isVerified: false,
        verificationStatus: 'pending',
        verificationDocumentUrl: null,
        rejectionReason: null,
      );

      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .set(event.toFirestore());

      widget.onEventAdded();
      Navigator.pop(context);
      Fluttertoast.showToast(
        msg: "Event created successfully!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error creating event: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Event'),
        backgroundColor: const Color.fromARGB(255, 25, 25, 95),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Event Title *'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category *'),
                items: _categories
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedCategory = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (DD/MM/YYYY) *',
                  hintText: 'e.g., 15/07/2025',
                ),
                validator: (value) {
                  if (value!.isEmpty) return 'Required';
                  final regex = RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$');
                  if (!regex.hasMatch(value)) return 'Invalid format (DD/MM/YYYY)';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location *'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description *'),
                maxLines: 4,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price (UGX) *'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Required';
                  if (double.tryParse(value) == null && value.toLowerCase() != 'free') {
                    return 'Enter a valid number or "free"';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: _imageFile == null
                      ? const Center(child: Text('Tap to select image'))
                      : Image.file(_imageFile!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _addEvent,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: const Color.fromARGB(255, 25, 25, 95),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Create Event'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}

class EditEventScreen extends StatefulWidget {
  final Event event;
  final VoidCallback onEventUpdated;

  const EditEventScreen({Key? key, required this.event, required this.onEventUpdated})
      : super(key: key);

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedCategory = 'Concert';
  File? _imageFile;
  bool _isLoading = false;

  final List<String> _categories = [
    'Concert',
    'Conference',
    'Workshop',
    'Sports',
    'Festival',
    'Networking',
    'Exhibition',
    'Theater',
    'Comedy',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.event.title;
    _descriptionController.text = widget.event.description;
    _dateController.text = widget.event.date;
    _locationController.text = widget.event.location;
    _priceController.text = widget.event.price == 0.0 ? 'free' : widget.event.price.toString();
    _selectedCategory = widget.event.category;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(String eventId) async {
    if (_imageFile == null) return widget.event.imageUrl;
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('events')
          .child('$eventId.jpg');
      await storageRef.putFile(_imageFile!);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return widget.event.imageUrl;
    }
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final imageUrl = await _uploadImage(widget.event.id);
      final updatedEvent = Event(
        id: widget.event.id,
        title: _titleController.text,
        category: _selectedCategory,
        date: _dateController.text,
        location: _locationController.text,
        description: _descriptionController.text,
        imageUrl: imageUrl,
        organizerId: widget.event.organizerId,
        price: _priceController.text.toLowerCase() == 'free'
            ? 0.0
            : double.parse(_priceController.text),
        isVerified: widget.event.isVerified,
        verificationStatus: widget.event.verificationStatus,
        verificationDocumentUrl: widget.event.verificationDocumentUrl,
        rejectionReason: widget.event.rejectionReason,
      );

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .update(updatedEvent.toFirestore());

      widget.onEventUpdated();
      Navigator.pop(context);
      Fluttertoast.showToast(
        msg: "Event updated successfully!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error updating event: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
        backgroundColor: const Color.fromARGB(255, 25, 25, 95),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Event Title *'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category *'),
                items: _categories
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedCategory = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (DD/MM/YYYY) *',
                  hintText: 'e.g., 15/07/2025',
                ),
                validator: (value) {
                  if (value!.isEmpty) return 'Required';
                  final regex = RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$');
                  if (!regex.hasMatch(value)) return 'Invalid format (DD/MM/YYYY)';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location *'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description *'),
                maxLines: 4,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price (UGX) *'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Required';
                  if (double.tryParse(value) == null && value.toLowerCase() != 'free') {
                    return 'Enter a valid number or "free"';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : widget.event.imageUrl != null
                          ? Image.network(widget.event.imageUrl!, fit: BoxFit.cover)
                          : const Center(child: Text('Tap to select image')),
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _updateEvent,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: const Color.fromARGB(255, 25, 25, 95),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Update Event'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}

class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({Key? key}) : super(key: key);

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  List<Event> organizerEvents = [];
  bool _isLoading = true;
  String? organizerId;
  bool _hasAccess = false;
  final BookingService _bookingService = BookingService();

  @override
  void initState() {
    super.initState();
    _initializeOrganizer();
  }

  DateTime parseEventDate(String input) {
    try {
      final parts = input.split('/');
      if (parts.length != 3) {
        print('Invalid date format: $input');
        return DateTime(1900);
      }
      final day = int.tryParse(parts[0]) ?? 1;
      final month = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? 1900;
      return DateTime(year, month, day);
    } catch (e) {
      print("Date parse error for '$input': $e");
      return DateTime(1900);
    }
  }

  Future<void> _initializeOrganizer() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    organizerId = authProvider.user?.uid;

    if (organizerId != null) {
      print('Initializing organizer with ID: $organizerId');
      await _checkAccessAndFetchEvents();
    } else {
      print('No organizer ID found, denying access');
      setState(() {
        _isLoading = false;
        _hasAccess = false;
      });
    }
  }

  Future<void> _checkAccessAndFetchEvents() async {
    if (organizerId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('Fetching events for organizerId: $organizerId');
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('organizerId', isEqualTo: organizerId)
          .get();

      print('Found ${snapshot.docs.length} events');
      snapshot.docs.forEach((doc) => print('Event data: ${doc.data()}'));

      setState(() {
        organizerEvents = snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
        organizerEvents.sort((a, b) => parseEventDate(a.date).compareTo(parseEventDate(b.date)));
        _hasAccess = true;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() {
        _isLoading = false;
        _hasAccess = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading events: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<Booking>> _getEventBookings(String eventId) async {
    try {
      final bookings = await _bookingService.getEventBookings(eventId);
      return bookings;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching bookings: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return [];
    }
  }

  Future<Map<String, dynamic>> _getOverallStats() async {
    try {
      return await _bookingService.getOverallStats(organizerEvents);
    } catch (e) {
      print('Error getting overall stats: $e');
      return {
        'revenue': 0.0,
        'bookings': 0,
        'paidBookings': 0,
      };
    }
  }

  Future<void> _deleteEvent(Event event) async {
    try {
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Event'),
          content: Text('Are you sure you want to delete "${event.title}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        QuerySnapshot bookingsSnapshot = await FirebaseFirestore.instance
            .collection('bookings')
            .where('eventId', isEqualTo: event.id)
            .get();
        for (var doc in bookingsSnapshot.docs) {
          await doc.reference.delete();
        }

        await FirebaseFirestore.instance
            .collection('events')
            .doc(event.id)
            .delete();

        if (event.imageUrl != null) {
          try {
            await FirebaseStorage.instance
                .ref()
                .child('events')
                .child('${event.id}.jpg')
                .delete();
          } catch (e) {
            print('Error deleting image: $e');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        await _checkAccessAndFetchEvents();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting event: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'concert':
      case 'festival':
        return Icons.music_note;
      case 'conference':
        return Icons.computer;
      case 'workshop':
        return Icons.build;
      case 'sports':
        return Icons.sports;
      case 'networking':
        return Icons.group;
      case 'exhibition':
        return Icons.museum;
      case 'theater':
        return Icons.theater_comedy;
      case 'comedy':
        return Icons.sentiment_very_satisfied;
      default:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Event Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 25, 25, 95),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _checkAccessAndFetchEvents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_hasAccess
              ? _buildNoAccessState()
              : organizerEvents.isEmpty
                  ? _buildEmptyState()
                  : _buildEventsList(),
      floatingActionButton: _hasAccess
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEventScreen(
                      onEventAdded: _checkAccessAndFetchEvents,
                    ),
                  ),
                );
              },
              backgroundColor: const Color.fromARGB(255, 25, 25, 95),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildNoAccessState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'Access Restricted',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This section is only available to event organizers',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Create your first event to access management features',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 25, 25, 95),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'No Events Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Create your first event to get started',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEventScreen(
                    onEventAdded: _checkAccessAndFetchEvents,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Event'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 25, 25, 95),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Events',
                  organizerEvents.length.toString(),
                  Icons.event,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _getOverallStats(),
                  builder: (context, snapshot) {
                    final stats = snapshot.data ?? {'revenue': 0.0, 'bookings': 0};
                    return _buildSummaryCard(
                      'Total Revenue',
                      'UGX ${stats['revenue'].toStringAsFixed(2)}',
                      Icons.attach_money,
                      Colors.green,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: organizerEvents.length,
            itemBuilder: (context, index) {
              final event = organizerEvents[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventDetailsScreen(event: event),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 25, 25, 95).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _getCategoryIcon(event.category),
                                color: const Color.fromARGB(255, 25, 25, 95),
                                size: 24,
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    event.category,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton(
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _deleteEvent(event);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete Event'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<List<Booking>>(
                          future: _getEventBookings(event.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const LinearProgressIndicator();
                            }
                            if (snapshot.hasError) {
                              return Text(
                                'Error loading bookings',
                                style: TextStyle(color: Colors.red, fontSize: 12),
                              );
                            }
                            final bookings = snapshot.data ?? [];
                            final paidBookings = bookings.where((b) => b.paid).length;
                            final totalRevenue =
                                bookings.where((b) => b.paid).fold(0.0, (sum, booking) => sum + booking.total);
                            final bookedCount = bookings.length;
                            final maxslots = event.maxslots ?? 0;
                            final slotsRemaining = maxslots - bookedCount;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        bookings.length.toString(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text('Bookings'),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        paidBookings.toString(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const Text('Paid'),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        'UGX ${totalRevenue.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      const Text('Revenue'),
                                    ],
                                  ),
                                  if (maxslots > 0)
                                    Column(
                                      children: [
                                        Text(
                                          slotsRemaining > 0 ? '$slotsRemaining' : 'Full',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: slotsRemaining > 0 ? Colors.orange : Colors.red,
                                          ),
                                        ),
                                        const Text('Slots Left'),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              event.date,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 20),
                            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                event.location,
                                style: TextStyle(color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildActionButton(
                              icon: Icons.people,
                              label: 'Attendees',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AttendeesScreen(event: event),
                                  ),
                                );
                              },
                            ),
                            _buildActionButton(
                              icon: Icons.edit,
                              label: 'Edit',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditEventScreen(
                                      event: event,
                                      onEventUpdated: _checkAccessAndFetchEvents,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildActionButton(
                              icon: Icons.analytics,
                              label: 'Analytics',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EventAnalyticsScreen(event: event),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 25, 25, 95).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color.fromARGB(255, 25, 25, 95)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: const Color.fromARGB(255, 25, 25, 95),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventDetailsScreen extends StatelessWidget {
  final Event event;

  const EventDetailsScreen({Key? key, required this.event}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(event.title),
        backgroundColor: const Color.fromARGB(255, 25, 25, 95),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.imageUrl != null)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(event.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              event.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              event.category,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  event.date,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.location,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              event.price == 0.0 ? 'Free Entry' : 'Price: UGX ${event.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              event.description,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendeesScreen extends StatelessWidget {
  final Event event;

  const AttendeesScreen({Key? key, required this.event}) : super(key: key);

  Future<List<Booking>> _getEventBookings() async {
    final bookingService = BookingService();
    return await bookingService.getEventBookings(event.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${event.title} - Attendees'),
        backgroundColor: const Color.fromARGB(255, 25, 25, 95),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Booking>>(
        future: _getEventBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final bookings = snapshot.data ?? [];
          if (bookings.isEmpty) {
            return const Center(child: Text('No attendees yet'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              String formattedDate = 'Unknown';
              if (booking.bookingDate != null) {
                if (booking.bookingDate is Timestamp) {
                  formattedDate = DateFormat('dd/MM/yyyy HH:mm')
                      .format((booking.bookingDate as Timestamp).toDate());
                } else if (booking.bookingDate is DateTime) {
                  formattedDate = DateFormat('dd/MM/yyyy HH:mm')
                      .format(booking.bookingDate as DateTime);
                }
              }
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${booking.firstName} ${booking.lastName}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.email),
                      Text('Paid: ${booking.paid ? "Yes" : "No"}'),
                      Text('Amount: UGX ${booking.total.toStringAsFixed(2)}'),
                      Text('Booked: $formattedDate'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class EventAnalyticsScreen extends StatelessWidget {
  final Event event;

  const EventAnalyticsScreen({Key? key, required this.event}) : super(key: key);

  Future<Map<String, dynamic>> _getEventStats() async {
    final bookingService = BookingService();
    final bookings = await bookingService.getEventBookings(event.id);
    final paidBookings = bookings.where((b) => b.paid).length;
    final totalRevenue = bookings.where((b) => b.paid).fold(0.0, (sum, booking) => sum + booking.total);
    return {
      'totalBookings': bookings.length,
      'paidBookings': paidBookings,
      'totalRevenue': totalRevenue,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${event.title} - Analytics'),
        backgroundColor: const Color.fromARGB(255, 25, 25, 95),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getEventStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final stats = snapshot.data ?? {'totalBookings': 0, 'paidBookings': 0, 'totalRevenue': 0.0};
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatCard(
                  'Total Bookings',
                  stats['totalBookings'].toString(),
                  Icons.people,
                  Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildStatCard(
                  'Paid Bookings',
                  stats['paidBookings'].toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                const SizedBox(height: 16),
                _buildStatCard(
                  'Total Revenue',
                  'UGX ${stats['totalRevenue'].toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.purple,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
