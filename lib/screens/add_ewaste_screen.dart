import 'dart:io';
import 'dart:convert';
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart'; 
import 'package:http/http.dart' as http; 
import 'package:mime/mime.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 
import '../models/ewaste_category.dart';
import '../services/ewaste_service.dart';

// ---------------------------------------------------------------------------------------
// ⭐ ACTION REQUIRED: PASTE YOUR GOOGLE GEMINI API KEY HERE ⭐
// ---------------------------------------------------------------------------------------
const String _GEMINI_API_KEY = "AIzaSyC8bEq71V1bg0ouvz3ugdaTTuKefLPLRs4"; 
// ---------------------------------------------------------------------------------------

const String _GEMINI_MODEL = "gemini-2.5-flash-preview-09-2025";
const String _REVERSE_GEOCODING_URL = 'https://nominatim.openstreetmap.org/reverse?format=json&lat={LAT}&lon={LON}&zoom=18&addressdetails=1';

class AddEwasteScreen extends StatefulWidget {
  const AddEwasteScreen({super.key});

  @override
  State<AddEwasteScreen> createState() => _AddEwasteScreenState();
}

class _AddEwasteScreenState extends State<AddEwasteScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedCategoryId = 'tv'; 
  File? _imageFile; // For display purposes only
  XFile? _pickedXFile; // Holds the image source file
  bool _isLoading = false;
  final _ewasteService = EwasteService();
  int _estimatedPoints = 0; // NEW: State variable for estimated points

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  // Helper widget for professional card styling
  Widget _inputCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }
  
  // NEW FUNCTION: Calculates and updates points based on the category ID
  void _updateEstimatedPoints(String categoryId) {
    if (categoryId.toUpperCase() == 'NON_EWASTE') {
      setState(() => _estimatedPoints = 0);
      return;
    }
    
    // Calls the now-public method in EwasteService
    try {
        final points = _ewasteService.calculatePointsForCategory(categoryId); 
        setState(() => _estimatedPoints = points);
    } catch (_) {
        setState(() => _estimatedPoints = 50); // Default low estimate if calculation fails
    }
  }

  // ------------------------------------------
  // Geolocation Logic
  // ------------------------------------------

  Future<void> _getCurrentLocation() async {
    if (_isLoading) return; 
    
    setState(() {
      _isLoading = true;
      _locationController.text = 'Fetching location...';
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final lat = position.latitude;
      final lon = position.longitude;

      final url = _REVERSE_GEOCODING_URL
          .replaceFirst('{LAT}', lat.toString())
          .replaceFirst('{LON}', lon.toString());

      final response = await http.get(Uri.parse(url), 
        headers: {'User-Agent': 'EcoCycleApp/1.0'} 
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['display_name'] as String? ?? 'Address not found';
        _locationController.text = address;
      } else {
        throw Exception('Failed to get address: ${response.statusCode}');
      }

    } catch (e) {
      debugPrint('Geolocation Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching location: ${e.toString()}')),
        );
        _locationController.text = '';
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------------------------------------
  // Image Detection Logic (Gemini API)
  // ------------------------------------------

  Future<void> _detectItem(XFile xFile) async {
    setState(() {
      _isLoading = true;
      _titleController.text = 'Analyzing image...';
      _descriptionController.text = '';
      _estimatedPoints = 0; // Reset points
    });

    try {
      if (_GEMINI_API_KEY.isEmpty) {
        throw Exception('Gemini API Key is not set. Please update the key in the code.');
      }
      
      final Uint8List bytes = await xFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = lookupMimeType(xFile.path) ?? 'image/jpeg';
      
      // FIX 1: Enhanced prompt to strictly enforce e-waste check
      final validCategories = ewasteCategories.map((c) => c.id).toList();
      validCategories.add("NON_EWASTE"); 
      
      final userQuery = """
      Analyze this image. 
      1. Determine if the item is E-WASTE (electronic waste). 
      2. If it is E-WASTE, identify the item and suggest the best matching 'category_id' from this list: ${ewasteCategories.map((c) => c.id).join(', ')}.
      3. If the item is NOT E-WASTE (e.g., general trash, furniture, food, or apparel), you MUST return "NON_EWASTE" as the 'category_id'.
      
      Respond ONLY with a JSON object. The JSON structure is: 
      {"item_name":"[Concise Name]", "description":"[2-3 sentence description and material notes]", "category_id":"[Suggested ID or NON_EWASTE]"}
      """;
      
      final apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/$_GEMINI_MODEL:generateContent?key=$_GEMINI_API_KEY";
      
      final payload = {
        "contents": [
          {
            "parts": [
              {"text": userQuery},
              {
                "inlineData": {
                  "mimeType": mimeType,
                  "data": base64Image
                }
              }
            ]
          }
        ],
        "generationConfig": { 
          "responseMimeType": "application/json",
          "responseSchema": {
            "type": "OBJECT",
            "properties": {
              "item_name": {"type": "STRING"},
              "description": {"type": "STRING"},
              "category_id": {"type": "STRING"}
            },
            "propertyOrdering": ["item_name", "description", "category_id"]
          }
        }
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final jsonString = result['candidates']?[0]?['content']?['parts']?[0]?['text'];
        final aiData = jsonDecode(jsonString);

        if (aiData != null) {
          final detectedCategoryId = aiData['category_id']?.toString() ?? 'other';
          
          if (detectedCategoryId.toUpperCase() == 'NON_EWASTE') {
             // Block submission if it's not e-waste
             setState(() {
                _titleController.text = aiData['item_name'] ?? 'Not Electronic Waste';
                _descriptionController.text = aiData['description'] ?? 'Item rejected.';
                _imageFile = null; // Clear image to prevent accidental submission
                _selectedCategoryId = 'tv'; // Reset to a default valid category for UI consistency
                _estimatedPoints = 0; // Ensure points are zeroed
             });
             throw Exception("The detected item is not classified as electronic waste. Please try again with a valid electronic item.");
          }

          final categoryExists = ewasteCategories.any((c) => c.id == detectedCategoryId);
          
          setState(() {
            _titleController.text = aiData['item_name'] ?? 'Unidentified E-Waste';
            _descriptionController.text = aiData['description'] ?? 'Detailed description needed.';
            _selectedCategoryId = categoryExists ? detectedCategoryId : 'other';
            _updateEstimatedPoints(_selectedCategoryId); // NEW: Update estimated points after detection
          });

        } else {
          throw Exception('AI analysis failed to return expected JSON.');
        }

      } else {
        throw Exception('Gemini API failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('AI Detection Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Detection Error: ${e.toString()}')),
        );
        _titleController.text = '';
        _descriptionController.text = '';
        setState(() => _estimatedPoints = 0); // Reset points on failure
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // ------------------------------------------
  // Image Picking Logic 
  // ------------------------------------------

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _pickedXFile = pickedFile;
        _imageFile = File(pickedFile.path); 
      });
      await _detectItem(pickedFile);
    }
  }

  // ------------------------------------------
  // Submission Logic (Final Fix: Session Refresh)
  // ------------------------------------------

  Future<void> _submitItem() async {
    // CRITICAL FIX 1: Force session refresh immediately before trying to get user ID
    // This attempts to discard the stale token and pick up a valid one.
    await _ewasteService.supabase.auth.refreshSession();

    final user = _ewasteService.supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Session expired. Please log in again.')),
      );
      return;
    }
    final userId = user.id;

    if (!_formKey.currentState!.validate() || _pickedXFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('please_fill_all_fields'))),
      );
      return;
    }
    
    if (_selectedCategoryId.toUpperCase() == 'NON_EWASTE') {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submission rejected: Item is not classified as electronic waste.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    String? imageUrl;

    try {
      // 1. Prepare platform-agnostic data for upload
      final fileBytes = await _pickedXFile!.readAsBytes();
      final mimeType = lookupMimeType(_pickedXFile!.path) ?? 'image/jpeg';
      
      // 2. Upload File using bytes and mimeType
      try {
        imageUrl = await _ewasteService.uploadImage(fileBytes, mimeType);
      } on StorageException catch (e) {
        throw Exception('File Upload Failed: Storage Error (${e.statusCode}). Check Supabase bucket setup/policy.');
      } catch (e) {
        throw Exception('Failed to upload image: ${e.toString()}');
      }

      // 3. Database Insertion
      try {
        await _ewasteService.insertEwaste(
          userId: userId, // Use the reliably fetched user ID
          categoryId: _selectedCategoryId,
          itemName: _titleController.text,
          description: _descriptionController.text,
          location: _locationController.text,
          imageUrl: imageUrl,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('item_added_successfully'))),
          );
        }
      } on PostgrestException catch (e) {
        debugPrint('❌ POSTGREST (DB) ERROR: ${e.message}');
        throw Exception('Database Error: ${e.message}. (Check RLS/Foreign Keys)');
      }


    } catch (e) {
      // Show the most relevant error message
      String errorMessage = e.toString().contains("Exception:") 
          ? e.toString().split("Exception:")[1].trim()
          : "Submission failed due to an unexpected error.";
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $errorMessage')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------------------------------------
  // Build Method (Modern UI)
  // ------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Determine which category name to show for the green box
    String currentCategoryName = 'Awaiting Detection...';
    if (_imageFile == null && !_isLoading) {
       currentCategoryName = 'Capture Photo to Begin';
    } else {
        try {
          currentCategoryName = ewasteCategories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => ewasteCategories.first).name;
        } catch (_) {
          currentCategoryName = 'Unknown Category';
        }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add E-Waste Item'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient:
                LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)]),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------------------
              // 1. Image Capture/Detection Area
              // ------------------------------------------
              Text('Step 1: Capture & Analyze',
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Take a clear photo of your item to automatically detect its type and material composition.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              
              _inputCard(
                child: GestureDetector(
                  onTap: _isLoading ? null : _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: _imageFile == null ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                      image: _imageFile != null
                          ? DecorationImage(
                              image: FileImage(_imageFile!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _imageFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                size: 56,
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                              ),
                              const SizedBox(height: 12),
                              const Text('Tap to open camera & analyze', style: TextStyle(fontSize: 16)),
                            ],
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  onPressed: () => setState(() => _imageFile = null),
                                  icon: const Icon(Icons.close),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black.withOpacity(0.5),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              if (_isLoading)
                                Container(
                                  color: Colors.black.withOpacity(0.5),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(color: Colors.white),
                                        SizedBox(height: 10),
                                        Text('Analyzing...', style: TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),

              // ------------------------------------------
              // 2. AI Detected Details
              // ------------------------------------------
              const SizedBox(height: 16),
              Text('Step 2: Review Item Details',
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('The details below were automatically detected. You may adjust them if needed.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              
              _inputCard(
                child: Column(
                  children: [
                    // Item Name
                    TextFormField(
                      controller: _titleController,
                      readOnly: _isLoading, 
                      decoration: InputDecoration(
                        labelText: 'Item Title',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.devices_other),
                      ),
                      validator: (value) =>
                          value?.isEmpty == true ? tr('required_field') : null,
                    ),
                    const SizedBox(height: 16),

                    // Description/Features
                    TextFormField(
                      controller: _descriptionController,
                      readOnly: _isLoading, 
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description & Materials',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.description),
                      ),
                      validator: (value) =>
                          value?.isEmpty == true ? tr('required_field') : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Detected Category Display
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.category, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Detected Category: $currentCategoryName',
                              style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12), // Spacer before points display

                    // NEW: Estimated Points Display
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stars, color: Colors.teal),
                          const SizedBox(width: 8),
                          Text(
                            // Display message based on state
                            _estimatedPoints > 0 
                              ? 'Estimated EcoPoints: $_estimatedPoints'
                              : (_imageFile != null && !_isLoading) 
                                ? 'Points calculated after detection.' 
                                : 'Take a photo to get estimate.',
                            style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    // END NEW POINTS DISPLAY
                  ],
                ),
              ),
              
              // ------------------------------------------
              // 3. Location Input
              // ------------------------------------------
              const SizedBox(height: 16),
              Text('Step 3: Confirm Pickup Location',
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Provide the exact address where the E-Waste will be available for pickup.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),

              _inputCard(
                child: TextFormField(
                  controller: _locationController,
                  readOnly: _isLoading,
                  decoration: InputDecoration(
                    labelText: 'Pickup Location',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.location_on),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.my_location, color: Colors.blue),
                      onPressed: _isLoading ? null : _getCurrentLocation,
                      tooltip: 'Use Current Location',
                    ),
                  ),
                  validator: (value) =>
                      value?.isEmpty == true ? tr('required_field') : null,
                ),
              ),

              // ------------------------------------------
              // 4. Submit Button
              // ------------------------------------------
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  // Disable if loading OR if no image has been picked
                  onPressed: _isLoading || _imageFile == null ? null : _submitItem,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_isLoading ? 'Processing...' : 'Submit E-Waste', style: const TextStyle(fontSize: 16)),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}