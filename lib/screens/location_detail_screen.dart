
import 'package:flutter/material.dart';
import 'package:travellog/models/travel_location.dart';
import 'package:travellog/services/firestore_service.dart';
import 'package:travellog/models/location_group.dart';

class LocationDetailScreen extends StatefulWidget {
  final TravelLocation location;

  const LocationDetailScreen({super.key, required this.location});

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final _needsController = TextEditingController();

  late String _notes;
  late int _estimatedDuration;
  late List<String> _needsList;
  late String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _notes = widget.location.notes ?? '';
    _estimatedDuration = widget.location.estimatedDuration ?? 0;
    _needsList = List<String>.from(widget.location.needsList ?? []);
    _selectedGroupId = widget.location.groupId;
  }

  @override
  void dispose() {
    _needsController.dispose();
    super.dispose();
  }

  void _saveForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final updatedLocation = TravelLocation(
        firestoreId: widget.location.firestoreId,
        name: widget.location.name, // Name and other core properties are not editable here
        description: widget.location.description,
        latitude: widget.location.latitude,
        longitude: widget.location.longitude,
        groupId: _selectedGroupId,
        notes: _notes,
        estimatedDuration: _estimatedDuration,
        needsList: _needsList,
      );

      if (widget.location.firestoreId != null) {
        await _firestoreService.updateLocation(widget.location.firestoreId!, updatedLocation);
      }
      
      Navigator.of(context).pop();
    }
  }

  void _addNeed() {
    if (_needsController.text.isNotEmpty) {
      setState(() {
        _needsList.add(_needsController.text);
        _needsController.clear();
      });
    }
  }

  void _removeNeed(int index) {
    setState(() {
      _needsList.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.location.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveForm,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                initialValue: _notes,
                decoration: const InputDecoration(
                  labelText: 'Özel Notlar',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onSaved: (value) {
                  _notes = value ?? '';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _estimatedDuration.toString(),
                decoration: const InputDecoration(
                  labelText: 'Tahmini Kalma Süresi (dakika)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (int.tryParse(value ?? '') == null) {
                    return 'Lütfen geçerli bir sayı girin.';
                  }
                  return null;
                },
                onSaved: (value) {
                  _estimatedDuration = int.tryParse(value ?? '0') ?? 0;
                },
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<LocationGroup>>(
                stream: _firestoreService.getGroups(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var groups = snapshot.data!;
                  return DropdownButtonFormField<String>(
                    value: _selectedGroupId,
                    decoration: const InputDecoration(
                      labelText: 'Grup',
                      border: OutlineInputBorder(),
                    ),
                    items: groups.map((group) {
                      return DropdownMenuItem<String>(
                        value: group.firestoreId,
                        child: Text(group.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedGroupId = value;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('İhtiyaç Listesi', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _needsList.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      title: Text(_needsList[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeNeed(index),
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _needsController,
                        decoration: const InputDecoration(
                          labelText: 'Yeni ihtiyaç ekle',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.green),
                      onPressed: _addNeed,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
