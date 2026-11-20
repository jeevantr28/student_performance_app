import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'academic_performance_screen.dart';

// Separate from your existing Phase 2 Student class.
class StudentRecord {
  final String usn;
  final String name;
  final String course;
  final int semester;
  final String section;

  const StudentRecord({
    required this.usn,
    required this.name,
    required this.course,
    required this.semester,
    required this.section,
  });

  factory StudentRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    return StudentRecord(
      usn: doc.id,
      name: data['name'] as String? ?? '',
      course: data['course'] as String? ?? '',
      semester: (data['semester'] as num?)?.toInt() ?? 1,
      section: data['section'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usn': usn,
      'name': name,
      'course': course,
      'semester': semester,
      'section': section,
    };
  }
}

// Database operations
class StudentRepository {
  final CollectionReference<Map<String, dynamic>> _students = FirebaseFirestore
      .instance
      .collection('students');

  Stream<List<StudentRecord>> watchStudents() {
    return _students.snapshots().map((snapshot) {
      final records = snapshot.docs.map(StudentRecord.fromFirestore).toList();

      records.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      return records;
    });
  }

  Future<void> add(StudentRecord student) async {
    final ref = _students.doc(student.usn);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final existing = await transaction.get(ref);

      if (existing.exists) {
        throw Exception('A student with this USN already exists.');
      }

      transaction.set(ref, student.toMap());
    });
  }

  Future<void> update(StudentRecord student) async {
    await _students.doc(student.usn).update(student.toMap());
  }

  Future<void> delete(String usn) async {
    await _students.doc(usn).delete();
  }
}

// Student list screen
class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  final StudentRepository _repository = StudentRepository();
  String _search = '';

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openForm([StudentRecord? student]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StudentFormScreen(repository: _repository, existing: student),
      ),
    );

    if (result == true) {
      _showMessage(
        student == null
            ? 'Student added successfully.'
            : 'Student updated successfully.',
      );
    }
  }

  Future<void> _deleteStudent(StudentRecord student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete student?'),
        content: Text(
          'Delete ${student.name} (${student.usn})? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repository.delete(student.usn);
      _showMessage('Student deleted successfully.');
    } on FirebaseException catch (e) {
      _showMessage('Delete failed: ${e.message ?? e.code}');
    } catch (_) {
      _showMessage('Unable to delete student.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Records')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() => _search = value.toLowerCase().trim());
              },
              decoration: const InputDecoration(
                hintText: 'Search by name, USN, or course',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<StudentRecord>>(
              stream: _repository.watchStudents(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final error = snapshot.error;

                  final message =
                      error is FirebaseException &&
                          error.code == 'permission-denied'
                      ? 'Access denied. Check faculty authorization '
                            'and Firestore rules.'
                      : 'Unable to load student records.';

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(message, textAlign: TextAlign.center),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filtered = snapshot.data!.where((student) {
                  return student.name.toLowerCase().contains(_search) ||
                      student.usn.toLowerCase().contains(_search) ||
                      student.course.toLowerCase().contains(_search);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _search.isEmpty
                          ? 'No students yet. Tap Add Student.'
                          : 'No matching students found.',
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final student = filtered[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(student.name),
                        subtitle: Text(
                          '${student.usn}\n'
                          '${student.course} • '
                          'Sem ${student.semester} • '
                          'Section ${student.section}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'academics') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AcademicPerformanceScreen(
                                    studentUsn: student.usn,
                                  ),
                                ),
                              );
                            } else if (value == 'edit') {
                              _openForm(student);
                            } else if (value == 'delete') {
                              _deleteStudent(student);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                            PopupMenuItem(
                              value: 'academics',
                              child: Text('Academic Records'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Add and edit student form
class StudentFormScreen extends StatefulWidget {
  final StudentRepository repository;
  final StudentRecord? existing;

  const StudentFormScreen({super.key, required this.repository, this.existing});

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _usn;
  late final TextEditingController _name;
  late final TextEditingController _course;
  late final TextEditingController _section;

  int _semester = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final student = widget.existing;

    _usn = TextEditingController(text: student?.usn ?? '');
    _name = TextEditingController(text: student?.name ?? '');
    _course = TextEditingController(text: student?.course ?? '');
    _section = TextEditingController(text: student?.section ?? '');
    _semester = student?.semester ?? 1;
  }

  @override
  void dispose() {
    _usn.dispose();
    _name.dispose();
    _course.dispose();
    _section.dispose();
    super.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool enabled = true,
    int maxLength = 100,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final student = StudentRecord(
      usn: _usn.text.trim().toUpperCase(),
      name: _name.text.trim(),
      course: _course.text.trim(),
      semester: _semester,
      section: _section.text.trim().toUpperCase(),
    );

    try {
      if (widget.existing == null) {
        await widget.repository.add(student);
      } else {
        await widget.repository.update(student);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      final message = e is FirebaseException
          ? (e.message ?? e.code)
          : e.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Student' : 'Add Student')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field(_usn, 'Student USN', enabled: !editing, maxLength: 30),
            _field(_name, 'Full Name'),
            _field(_course, 'Course', maxLength: 60),
            DropdownButtonFormField<int>(
              initialValue: _semester,
              decoration: const InputDecoration(
                labelText: 'Semester',
                border: OutlineInputBorder(),
              ),
              items: List.generate(
                8,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('Semester ${index + 1}'),
                ),
              ),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _semester = value);
                      }
                    },
            ),
            const SizedBox(height: 14),
            _field(_section, 'Section', maxLength: 20),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'Saving...' : 'Save Student'),
            ),
          ],
        ),
      ),
    );
  }
}
