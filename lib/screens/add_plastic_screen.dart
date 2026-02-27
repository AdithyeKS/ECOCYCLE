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

const String _newGeminiKey = GeminiConfig.apiKey;
const String _modelName = "gemini-2.5-flash-preview-09-2025";

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
  int _quantity = 1; // NEW: Quantity state variable

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
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
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
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));

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
      _showErrorSnackBar(
          "Unable to retrieve your current location. Please ensure location services are enabled and try again.");
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
    if (_newGeminiKey.isEmpty || _newGeminiKey == 'YOUR_API_KEY_HERE') {
      _showErrorSnackBar(
          "Error: Gemini API key not configured. Please update lib/core/gemini_config.dart");
      setState(() => _isLoading = false);
      return;
    }

    try {
      final Uint8List bytes = await xFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final prompt = """
      Analyze this image carefully for plastic waste submission.

      FIRST: Check for human presence
      - If ANY human (person, hand, face, or body part) is visible in the image, immediately reject with error.

      SECOND: Check for NON-PLASTIC waste (Strict Rejection)
      - E-WASTE: Headphones, cables, chargers, remote controls, keyboards, mouse, circuit boards, batteries, electronic toys. Even if they have plastic casing, they are E-WASTE.
      - CLOTH: Clothes, fabric bags, towels, textile items.

      THIRD: Plastic validation and analysis
      - If valid plastic, determine the category from this list:
        1. 'Bottle' (Water bottles, soda bottles, PET bottles)
        2. 'Polythene Bags & Covers' (Grocery bags, plastic covers, ziplock bags)
        3. 'Plastic Furniture' (Chairs, stools, tables)
        4. 'Sheets & Films' (Tarps, clear sheets, lamination films)
        5. 'Multi-layer Packaging (Wrappers)' (Chip packets, biscuit wrappers, shiny food packaging)
        6. 'Rigid Plastic (HDPE/PP)' (Toys, buckets, mugs, shampoo bottles, thick containers)
        7. 'Other' (Pens, stationary, or anything that fits none of the above)

      - If the item is NOT plastic (food, metal, paper, wood, etc.), return category "NON_PLASTIC"
      - Provide a clear Item Name and a 2-sentence description.

      RESPONSE RULES:
      - If human detected: Set "error_type": "human_detected", "error_message": "Not acceptable image, human detected"
      - If E-WASTE detected: Set "error_type": "ewaste_detected", "error_message": "This looks like an electronic item (E-Waste)."
      - If CLOTH detected: Set "error_type": "cloth_detected", "error_message": "This looks like a cloth/fabric item."
      - If valid plastic: Provide item details without error fields.
      - If not plastic: Set category to "NON_PLASTIC" without error fields.

      Respond ONLY with a JSON object in one of these formats:

      For VALID plastic:
      {"item_name": "name", "category": "Exact Category Name", "description": "desc"}

      For NON_PLASTIC:
      {"item_name": "item name", "category": "NON_PLASTIC", "description": "description"}

      For HUMAN/E-WASTE/CLOTH/ERROR:
      {"error_type": "type", "error_message": "message"}
      """;

      final url =
          "https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent?key=$_newGeminiKey";

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

        // Check for error responses first
        final errorType = aiResult['error_type']?.toString();
        final errorMessage = aiResult['error_message']?.toString();

        if (errorType != null && errorMessage != null) {
          // Handle rejection cases
          String dialogTitle = 'Image Rejected';
          String userMessage = errorMessage;

          if (errorType == 'human_detected') {
            dialogTitle = 'Invalid Image';
          } else if (errorType == 'ewaste_detected') {
            dialogTitle = 'E-Waste Detected';
            userMessage =
                "This item appears to be E-Waste (Electronic Waste).\nPlease use the 'Add E-Waste' section for this item.";
          } else if (errorType == 'cloth_detected') {
            dialogTitle = 'Cloth Detected';
            userMessage =
                "This item appears to be Cloth/Fabric.\nPlease use the 'Add Clothes' section for this item.";
          }

          _showRejectionDialog(dialogTitle, userMessage);
          setState(() {
            _titleController.clear();
            _descController.clear();
            _imageFile = null; // Clear image to prevent accidental submission
            _pickedXFile = null; // Clear the picked file as well
            _selectedType = 'Bottle'; // Reset to a default valid category
            _estimatedPoints = 0; // Ensure points are zeroed
          });
          return; // Exit early without throwing exception
        }

        // Handle valid responses
        // Restriction logic: Only allow plastic items
        if (aiResult['category'] == "NON_PLASTIC") {
          _showRejectionDialog("Invalid Item Type",
              "This is not a plastic waste item. Please add only plastic waste items here.");
          setState(() {
            _titleController.clear();
            _descController.clear();
            _imageFile = null;
            _pickedXFile = null;
            _selectedType = 'Bottle'; // Reset to default
            _estimatedPoints = 0; // Reset points
          });
        } else {
          setState(() {
            _titleController.text = aiResult['item_name'];
            _descController.text = aiResult['description'];

            // Normalize category to ensure it matches dropdown exactly
            String detectedCategory = aiResult['category'];
            const validCategories = [
              'Bottle',
              'Polythene Bags & Covers',
              'Plastic Furniture',
              'Sheets & Films',
              'Multi-layer Packaging (Wrappers)',
              'Rigid Plastic (HDPE/PP)',
              'Other'
            ];

            if (!validCategories.contains(detectedCategory)) {
              // Fallback if AI hallucinates a new category name
              detectedCategory = 'Other';
            }

            _selectedType = detectedCategory;
            int base = (_selectedType == 'Bottle') ? 40 : 20;
            _estimatedPoints = base + ((_quantity - 1) * 5);
          });
        }
      } else {
        // print(...);
        // print(...);
        String errorMsg =
            "Unable to analyze the image at this time. Please try again later.";
        if (response.statusCode == 404) {
          errorMsg =
              "Unable to process the image. Please check your API configuration and try again.";
        } else if (response.statusCode == 401) {
          errorMsg =
              "Authentication failed. Please verify your API key and try again.";
        } else if (response.statusCode == 429) {
          errorMsg =
              "Service is temporarily busy. Please try again in a few moments.";
        }
        _showErrorSnackBar(errorMsg);
      }
    } catch (e) {
      // print(...);
      _showErrorSnackBar(
          "Unable to analyze the image. Please check your internet connection and try again.");
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
        _showErrorSnackBar(
            'Your session has expired. Please log in again to continue.');
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
          userId: user.id,
          plasticType: _selectedType,
          itemName: _titleController.text,
          description: _descController.text,
          location: _locationController.text,
          imageUrl: imageUrl,
          quantity: _quantity, // Pass quantity to service
        );
      } on PostgrestException catch (e) {
        // print(...);
        throw Exception(
            'Database Error: ${e.message}. (Check RLS/Foreign Keys)');
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('plastic_waste_reported'))));
      }
    } catch (e) {
      _showErrorSnackBar(
          "Unable to submit your plastic waste report. Please try again.");
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

  void _showRejectionDialog(String title, String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('add_plastic_waste')),
        flexibleSpace: Theme.of(context).brightness == Brightness.dark
            ? null
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)]),
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
                                    .withValues(alpha: 0.6),
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
                                        Colors.black.withValues(alpha: 0.5),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              if (_isLoading)
                                Container(
                                  color: Colors.black.withValues(alpha: 0.5),
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
                      items: [
                        'Bottle',
                        'Polythene Bags & Covers',
                        'Plastic Furniture',
                        'Sheets & Films',
                        'Multi-layer Packaging (Wrappers)',
                        'Rigid Plastic (HDPE/PP)',
                        'Other'
                      ]
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

                    const SizedBox(height: 16),

                    // NEW: Quantity Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Quantity',
                            style: Theme.of(context).textTheme.titleMedium),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: _quantity > 1
                                    ? () {
                                        setState(() {
                                          _quantity--;
                                          int base = (_selectedType == 'Bottle')
                                              ? 40
                                              : 20;
                                          _estimatedPoints =
                                              base + ((_quantity - 1) * 5);
                                        });
                                      }
                                    : null,
                              ),
                              Text(
                                '$_quantity',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  setState(() {
                                    _quantity++;
                                    int base =
                                        (_selectedType == 'Bottle') ? 40 : 20;
                                    _estimatedPoints =
                                        base + ((_quantity - 1) * 5);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                        height: 12), // Spacer before category display

                    // Detected Category Display
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
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
                        color: Colors.teal.withValues(alpha: 0.1),
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
