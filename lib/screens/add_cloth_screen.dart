import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../services/cloth_service.dart';
import '../core/supabase_config.dart';
import '../core/gemini_config.dart';

// ...existing code...

class AddClothScreen extends StatefulWidget {
  const AddClothScreen({super.key});

  @override
  State<AddClothScreen> createState() => _AddClothScreenState();
}

class _AddClothScreenState extends State<AddClothScreen> {
  String? _aiError;
  final String _geminiApiKey = GeminiConfig.apiKey;
  final String _geminiModel = "gemini-2.5-flash-preview-09-2025";
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _quantityController = TextEditingController();

  String _selectedType = 'Apparel';
  String _selectedCondition = 'Good'; // Set by AI after analysis
  int _estimatedDamagePercent = 0; // AI's objective damage assessment
  int _ecoPoints = 0; // Calculated eco points
  double? _latitude;
  double? _longitude;

  bool _isSubmitting = false;
  bool _isLoading = false;

  File? _imageFile;
  XFile? _pickedXFile;
  String _detectionMessage = 'Capture photo to analyze item.';

  final _clothService = ClothService();

  // FIX: These are the master categories used in the dropdown
  final List<String> _clothTypes = [
    'Apparel',
    'Linen',
    'Accessories',
    'Footwear',
    'Other'
  ];
  final List<String> _conditions = ['Good', 'Fair', 'Poor'];

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    _locationController.text = "Locating...";
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackbar(
              'Location access is required to determine your pickup address. Please grant location permissions.');
          setState(() => _isLoading = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnackbar(
            'Location permissions have been permanently denied. To use this feature, enable location access in your device settings.');
        setState(() => _isLoading = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
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
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      } else {
        _showSnackbar(
            'Unable to retrieve your address. Please try again or enter it manually.');
      }
    } catch (e) {
      _showSnackbar(
          "An error occurred while accessing your location. Please check your connection and try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Calculate eco points based on damage and type
  void _updateEcoPoints() {
    // Example logic: Good = 125, Fair = 100, Poor = 75, reduce by damage
    int basePoints;
    switch (_selectedCondition) {
      case 'Good':
        basePoints = 125;
        break;
      case 'Fair':
        basePoints = 100;
        break;
      case 'Poor':
        basePoints = 75;
        break;
      default:
        basePoints = 75;
    }
    // Reduce points by damage percent (max 80%)
    int reduction = ((_estimatedDamagePercent / 100) * basePoints).round();
    int points = basePoints - reduction;
    if (points < 0) points = 0;
    setState(() => _ecoPoints = points);
  }

  @override
  void dispose() {
    _locationController.dispose();
    _quantityController.dispose();
    super.dispose();
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
      await _detectCloth(pickedFile);
    }
  }

  // ------------------------------------------
  // Image Detection Logic (Gemini API for Cloth/Damage)
  // ------------------------------------------

  Future<void> _detectCloth(XFile xFile) async {
    if (_geminiApiKey.isEmpty || _geminiApiKey.contains('DISABLED')) {
      _showSnackbar(
          'AI analysis is currently unavailable. Please contact support to enable image analysis features.');
      return;
    }

    setState(() {
      _isLoading = true;
      _detectionMessage =
          'Analyzing image for cloth type, damage, and quantity...';
      _estimatedDamagePercent = 0;
      _aiError = null;
    });

    try {
      final Uint8List bytes = await xFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = lookupMimeType(xFile.path) ?? 'image/jpeg';

      final userQuery = """
      Analyze this image carefully for cloth donation submission.

      FIRST: Check for human presence
      - If ANY human (person, hand, face, or body part) is visible in the image, immediately reject with error.

      SECOND: Cloth validation and analysis
      - Determine if the main item is CLOTHING/FABRIC. If not, return "NON_CLOTHING".
      - If it is clothing, provide a concise 'type' (e.g., Shirt, Blanket, Shoes).
      - Estimate the percentage of visible damage (stains, tears, excessive wear) from 0 (perfect) to 100 (total waste).
      - Estimate the number of items visible (quantity, minimum 1 if unsure).

      RESPONSE RULES:
      - If human detected: Set "error_type": "human_detected", "error_message": "Not acceptable image, human detected"
      - If valid cloth: Provide cloth details without error fields
      - If not cloth: Set type to "NON_CLOTHING" without error fields

      Respond ONLY with a JSON object in one of these formats:

      For VALID cloth:
      {"type":"[Identified Type]", "damage_percent":[0-100], "reason":"[1 sentence summary of quality]", "quantity": [number, minimum 1]}

      For NON_CLOTHING:
      {"type":"NON_CLOTHING", "damage_percent":100, "reason":"Not a cloth item", "quantity": 0}

      For HUMAN DETECTED:
      {"error_type":"human_detected", "error_message":"Not acceptable image, human detected"}
      """;

      final apiUrl =
          "https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiApiKey";

      final payload = {
        "contents": [
          {
            "parts": [
              {"text": userQuery},
              {
                "inlineData": {"mimeType": mimeType, "data": base64Image}
              }
            ]
          }
        ],
        "generationConfig": {
          "responseMimeType": "application/json",
          "responseSchema": {
            "type": "OBJECT",
            "properties": {
              "type": {"type": "STRING"},
              "damage_percent": {"type": "INTEGER"},
              "reason": {"type": "STRING"},
              "quantity": {"type": "INTEGER"},
              "error_type": {"type": "STRING"},
              "error_message": {"type": "STRING"}
            },
            "propertyOrdering": [
              "type",
              "damage_percent",
              "reason",
              "quantity",
              "error_type",
              "error_message"
            ]
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
        final jsonString =
            result['candidates']?[0]?['content']?['parts']?[0]?['text'];
        final aiData = jsonDecode(jsonString);

        if (aiData != null) {
          // Check for error responses first
          final errorType = aiData['error_type']?.toString();
          final errorMessage = aiData['error_message']?.toString();

          if (errorType != null && errorMessage != null) {
            // Handle rejection cases: human detected or poor quality
            setState(() {
              _imageFile = null; // Clear image to prevent accidental submission
              _pickedXFile = null; // Clear the picked file as well
              _estimatedDamagePercent = 0;
              _ecoPoints = 0;
              _detectionMessage = errorMessage;
              _selectedType = 'Apparel'; // Reset to a default valid category
            });
            throw Exception(errorMessage);
          }

          // Handle valid responses
          final detectedType = aiData['type']?.toString() ?? 'Other';
          final damage = aiData['damage_percent'] as int? ?? 100;
          final reason = aiData['reason'] as String? ?? 'Analysis complete.';
          int aiQuantity = 1;
          if (aiData.containsKey('quantity')) {
            aiQuantity = aiData['quantity'] is int
                ? aiData['quantity']
                : int.tryParse(aiData['quantity'].toString()) ?? 1;
            if (aiQuantity < 1) aiQuantity = 1;
          }

          if (detectedType.toUpperCase() == 'NON_CLOTHING' || damage > 80) {
            _handleRejection(detectedType, damage, reason);
            return;
          }

          // FIX LOGIC: Map the detailed AI result to a master category for the dropdown
          String masterCategory = 'Other';

          if (detectedType.toLowerCase().contains('shirt') ||
              detectedType.toLowerCase().contains('trousers') ||
              detectedType.toLowerCase().contains('dress')) {
            masterCategory = 'Apparel';
          } else if (detectedType.toLowerCase().contains('blanket') ||
              detectedType.toLowerCase().contains('towel') ||
              detectedType.toLowerCase().contains('sheet')) {
            masterCategory = 'Linen';
          } else if (detectedType.toLowerCase().contains('bag') ||
              detectedType.toLowerCase().contains('hat') ||
              detectedType.toLowerCase().contains('scarf')) {
            masterCategory = 'Accessories';
          } else if (detectedType.toLowerCase().contains('shoes') ||
              detectedType.toLowerCase().contains('sneakers')) {
            masterCategory = 'Footwear';
          }
          // Default remains 'Other' if no match is found.

          // Set condition based on damage percent (AI only)
          String aiCondition = 'Good';
          if (damage > 30 && damage <= 80) {
            aiCondition = 'Fair';
          } else if (damage > 80) {
            aiCondition = 'Poor';
          }
          setState(() {
            _estimatedDamagePercent = damage;
            _selectedType = masterCategory;
            _selectedCondition = aiCondition;
            _quantityController.text = aiQuantity.toString();
            _detectionMessage =
                'Analysis complete. Item set to: $masterCategory, Damage estimated at $damage%. Condition: $aiCondition. Quantity: $aiQuantity.';
            _aiError = null;
          });
          _updateEcoPoints();

          _showSnackbar(
              'Item detected: $detectedType. Damage: $damage%. Condition: $aiCondition. Quantity: $aiQuantity. Accepted for recycling.');
        } else {
          setState(() {
            _aiError =
                'Image analysis encountered an error. Please try uploading the photo again.';
          });
          throw Exception(
              'Image analysis encountered an error. Please try uploading the photo again.');
        }
      } else {
        throw Exception(
            'Gemini API failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // print(...);
      setState(() {
        _aiError =
            'Image analysis failed. Please try uploading the photo again.';
      });
      _showSnackbar(
          'Image analysis failed. Please try uploading the photo again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleRejection(String type, int damage, String reason) {
    if (mounted) {
      String message;
      if (type.toUpperCase() == 'NON_CLOTHING') {
        message =
            'Item not accepted: We only accept clothing and fabric items for donation.';
      } else {
        message =
            'Item not accepted: Damage level ($damage%) exceeds our 80% threshold. $reason';
      }

      setState(() {
        _imageFile = null;
        _pickedXFile = null;
        _estimatedDamagePercent = 0;
        _ecoPoints = 0;
        _detectionMessage = message;
        _selectedType = 'Apparel'; // Reset to a valid default value
      });
      _showSnackbar(message);
    }
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // ------------------------------------------
  // Submission Logic
  // ------------------------------------------

  Future<void> _submitDonation() async {
    // Check for rejection status again before final submit
    if (!_formKey.currentState!.validate() ||
        _pickedXFile == null ||
        _estimatedDamagePercent > 80) {
      _showSnackbar(
          'Please complete all required fields, upload a photo, and ensure the item meets our damage criteria.');
      return;
    }

    final userId = AppSupabase.client.auth.currentUser?.id;
    if (userId == null) {
      _showSnackbar('Session expired. Please log in again to continue.');
      return;
    }

    setState(() => _isSubmitting = true);
    String? imageUrl;

    try {
      final fileBytes = await _pickedXFile!.readAsBytes();
      final mimeType = lookupMimeType(_pickedXFile!.path) ?? 'image/jpeg';

      // 1. Upload File
      try {
        imageUrl = await _clothService.uploadImage(fileBytes, mimeType);
      } catch (e) {
        throw Exception('Failed to upload image: ${e.toString()}');
      }

      // 2. Database Insertion
      await _clothService.insertClothDonation(
        userId: userId,
        type: _selectedType, // Use the categorized type
        quantity: int.parse(_quantityController.text),
        condition: _selectedCondition,
        location: _locationController.text,
        imageUrl: imageUrl,
        estimatedDamagePercent: _estimatedDamagePercent,
        latitude: _latitude,
        longitude: _longitude,
      );

      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Donation submitted successfully for review.');
      }
    } catch (e) {
      // print(...);
      _showSnackbar(
          'Submission failed. Please check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Check if the item is rejected by AI based on damage limit
    final bool isRejectedByDamage =
        _imageFile != null && _estimatedDamagePercent > 80;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('donate_clothes')),
        flexibleSpace: Theme.of(context).brightness == Brightness.dark
            ? null
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)],
                  ),
                ),
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step 1
              Text(
                'Step 1: Photo Analysis (AI detects type, condition, and number of items)',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Capture an image to automatically check if the item is clothing, assess its damage, and count the number of items. Any AI detection errors will be shown below.',
                style: TextStyle(color: theme.hintColor),
              ),
              if (_aiError != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_aiError ?? '',
                              style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // --- Image Capture/Detection Area ---
              GestureDetector(
                onTap: _isLoading ? null : _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: _imageFile == null
                        ? theme.colorScheme.surfaceContainerHighest
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRejectedByDamage
                          ? Colors.red.shade700
                          : theme.dividerColor,
                      width: 2,
                    ),
                    image: _imageFile != null
                        ? DecorationImage(
                            image: FileImage(_imageFile!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: Center(
                    child: _imageFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt,
                                  size: 56,
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.6)),
                              const SizedBox(height: 12),
                              Text(_detectionMessage,
                                  style: const TextStyle(fontSize: 16)),
                            ],
                          )
                        : _isLoading
                            ? Container(
                                color: Colors.black.withValues(alpha: 0.5),
                                child: const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white)),
                              )
                            : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- Detection Results ---
              if (_imageFile != null && !_isLoading) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isRejectedByDamage
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isRejectedByDamage
                            ? Colors.red.shade300
                            : Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          isRejectedByDamage ? Icons.block : Icons.check_circle,
                          color: isRejectedByDamage
                              ? Colors.red.shade700
                              : Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Analysis:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyLarge?.color),
                            ),
                            Text(
                              isRejectedByDamage
                                  ? 'Status: REJECTED (Damage: $_estimatedDamagePercent%)'
                                  : 'Type Detected: $_selectedType | Damage: $_estimatedDamagePercent%',
                              style: TextStyle(
                                  color: isRejectedByDamage
                                      ? Colors.red.shade700
                                      : Colors.green.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Step 2
              Text(
                'Step 2: Donation Details',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Cloth Type Dropdown (AI only, disabled for user)
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Cloth Type (AI detected)',
                  prefixIcon: const Icon(Icons.style_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: _clothTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: null, // Disabled
                validator: (value) =>
                    value == null ? tr('required_field') : null,
                disabledHint: Text(_selectedType),
              ),
              const SizedBox(height: 16),

              // Quantity Input
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity (Number of items)',
                  prefixIcon: const Icon(Icons.numbers),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return tr('required_field');
                  }
                  final intVal = int.tryParse(value);
                  if (intVal == null || intVal < 1) {
                    return 'Minimum quantity is 1';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Condition Dropdown (AI only, disabled for user)
              DropdownButtonFormField<String>(
                initialValue: _selectedCondition,
                decoration: InputDecoration(
                  labelText: 'Condition (AI detected)',
                  prefixIcon: const Icon(Icons.check_box_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: _conditions.map((String condition) {
                  return DropdownMenuItem<String>(
                    value: condition,
                    child: Text(condition),
                  );
                }).toList(),
                onChanged: null, // Disabled
                validator: (value) =>
                    value == null ? tr('required_field') : null,
                disabledHint: Text(_selectedCondition),
              ),
              const SizedBox(height: 16),

              // Step 3
              Text(
                'Step 3: Pickup Location / Address',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                maxLines: 2,
                readOnly: _isLoading,
                decoration: InputDecoration(
                  labelText: 'Pickup Location / Address',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.blue),
                    onPressed: _isLoading ? null : _getCurrentLocation,
                    tooltip: 'Use Current Location',
                  ),
                ),
                validator: (value) =>
                    value?.isEmpty == true ? tr('required_field') : null,
              ),
              const SizedBox(height: 32),

              // Submit Button
              // Eco Points Display
              if (_ecoPoints > 0 && !isRejectedByDamage) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text('Estimated EcoPoints: $_ecoPoints',
                          style: TextStyle(
                              color: Colors.teal.shade800,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_isSubmitting ||
                          _imageFile == null ||
                          isRejectedByDamage)
                      ? null
                      : _submitDonation,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.favorite_border),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                        _isSubmitting
                            ? 'Submitting...'
                            : isRejectedByDamage
                                ? 'Rejected (Too Damaged)'
                                : 'Submit Donation',
                        style: const TextStyle(fontSize: 16)),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: isRejectedByDamage
                        ? Colors.red.shade400
                        : Colors.indigo,
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
