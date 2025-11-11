import 'package:flutter/material.dart';
import '../models/ngo.dart';
import '../services/ewaste_service.dart';

class NgoManagementScreen extends StatefulWidget {
  const NgoManagementScreen({super.key});

  @override
  State<NgoManagementScreen> createState() => _NgoManagementScreenState();
}

class _NgoManagementScreenState extends State<NgoManagementScreen> {
  final _ewasteService = EwasteService();
  List<Ngo> _ngos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNgos();
  }

  Future<void> _fetchNgos() async {
    try {
      final ngos = await _ewasteService.fetchNgos();
      setState(() {
        _ngos = ngos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading NGOs: $e')),
      );
    }
  }

  Future<void> _addNgo() async {
    final result = await showDialog<Ngo>(
      context: context,
      builder: (context) => const AddNgoDialog(),
    );

    if (result != null) {
      try {
        await _ewasteService.addNgo(result);
        _fetchNgos();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NGO added successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding NGO: $e')),
        );
      }
    }
  }

  Future<void> _deleteNgo(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete NGO'),
        content: const Text('Are you sure you want to delete this NGO?'),
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
      try {
        await _ewasteService.deleteNgo(id);
        _fetchNgos();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NGO deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting NGO: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NGO Management'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNgo,
            tooltip: 'Add NGO',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ngos.isEmpty
              ? const Center(child: Text('No NGOs found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _ngos.length,
                  itemBuilder: (context, index) {
                    final ngo = _ngos[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.business, color: Colors.green),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    ngo.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteNgo(ngo.id),
                                  tooltip: 'Delete NGO',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (ngo.description != null) ...[
                              Text(
                                ngo.description!,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    ngo.address,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                            if (ngo.phone != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.phone,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    ngo.phone!,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                            if (ngo.email != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.email,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    ngo.email!,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class AddNgoDialog extends StatefulWidget {
  const AddNgoDialog({super.key});

  @override
  State<AddNgoDialog> createState() => _AddNgoDialogState();
}

class _AddNgoDialogState extends State<AddNgoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final ngo = Ngo(
        id: '', // Will be generated by database
        name: _nameController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        address: _addressController.text,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      Navigator.pop(context, ngo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add NGO'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'NGO Name *'),
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address *'),
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add NGO'),
        ),
      ],
    );
  }
}
