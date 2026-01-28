import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:http/http.dart' as http;
import '../services/cloth_service.dart';
import '../core/supabase_config.dart';

// Assuming GEMINI_API_KEY is available globally or needs to be defined here:
const String _GEMINI_API_KEY = "AIzaSyB6OjloqNfljFJvo4YUnr6XqUZ2rkCGXsU"; 
const String _GEMINI_MODEL = "gemini-2.5-flash-preview-09-2025";

class AddClothScreen extends StatefulWidget {
  const AddClothScreen({super.key});

  @override
  State<AddClothScreen> createState() => _AddClothScreenState();
}

class _AddClothScreenState extends State<AddClothScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _quantityController = TextEditingController();
  
  String _selectedType = 'Apparel';
  String _selectedCondition = 'Good'; // User's subjective assessment
  int _estimatedDamagePercent = 0; // AI's objective damage assessment
  bool _isSubmitting = false;
  bool _isLoading = false;

  File? _imageFile;
  XFile? _pickedXFile;
  String _detectionMessage = 'Capture photo to analyze item.';
  
  final _clothService = ClothService();

  // FIX: These are the master categories used in the dropdown
  final List<String> _clothTypes = ['Apparel', 'Linen', 'Accessories', 'Footwear', 'Other'];
  final List<String> _conditions = ['Good', 'Fair', 'Poor'];

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
    if (_GEMINI_API_KEY.isEmpty) {
      _showSnackbar('Gemini API Key is not set.');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _detectionMessage = 'Analyzing image for cloth type and damage...';
      _estimatedDamagePercent = 0;
    });

    try {
      final Uint8List bytes = await xFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = lookupMimeType(xFile.path) ?? 'image/jpeg';
      
      final userQuery = """
      Analyze this image. 
      1. Determine if the main item is CLOTHING/FABRIC. If not, return "NON_CLOTHING".
      2. If it is clothing, provide a concise 'type' (e.g., Shirt, Blanket, Shoes).
      3. Estimate the percentage of visible damage (stains, tears, excessive wear) from 0 (perfect) to 100 (total waste).

      Respond ONLY with a JSON object. The JSON structure is: 
      {"type":"[Identified Type or NON_CLOTHING]", "damage_percent":[0-100], "reason":"[1 sentence summary of quality]"}
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
              "type": {"type": "STRING"},
              "damage_percent": {"type": "INTEGER"},
              "reason": {"type": "STRING"}
            },
            "propertyOrdering": ["type", "damage_percent", "reason"]
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
          final detectedType = aiData['type']?.toString() ?? 'Other';
          final damage = aiData['damage_percent'] as int? ?? 100;
          final reason = aiData['reason'] as String? ?? 'Analysis complete.';
          
          if (detectedType.toUpperCase() == 'NON_CLOTHING' || damage > 80) {
             _handleRejection(detectedType, damage, reason);
             return;
          }

          // FIX LOGIC: Map the detailed AI result to a master category for the dropdown
          String masterCategory = 'Other';
          
          if (detectedType.toLowerCase().contains('shirt') || detectedType.toLowerCase().contains('trousers') || detectedType.toLowerCase().contains('dress')) {
              masterCategory = 'Apparel';
          } else if (detectedType.toLowerCase().contains('blanket') || detectedType.toLowerCase().contains('towel') || detectedType.toLowerCase().contains('sheet')) {
              masterCategory = 'Linen';
          } else if (detectedType.toLowerCase().contains('bag') || detectedType.toLowerCase().contains('hat') || detectedType.toLowerCase().contains('scarf')) {
              masterCategory = 'Accessories';
          } else if (detectedType.toLowerCase().contains('shoes') || detectedType.toLowerCase().contains('sneakers')) {
              masterCategory = 'Footwear';
          }
          // Default remains 'Other' if no match is found.

          // Successful analysis
          setState(() {
            _estimatedDamagePercent = damage;
            // Set the state variable to the master category
            _selectedType = masterCategory; 
            _detectionMessage = 'Analysis complete. Item set to: $masterCategory, Damage estimated at $damage%.';
          });
          
          _showSnackbar('Item detected: $detectedType. Damage: $damage%. Accepted for donation.');

        } else {
          throw Exception('AI analysis failed to return expected JSON.');
        }

      } else {
        throw Exception('Gemini API failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('AI Detection Error: $e');
      _showSnackbar('AI Detection Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _handleRejection(String type, int damage, String reason) {
    if (mounted) {
      String message;
      if (type.toUpperCase() == 'NON_CLOTHING') {
        message = 'Item rejected: Only clothing/fabric is accepted.';
      } else {
        message = 'Item rejected: Damage ($damage%) exceeds 80% limit. $reason';
      }
      
      setState(() {
        _imageFile = null; 
        _pickedXFile = null;
        _estimatedDamagePercent = 0;
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
    if (!_formKey.currentState!.validate() || _pickedXFile == null || _estimatedDamagePercent > 80) {
      _showSnackbar('Please ensure all fields are filled, a photo is uploaded, and the damage is acceptable (<= 80%).');
      return;
    }

    final userId = AppSupabase.client.auth.currentUser?.id;
    if (userId == null) {
      _showSnackbar('Authentication error. Please log in again.');
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
      );

      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Donation submitted successfully for review.');
      }
    } catch (e) {
      debugPrint('Submission Error: $e');
      _showSnackbar('Submission failed: Check connection and permissions.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Check if the item is rejected by AI based on damage limit
    final bool isRejectedByDamage = _imageFile != null && _estimatedDamagePercent > 80;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('donate_clothes')),
        flexibleSpace: Container(
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
              Text(
                'Step 1: Photo Analysis (80% Max Damage)',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Capture an image to automatically check if the item is clothing and assess its damage.',
                style: TextStyle(color: theme.hintColor),
              ),
              const SizedBox(height: 16),
              
              // --- Image Capture/Detection Area ---
              GestureDetector(
                onTap: _isLoading ? null : _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: _imageFile == null ? theme.colorScheme.surfaceContainerHighest : null,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRejectedByDamage ? Colors.red.shade700 : theme.dividerColor,
                      width: 2,
                    ),
                    image: _imageFile != null
                        ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: Center(
                    child: _imageFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 56, color: theme.colorScheme.primary.withOpacity(0.6)),
                              const SizedBox(height: 12),
                              Text(_detectionMessage, style: const TextStyle(fontSize: 16)),
                            ],
                          )
                        : _isLoading 
                          ? Container(
                              color: Colors.black.withOpacity(0.5),
                              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
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
                    color: isRejectedByDamage ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isRejectedByDamage ? Colors.red.shade300 : Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(isRejectedByDamage ? Icons.block : Icons.check_circle, 
                           color: isRejectedByDamage ? Colors.red.shade700 : Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Analysis:',
                              style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                            ),
                            Text(
                              isRejectedByDamage 
                                ? 'Status: REJECTED (Damage: $_estimatedDamagePercent%)'
                                : 'Type Detected: $_selectedType | Damage: $_estimatedDamagePercent%',
                              style: TextStyle(color: isRejectedByDamage ? Colors.red.shade700 : Colors.green.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],


              Text(
                'Step 2: Donation Details',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Cloth Type Dropdown (User can override AI suggestion)
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Cloth Type',
                  prefixIcon: const Icon(Icons.style_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _clothTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedType = newValue!;
                  });
                },
                validator: (value) => value == null ? tr('required_field') : null,
              ),
              const SizedBox(height: 16),

              // Quantity Input
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity (Number of items)',
                  prefixIcon: const Icon(Icons.numbers),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return tr('required_field');
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Condition Dropdown (User's subjective assessment)
              DropdownButtonFormField<String>(
                initialValue: _selectedCondition,
                decoration: InputDecoration(
                  labelText: 'Condition (Your rating)',
                  prefixIcon: const Icon(Icons.check_box_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _conditions.map((String condition) {
                  return DropdownMenuItem<String>(
                    value: condition,
                    child: Text(condition),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCondition = newValue!;
                  });
                },
                validator: (value) => value == null ? tr('required_field') : null,
              ),
              const SizedBox(height: 16),

              // Pickup Location
              TextFormField(
                controller: _locationController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Pickup Location / Address',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => value?.isEmpty == true ? tr('required_field') : null,
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_isSubmitting || _imageFile == null || isRejectedByDamage) ? null : _submitDonation,
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
                      _isSubmitting ? 'Submitting...' : isRejectedByDamage ? 'Rejected (Too Damaged)' : 'Submit Donation', 
                      style: const TextStyle(fontSize: 16)
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: isRejectedByDamage ? Colors.red.shade400 : Colors.indigo,
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