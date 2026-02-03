import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../services/plastic_service.dart';

// Import from config instead of hardcoding
import '../core/gemini_config.dart';

const String _NEW_GEMINI_KEY = GeminiConfig.apiKey;
const String _MODEL_NAME = "gemini-2.5-flash-preview-09-2025";

class AddPlasticScreen extends StatefulWidget {
  const AddPlasticScreen({super.key});

  @override
  State<AddPlasticScreen> createState() => _AddPlasticScreenState();
}

class _AddPlasticScreenState extends State<AddPlasticScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();

  File? _imageFile;
  XFile? _pickedXFile;
  String _selectedType = 'Bottle';
  bool _isLoading = false;
  int _estimatedPoints = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // Card helper to match the EcoCycle project theme
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

  // Reverse geocoding to show street/city name instead of coordinates
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    _locationController.text = "Locating...";
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18';
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'EcoCycle/1.0'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _locationController.text = data['display_name'] ??
              "${position.latitude}, ${position.longitude}";
        });
      }
    } catch (e) {
      _showErrorSnackBar("Location Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Strict AI detection: Category, Name, and Description generation
  Future<void> _detectPlastic(XFile xFile) async {
    setState(() {
      _isLoading = true;
      _titleController.text = 'AI is analyzing...';
      _descController.text = '';
      _estimatedPoints = 0;
    });

    // Validate API Key before making request
    if (_NEW_GEMINI_KEY.isEmpty || _NEW_GEMINI_KEY == 'YOUR_API_KEY_HERE') {
      _showErrorSnackBar(
          "Error: Gemini API key not configured. Please update lib/core/gemini_config.dart");
      setState(() => _isLoading = false);
      return;
    }

    try {
      final Uint8List bytes = await xFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final prompt = """
        Analyze this image strictly for plastic waste management.
        1. If the item is NOT plastic (food, electronics, metal, paper), return category "NON_PLASTIC".
        2. If it IS plastic, determine the category: 'Bottle', 'Bag', 'Cover', or 'Other'.
        3. Provide a clear Item Name and a 2-sentence description of the material.
        
        Respond ONLY in JSON format: 
        {"item_name": "name", "category": "Bottle/Bag/Cover/Other/NON_PLASTIC", "description": "desc"}
      """;

      final url =
          "https://generativelanguage.googleapis.com/v1beta/models/$_MODEL_NAME:generateContent?key=$_NEW_GEMINI_KEY";

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt},
                {
                  "inlineData": {"mimeType": "image/jpeg", "data": base64Image}
                }
              ]
            }
          ],
          "generationConfig": {"responseMimeType": "application/json"}
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResult =
            jsonDecode(data['candidates'][0]['content']['parts'][0]['text']);

        // Restriction logic: Only allow plastic items
        if (aiResult['category'] == "NON_PLASTIC") {
          setState(() {
            _titleController.clear();
            _descController.clear();
            _imageFile = null;
          });
          _showErrorSnackBar("Rejected: Only plastic items are allowed.");
        } else {
          setState(() {
            _titleController.text = aiResult['item_name'];
            _descController.text = aiResult['description'];
            _selectedType = aiResult['category']; // Auto-selects the dropdown
            _estimatedPoints = (_selectedType == 'Bottle') ? 40 : 20;
          });
        }
      } else {
        debugPrint("API Response: ${response.statusCode}");
        debugPrint("Response Body: ${response.body}");
        String errorMsg = "API Error: ${response.statusCode}";
        if (response.statusCode == 404) {
          errorMsg =
              "API Error 404: Invalid API key or endpoint. Please update your Gemini API key.";
        } else if (response.statusCode == 401) {
          errorMsg =
              "API Error 401: Unauthorized. Check your API key validity.";
        } else if (response.statusCode == 429) {
          errorMsg = "API Error 429: Rate limit exceeded. Try again later.";
        }
        _showErrorSnackBar(errorMsg);
      }
    } catch (e) {
      debugPrint("AI Detection Error: $e");
      _showErrorSnackBar(
          "Analysis failed: Check your internet connection or API configuration.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        _pickedXFile = pickedFile;
        _imageFile = File(pickedFile.path);
      });
      await _detectPlastic(pickedFile);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _imageFile == null) return;

    setState(() => _isLoading = true);
    try {
      // CRITICAL FIX: Force session refresh immediately before trying to get user ID
      // This attempts to discard the stale token and pick up a valid one.
      await AppSupabase.client.auth.refreshSession();

      final user = AppSupabase.client.auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('Error: Session expired. Please log in again.');
        return;
      }
      final bytes = await _pickedXFile!.readAsBytes();
      final mimeType = lookupMimeType(_pickedXFile!.path) ?? 'image/jpeg';

      // 1. Upload File using bytes and mimeType
      String? imageUrl;
      try {
        imageUrl = await PlasticService().uploadImage(bytes, mimeType);
      } on StorageException catch (e) {
        throw Exception(
            'File Upload Failed: Storage Error (${e.statusCode}). Check Supabase bucket setup/policy.');
      } catch (e) {
        throw Exception('Failed to upload image: ${e.toString()}');
      }

      // 2. Database Insertion
      try {
        await PlasticService().insertPlastic(
          userId: user!.id,
          plasticType: _selectedType,
          itemName: _titleController.text,
          description: _descController.text,
          location: _locationController.text,
          imageUrl: imageUrl,
        );
      } on PostgrestException catch (e) {
        debugPrint('❌ POSTGREST (DB) ERROR: ${e.message}');
        throw Exception(
            'Database Error: ${e.message}. (Check RLS/Foreign Keys)');
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('plastic_waste_reported'))));
      }
    } catch (e) {
      _showErrorSnackBar("Submission Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('add_plastic_waste')),
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
              // ----------------------------------
              // 1. Image Capture/Detection Area
              // ----------------------------------
              Text('Step 1: Capture & Analyze',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'Take a clear photo of your item to automatically detect its type and material composition.',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),

              _inputCard(
                child: GestureDetector(
                  onTap: _isLoading ? null : _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: _imageFile == null
                          ? Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                      image: _imageFile != null
                          ? DecorationImage(
                              image: FileImage(_imageFile!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _imageFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                size: 56,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.6),
                              ),
                              const SizedBox(height: 12),
                              const Text('Tap to open camera & analyze',
                                  style: TextStyle(fontSize: 16)),
                            ],
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  onPressed: () =>
                                      setState(() => _imageFile = null),
                                  icon: const Icon(Icons.close),
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        Colors.black.withOpacity(0.5),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              if (_isLoading)
                                Container(
                                  color: Colors.black.withOpacity(0.5),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                            color: Colors.white),
                                        SizedBox(height: 10),
                                        Text('Analyzing...',
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),

              // ----------------------------------
              // 2. AI Detected Details
              // ----------------------------------
              const SizedBox(height: 16),
              Text('Step 2: Review Item Details',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'The details below were automatically detected. You may adjust them if needed.',
                  style: TextStyle(color: Colors.grey)),
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
                      controller: _descController,
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

                    // Plastic Category Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      items: ['Bottle', 'Bag', 'Cover', 'Other']
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: _isLoading
                          ? null
                          : (v) => setState(() => _selectedType = v!),
                      decoration: const InputDecoration(
                          labelText: 'Plastic Category',
                          prefixIcon: Icon(Icons.category_outlined),
                          border: OutlineInputBorder()),
                    ),

                    const SizedBox(
                        height: 12), // Spacer before category display

                    // Detected Category Display
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
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
                              'Detected Category: $_selectedType',
                              style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12), // Spacer before points display

                    // Estimated Points Display
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
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
                            style: TextStyle(
                                color: Colors.teal.shade800,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ----------------------------------
              // 3. Location Input
              // ----------------------------------
              const SizedBox(height: 16),
              Text('Step 3: Confirm Pickup Location',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'Provide the exact address where the plastic waste will be available for pickup.',
                  style: TextStyle(color: Colors.grey)),
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

              // ----------------------------------
              // 4. Submit Button
              // ----------------------------------
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  // Disable if loading OR if no image has been picked
                  onPressed: _isLoading || _imageFile == null ? null : _submit,
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
                    child: Text(
                        _isLoading ? 'Processing...' : 'Submit Plastic Waste',
                        style: const TextStyle(fontSize: 16)),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
