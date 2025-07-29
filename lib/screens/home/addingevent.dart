import 'package:event_locator_app/models/event.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../providers/auth_provider.dart';
import '../map/location_picker_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:file_picker/file_picker.dart';

class AddEventDialog extends StatefulWidget {
  final Function(Event) onAddEvent;

  const AddEventDialog({Key? key, required this.onAddEvent}) : super(key: key);

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxslotsController = TextEditingController();
  String _selectedCategory = 'Other';
  File? _selectedImage;
  Uint8List? _webImage;
  bool _isUploading = false;

  // Document verification fields
  File? _verificationDocument;
  Uint8List? _webVerificationDocument;
  String? _verificationDocumentName;
  String _selectedDocumentType = 'Business License';
  bool _requiresVerification = false;

  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  double? _latitude;
  double? _longitude;

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
    'Other',
  ];

  final List<String> _documentTypes = [
    'Business License',
    'Event Permit',
    'Insurance Certificate',
    'Tax Certificate',
    'Organization Registration',
    'Venue Agreement',
    'Professional Certificate',
    'Government ID',
    'Other Official Document',
  ];

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _webImage = bytes;
            _selectedImage = null;
          });
        } else {
          setState(() {
            _selectedImage = File(image.path);
            _webImage = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _webImage = bytes;
            _selectedImage = null;
          });
        } else {
          setState(() {
            _selectedImage = File(image.path);
            _webImage = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickVerificationDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result != null) {
        PlatformFile file = result.files.first;

        if (kIsWeb) {
          setState(() {
            _webVerificationDocument = file.bytes;
            _verificationDocumentName = file.name;
            _verificationDocument = null;
          });
        } else {
          setState(() {
            _verificationDocument = File(file.path!);
            _verificationDocumentName = file.name;
            _webVerificationDocument = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImageToFirebase() async {
    try {
      setState(() {
        _isUploading = true;
      });

      String fileName =
          'events/${DateTime.now().millisecondsSinceEpoch}_${_titleController.text.replaceAll(' ', '_').replaceAll(RegExp(r'[^\w\s-]'), '')}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask;
      if (kIsWeb && _webImage != null) {
        uploadTask = storageRef.putData(
          _webImage!,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'uploaded_by': 'flutter_app',
              'upload_time': DateTime.now().toIso8601String(),
            },
          ),
        );
      } else if (_selectedImage != null) {
        uploadTask = storageRef.putFile(
          _selectedImage!,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'uploaded_by': 'flutter_app',
              'upload_time': DateTime.now().toIso8601String(),
            },
          ),
        );
      } else {
        return null;
      }

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      print('Image uploaded successfully. URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<String?> _uploadVerificationDocumentToFirebase() async {
    try {
      if (_verificationDocument == null && _webVerificationDocument == null) {
        return null;
      }

      String fileName =
          'verification_documents/${DateTime.now().millisecondsSinceEpoch}_${_verificationDocumentName ?? 'document'}';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      String contentType = _getContentType(_verificationDocumentName ?? '');

      UploadTask uploadTask;
      if (kIsWeb && _webVerificationDocument != null) {
        uploadTask = storageRef.putData(
          _webVerificationDocument!,
          SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'uploaded_by': 'flutter_app',
              'upload_time': DateTime.now().toIso8601String(),
              'document_type': _selectedDocumentType,
              'original_name': _verificationDocumentName ?? 'document',
            },
          ),
        );
      } else if (_verificationDocument != null) {
        uploadTask = storageRef.putFile(
          _verificationDocument!,
          SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'uploaded_by': 'flutter_app',
              'upload_time': DateTime.now().toIso8601String(),
              'document_type': _selectedDocumentType,
              'original_name': _verificationDocumentName ?? 'document',
            },
          ),
        );
      } else {
        return null;
      }

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      print('Verification document uploaded successfully. URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading verification document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading verification document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  String _getContentType(String fileName) {
    String extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _saveEventToFirestore(Event event) async {
    try {
      print('Saving event to Firestore: ${event.toFirestore()}');
      await _firestore
          .collection('events')
          .doc(event.id)
          .set(event.toFirestore());
      print(
        'Event saved to Firestore successfully: ${event.id}, organizerId: ${event.organizerId}, isVerified: ${event.isVerified}, verificationStatus: ${event.verificationStatus}',
      );
      // Verify the saved data
      final savedDoc = await _firestore
          .collection('events')
          .doc(event.id)
          .get();
      final savedData = savedDoc.data();
      print('Retrieved saved event from Firestore: $savedData');
    } catch (e) {
      print('Error saving event to Firestore: $e');
      throw e;
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _takePicture();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (kIsWeb && _webImage != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _webImage!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _webImage = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    } else if (_selectedImage != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _selectedImage!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedImage = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    } else {
      return InkWell(
        onTap: _showImageSourceDialog,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 10),
            Text(
              'Tap to add event image',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              kIsWeb ? 'Gallery' : 'Gallery or Camera',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildVerificationSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user, color: Colors.green[600], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Event Verification',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Upload a verification document to establish credibility for your event. This helps attendees trust your event.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _requiresVerification,
                  onChanged: (value) {
                    setState(() {
                      _requiresVerification = value ?? false;
                    });
                  },
                ),
                const Expanded(
                  child: Text(
                    'I want to verify this event with official documents',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            if (_requiresVerification) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedDocumentType,
                decoration: const InputDecoration(
                  labelText: 'Document Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                items: _documentTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDocumentType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child:
                    _verificationDocument != null ||
                        _webVerificationDocument != null
                    ? Row(
                        children: [
                          Icon(
                            _getDocumentIcon(_verificationDocumentName ?? ''),
                            color: Colors.blue,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _verificationDocumentName ?? 'Document',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _selectedDocumentType,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _verificationDocument = null;
                                _webVerificationDocument = null;
                                _verificationDocumentName = null;
                              });
                            },
                            icon: const Icon(Icons.close, color: Colors.red),
                          ),
                        ],
                      )
                    : InkWell(
                        onTap: _pickVerificationDocument,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.upload_file,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload Verification Document',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'PDF, DOC, DOCX, JPG, PNG (Max 10MB)',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your document will be reviewed by our team. Verified events get a trust badge.',
                        style: TextStyle(color: Colors.blue[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getDocumentIcon(String fileName) {
    String extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 700, maxWidth: 600),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.add_circle,
                      color: Color.fromARGB(255, 25, 25, 95),
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Add New Event',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _buildImagePreview(),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Event Title *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter event title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a price';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _maxslotsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Maximum/Capacity Slots',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter max slots';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 15),
                TextFormField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date *',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter event date';
                    }
                    return null;
                  },
                  onTap: () async {
                    FocusScope.of(context).requestFocus(FocusNode());
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      _dateController.text =
                          '${date.day}/${date.month}/${date.year}';
                    }
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter event location';
                    }
                    return null;
                  },
                  onTap: () async {
                    final result = await Navigator.push<Map<String, dynamic>?>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LocationPickerScreen(),
                      ),
                    );
                    if (result != null) {
                      final LatLng location = result['location'];
                      final String locationName =
                          result['locationName'] ?? 'Unknown location';
                      setState(() {
                        _latitude = location.latitude;
                        _longitude = location.longitude;
                        _locationController.text = locationName;
                      });
                    }
                  },
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 20),
                _buildVerificationSection(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isUploading
                            ? null
                            : () => Navigator.pop(context),
                        child: Text('Cancel'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _addEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 25, 25, 95),
                          foregroundColor: Colors.white,
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Add Event'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addEvent() async {
    if (_formKey.currentState!.validate()) {
      // Validate verification document if required
      if (_requiresVerification &&
          _verificationDocument == null &&
          _webVerificationDocument == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please upload a verification document or uncheck the verification option.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final organizerId = authProvider.user?.uid;
        if (organizerId == null) {
          throw Exception('User not authenticated');
        }
        print('Creating event with organizerId: $organizerId');

        String? imageUrl;
        if (_selectedImage != null || _webImage != null) {
          imageUrl = await _uploadImageToFirebase();
          if (imageUrl == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to upload image. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }

        String? verificationDocumentUrl;
        if (_requiresVerification &&
            (_verificationDocument != null ||
                _webVerificationDocument != null)) {
          verificationDocumentUrl =
              await _uploadVerificationDocumentToFirebase();
          if (verificationDocumentUrl == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Failed to upload verification document. Please try again.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }

        final event = Event(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          date: _dateController.text.trim(),
          location: _locationController.text.trim(),
          latitude: _latitude ?? 0.0,
          longitude: _longitude ?? 0.0,
          category: _selectedCategory,
          imageUrl: imageUrl,
          organizerId: organizerId,
          
          
          
          price: double.tryParse(_priceController.text) ?? 0.0,
          maxslots: int.tryParse(_maxslotsController.text) ?? 0,
          verificationDocumentUrl: verificationDocumentUrl,
          verificationDocumentType: _requiresVerification
              ? _selectedDocumentType
              : null,
          verificationStatus: _requiresVerification ? 'pending' : null,
          requiresVerification: _requiresVerification,
          verificationSubmittedAt: _requiresVerification
              ? DateTime.now().toIso8601String()
              : null,
          isVerified:
              false, // Explicitly set to false to ensure initial unverified state
          status:
              'unverified', // Explicitly set to align with Event model default
        );

        print('Event created: ${event.toFirestore()}');
        await _saveEventToFirestore(event);
        print(
          'Calling onAddEvent with event: id=${event.id}, isVerified=${event.isVerified}, verificationStatus=${event.verificationStatus}',
        );
        widget.onAddEvent(event);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _requiresVerification
                    ? 'Event added successfully! Your verification document is being reviewed.'
                    : 'Event added successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        //print('Error adding event: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding event: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _maxslotsController.dispose();
    super.dispose();
  }
}
