import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class TestUploadPage extends StatefulWidget {
  const TestUploadPage({super.key});
  @override
  State<TestUploadPage> createState() => _TestUploadPageState();
}

class _TestUploadPageState extends State<TestUploadPage> {
  final supabase = Supabase.instance.client;
  File? _image;
  bool _busy = false;

  Future<void> _pick() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _image = File(x.path));
  }

  Future<void> _upload() async {
    if (_image == null) return;
    setState(() => _busy = true);
    try {
      final name = p.basename(_image!.path);
      final path = 'uploads/$name';

      await supabase.storage.from('ewaste_images').upload(path, _image!);
      final publicUrl =
          supabase.storage.from('ewaste_images').getPublicUrl(path);

      await supabase.from('ewaste_items').insert({
        'title': 'Test Upload',
        'description': 'Uploaded from Flutter',
        'image_url': publicUrl,
        'location': 'Test Location',
        'status': 'Pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Uploaded & inserted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Upload')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_image != null) Image.file(_image!, height: 180),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _pick, child: const Text('Pick Image')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _busy ? null : _upload,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Text('Upload & Insert'),
            ),
          ],
        ),
      ),
    );
  }
}
