import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import '../core/supabase_config.dart';
import '../services/plastic_service.dart';

// IMPORTANT: Replace this with a BRAND NEW key from Google AI Studio.
// DO NOT share this key publicly or it will be leaked and disabled again.
const String _NEW_GEMINI_KEY = "AIzaSyB_wg2sH_ibW5Vzp_as2lqUb3PlEBYcDGY";
const String _MODEL_NAME = "gemini-1.5-flash"; 

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
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18';
      final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'EcoCycle/1.0'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _locationController.text = data['display_name'] ?? "${position.latitude}, ${position.longitude}";
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

      final url = "https://generativelanguage.googleapis.com/v1beta/models/$_MODEL_NAME:generateContent?key=$_NEW_GEMINI_KEY";

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{
            "parts": [
              {"text": prompt},
              {"inlineData": {"mimeType": "image/jpeg", "data": base64Image}}
            ]
          }],
          "generationConfig": {"responseMimeType": "application/json"}
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResult = jsonDecode(data['candidates'][0]['content']['parts'][0]['text']);
        
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
        _showErrorSnackBar("API Error: ${response.statusCode}. Check your API key.");
      }
    } catch (e) {
      debugPrint("AI Detection Error: $e");
      _showErrorSnackBar("Analysis failed. Check your internet connection.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);

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
      final user = AppSupabase.client.auth.currentUser;
      final bytes = await _pickedXFile!.readAsBytes();
      final mimeType = lookupMimeType(_pickedXFile!.path) ?? 'image/jpeg';
      
      // Fixed service call to match updated plastic_service.dart
      final imageUrl = await PlasticService().uploadImage(bytes, mimeType);

      await PlasticService().insertPlastic(
        userId: user!.id,
        plasticType: _selectedType,
        itemName: _titleController.text,
        description: _descController.text,
        location: _locationController.text,
        imageUrl: imageUrl,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plastic Waste Reported!")));
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
        title: const Text('Add Plastic Waste'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)]),
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
              // Photo Area
              _inputCard(
                child: GestureDetector(
                  onTap: _isLoading ? null : _pickImage,
                  child: Container(
                    width: double.infinity, height: 220,
                    decoration: BoxDecoration(
                      color: _imageFile == null ? Colors.grey.shade200 : null,
                      borderRadius: BorderRadius.circular(12),
                      image: _imageFile != null ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover) : null,
                    ),
                    child: _imageFile == null 
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_enhance, size: 56, color: Colors.green),
                              SizedBox(height: 12),
                              Text("Tap to capture plastic waste", style: TextStyle(color: Colors.grey)),
                            ],
                          ) 
                        : (_isLoading ? const Center(child: CircularProgressIndicator()) : null),
                  ),
                ),
              ),
              // Item Details
              _inputCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController, 
                      readOnly: _isLoading,
                      decoration: const InputDecoration(labelText: 'Item Name', prefixIcon: Icon(Icons.edit_note), border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController, 
                      readOnly: _isLoading,
                      maxLines: 3, 
                      decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      items: ['Bottle', 'Bag', 'Cover', 'Other'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: _isLoading ? null : (v) => setState(() => _selectedType = v!),
                      decoration: const InputDecoration(labelText: 'Plastic Category', prefixIcon: Icon(Icons.category_outlined), border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              // Location
              _inputCard(
                child: TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'Pickup Location',
                    prefixIcon: const Icon(Icons.location_on),
                    suffixIcon: IconButton(icon: const Icon(Icons.my_location, color: Colors.blue), onPressed: _isLoading ? null : _getCurrentLocation),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? "Location required" : null,
                ),
              ),
              // Rewards Preview
              if (_estimatedPoints > 0)
                _inputCard(child: Row(
                  children: [
                    const Icon(Icons.stars, color: Colors.teal),
                    const SizedBox(width: 8),
                    Text("Estimated EcoPoints: $_estimatedPoints", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                  ],
                )),
              const SizedBox(height: 24),
              // Action Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading || _imageFile == null ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit for Recycling', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}