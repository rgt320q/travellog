import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:travellog/models/location_group.dart';
import 'package:travellog/services/firestore_service.dart';
import 'package:travellog/screens/group_detail_screen.dart';

enum GroupSortBy { nameAsc, nameDesc, dateNewest, dateOldest }

class GroupsScreen extends StatefulWidget {
  final bool isForSelection;

  const GroupsScreen({super.key, this.isForSelection = false});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _groupNameController = TextEditingController();
  Color? _selectedColor;
  GroupSortBy _currentSortBy = GroupSortBy.dateNewest;

  final List<Color> _groupColors = [
    Colors.red, Colors.pink, Colors.purple, Colors.deepPurple, Colors.indigo,
    Colors.blue, Colors.lightBlue, Colors.cyan, Colors.teal, Colors.green,
    Colors.lightGreen, Colors.lime, Colors.yellow, Colors.amber, Colors.orange,
    Colors.deepOrange, Colors.brown, Colors.grey, Colors.blueGrey, Colors.black,
  ];

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  void _sortGroups(List<LocationGroup> groups) {
    switch (_currentSortBy) {
      case GroupSortBy.nameAsc:
        groups.sort((a, b) => a.name.compareTo(b.name));
        break;
      case GroupSortBy.nameDesc:
        groups.sort((a, b) => b.name.compareTo(a.name));
        break;
      case GroupSortBy.dateNewest:
        groups.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        break;
      case GroupSortBy.dateOldest:
        groups.sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
        break;
    }
  }

  void _showGroupDialog({LocationGroup? groupToEdit}) {
    _groupNameController.text = groupToEdit?.name ?? '';
    _selectedColor = groupToEdit != null ? Color(groupToEdit.color ?? Colors.blue.value) : Colors.blue;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(groupToEdit == null ? 'Yeni Grup Oluştur' : 'Grup Düzenle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _groupNameController,
                      decoration: const InputDecoration(hintText: 'Grup Adı'),
                      autofocus: true,
                    ),
                    const SizedBox(height: 20),
                    const Text('Grup Rengi Seçin:'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _groupColors.map((color) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedColor == color ? Colors.black : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _groupNameController.clear();
                    _selectedColor = null;
                  },
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_groupNameController.text.isNotEmpty) {
                      final group = LocationGroup(
                        firestoreId: groupToEdit?.firestoreId,
                        name: _groupNameController.text,
                        color: _selectedColor?.value,
                        createdAt: groupToEdit?.createdAt, // Preserve original creation date
                      );

                      if (groupToEdit == null) {
                        await _firestoreService.addGroup(group);
                      } else {
                        await _firestoreService.updateGroup(group.firestoreId!, group);
                      }

                      _groupNameController.clear();
                      _selectedColor = null;
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isForSelection ? 'Grup Seç' : 'Seyahat Grupları'),
        actions: [
          if (!widget.isForSelection)
            PopupMenuButton<GroupSortBy>(
              icon: const Icon(Icons.sort),
              onSelected: (GroupSortBy result) {
                setState(() {
                  _currentSortBy = result;
                });
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<GroupSortBy>>[
                const PopupMenuItem<GroupSortBy>(
                  value: GroupSortBy.nameAsc,
                  child: Text('Ada Göre (A-Z)'),
                ),
                const PopupMenuItem<GroupSortBy>(
                  value: GroupSortBy.nameDesc,
                  child: Text('Ada Göre (Z-A)'),
                ),
                const PopupMenuItem<GroupSortBy>(
                  value: GroupSortBy.dateNewest,
                  child: Text('Tarihe Göre (Yeni)'),
                ),
                const PopupMenuItem<GroupSortBy>(
                  value: GroupSortBy.dateOldest,
                  child: Text('Tarihe Göre (Eski)'),
                ),
              ],
            ),
        ],
      ),
      body: StreamBuilder<List<LocationGroup>>(
        stream: _firestoreService.getGroups(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Henüz bir grup oluşturulmamış.'));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
          }

          final groups = snapshot.data!;
          _sortGroups(groups);

          return AnimationLimiter(
            child: ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: ListTile(
                        leading: Icon(Icons.circle, color: Color(group.color ?? Colors.blue.value)),
                        title: Text(group.name),
                        trailing: widget.isForSelection
                            ? const Icon(Icons.arrow_forward_ios)
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {
                                      _showGroupDialog(groupToEdit: group);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () async {
                                      final bool? confirmDelete = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Grup Sil'),
                                          content: Text('\'${group.name}\' grubunu silmek istediğinizden emin misiniz? Bu gruba ait tüm konumlar da silinecektir.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: const Text('İptal'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: const Text('Sil'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmDelete == true) {
                                        await _firestoreService.deleteGroup(group.firestoreId!);
                                      }
                                    },
                                  ),
                                ],
                              ),
                        onTap: () {
                          if (widget.isForSelection) {
                            Navigator.of(context).pop({'id': group.firestoreId!, 'name': group.name});
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => GroupDetailScreen(
                                  groupId: group.firestoreId!,
                                  groupName: group.name,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGroupDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}