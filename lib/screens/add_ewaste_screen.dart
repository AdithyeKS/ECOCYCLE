import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddEwasteScreen extends StatefulWidget {
  const AddEwasteScreen({super.key});

  @override
  State<AddEwasteScreen> createState() => _AddEwasteScreenState();
}

class _AddEwasteScreenState extends State<AddEwasteScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  File? imageFile;
  bool isUploading = false;

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => imageFile = File(picked.path));
    }
  }

  Future<void> uploadData() async {
    if (nameController.text.isEmpty || imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select an image')),
      );
      return;
    }

    setState(() => isUploading = true);

    try {
      final fileName = 'ewaste_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = 'uploads/$fileName';

      await Supabase.instance.client.storage
          .from('ewaste_images')
          .upload(filePath, imageFile!);

      final imageUrl = Supabase.instance.client.storage
          .from('ewaste_images')
          .getPublicUrl(filePath);

      await Supabase.instance.client.from('ewaste_items').insert({
        'item_name': nameController.text,
        'description': descController.text,
        'location': locationController.text,
        'status': 'Pending',
        'image_url': imageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Uploaded successfully!')),
      );

      setState(() {
        isUploading = false;
        imageFile = null;
        nameController.clear();
        descController.clear();
        locationController.clear();
      });
    } catch (e) {
      setState(() => isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Upload failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add E-Waste')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Item Name')),
              const SizedBox(height: 10),
              TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 10),
              TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location')),
              const SizedBox(height: 15),
              if (imageFile != null)
                Image.file(imageFile!, width: 150, height: 150, fit: BoxFit.cover),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: pickImage, child: const Text('Pick Image')),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: isUploading ? null : uploadData,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Upload'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
