import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ewaste_item.dart';
import '../models/ngo.dart';
import '../models/pickup_agent.dart';
import '../services/ewaste_service.dart';
import 'ngo_management_screen.dart';
import 'agent_dashboard.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _ewasteService = EwasteService();
  List<EwasteItem> ewasteItems = [];
  List<Ngo> ngos = [];
  List<PickupAgent> agents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAllData();
  }

  Future<void> fetchAllData() async {
    try {
      final items = await _ewasteService.fetchAll();
      final ngoList = await _ewasteService.fetchNgos();
      final agentList = await _ewasteService.fetchPickupAgents();
      setState(() {
        ewasteItems = items;
        ngos = ngoList;
        agents = agentList;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> updateStatus(String id, String newStatus) async {
    try {
      await _ewasteService.updateStatus(int.parse(id), newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Status updated to "$newStatus"!')),
      );
      fetchAllData(); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to update status: $e')),
      );
    }
  }

  Future<void> assignPickupAgent(String itemId, String agentId) async {
    try {
      await _ewasteService.assignPickupAgent(int.parse(itemId), agentId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Pickup agent assigned!')),
      );
      fetchAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to assign agent: $e')),
      );
    }
  }

  Future<void> assignNgo(String itemId, String ngoId) async {
    try {
      await _ewasteService.assignNgo(int.parse(itemId), ngoId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ NGO assigned!')),
      );
      fetchAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to assign NGO: $e')),
      );
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.orange;
      case 'collected':
        return Colors.green;
      case 'delivered':
        return Colors.blue;
      default:
        return Colors.redAccent;
    }
  }

  void _showAssignmentDialog(EwasteItem item) {
    showDialog(
      context: context,
      builder: (context) => AssignmentDialog(
        item: item,
        ngos: ngos,
        agents: agents,
        onAssignAgent: (agentId) =>
            assignPickupAgent(item.id.toString(), agentId),
        onAssignNgo: (ngoId) => assignNgo(item.id.toString(), ngoId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.business),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NgoManagementScreen()),
            ),
            tooltip: 'Manage NGOs',
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AgentDashboard()),
            ),
            tooltip: 'Agent Dashboard',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchAllData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ewasteItems.isEmpty
              ? const Center(child: Text('No e-waste items found'))
              : ListView.builder(
                  itemCount: ewasteItems.length,
                  itemBuilder: (context, index) {
                    final item = ewasteItems[index];
                    return Card(
                      margin: const EdgeInsets.all(10),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.imageUrl.isNotEmpty)
                              Image.network(item.imageUrl,
                                  height: 120, fit: BoxFit.cover),
                            const SizedBox(height: 10),
                            Text('🧱 ${item.itemName}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
                            Text(item.description),
                            Text('📍 Location: ${item.location}'),
                            Text(
                              'Status: ${item.status}',
                              style: TextStyle(
                                  color: getStatusColor(item.status),
                                  fontWeight: FontWeight.bold),
                            ),
                            if (item.assignedAgentId != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '👤 Agent Assigned',
                                style: TextStyle(color: Colors.blue[700]),
                              ),
                            ],
                            if (item.assignedNgoId != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '🏢 NGO Assigned',
                                style: TextStyle(color: Colors.green[700]),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: () => updateStatus(
                                      item.id.toString(), 'Approved'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange),
                                  child: const Text('Approve'),
                                ),
                                ElevatedButton(
                                  onPressed: () => updateStatus(
                                      item.id.toString(), 'Collected'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green),
                                  child: const Text('Collected'),
                                ),
                                ElevatedButton(
                                  onPressed: () => _showAssignmentDialog(item),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue),
                                  child: const Text('Assign'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class AssignmentDialog extends StatefulWidget {
  final EwasteItem item;
  final List<Ngo> ngos;
  final List<PickupAgent> agents;
  final Function(String) onAssignAgent;
  final Function(String) onAssignNgo;

  const AssignmentDialog({
    super.key,
    required this.item,
    required this.ngos,
    required this.agents,
    required this.onAssignAgent,
    required this.onAssignNgo,
  });

  @override
  State<AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<AssignmentDialog> {
  String? selectedAgentId;
  String? selectedNgoId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign "${widget.item.itemName}"'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pickup Agent:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedAgentId,
              hint: const Text('Select pickup agent'),
              items: widget.agents.map((agent) {
                return DropdownMenuItem(
                  value: agent.id,
                  child: Text(agent.name),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedAgentId = value),
            ),
            const SizedBox(height: 16),
            const Text('NGO:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedNgoId,
              hint: const Text('Select NGO'),
              items: widget.ngos.map((ngo) {
                return DropdownMenuItem(
                  value: ngo.id,
                  child: Text(ngo.name),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedNgoId = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (selectedAgentId != null) {
              widget.onAssignAgent(selectedAgentId!);
            }
            if (selectedNgoId != null) {
              widget.onAssignNgo(selectedNgoId!);
            }
            Navigator.pop(context);
          },
          child: const Text('Assign'),
        ),
      ],
    );
  }
}
