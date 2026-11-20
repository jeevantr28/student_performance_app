import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AcademicPerformanceScreen extends StatelessWidget {
  final String studentUsn;

  const AcademicPerformanceScreen({super.key, required this.studentUsn});

  CollectionReference<Map<String, dynamic>> get subjects => FirebaseFirestore
      .instance
      .collection('students')
      .doc(studentUsn)
      .collection('academics');

  double percent(num obtained, num maximum) =>
      maximum <= 0 ? 0 : obtained / maximum * 100;

  Future<void> deleteSubject(BuildContext context, String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete subject?'),
        content: Text('Delete the academic record for $code?'),
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
      await subjects.doc(code).delete();
    } on FirebaseException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: ${e.message ?? e.code}')),
      );
    }
  }

  void openForm(BuildContext context, [Map<String, dynamic>? existing]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SubjectFormScreen(studentUsn: studentUsn, existing: existing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Academic Records - $studentUsn')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Subject'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: subjects.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load records. Check Firestore permissions.',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) => a.id.compareTo(b.id));

          if (docs.isEmpty) {
            return const Center(
              child: Text('No subjects yet. Tap Add Subject.'),
            );
          }

          final totalMarks = docs.fold<double>(
            0,
            (total, doc) => total + (doc.data()['marks'] as num),
          );

          final totalMaximum = docs.fold<double>(
            0,
            (total, doc) => total + (doc.data()['maxMarks'] as num),
          );

          final totalAttended = docs.fold<int>(
            0,
            (total, doc) => total + (doc.data()['attended'] as int),
          );

          final totalConducted = docs.fold<int>(
            0,
            (total, doc) => total + (doc.data()['conducted'] as int),
          );

          final overallMarks = percent(totalMarks, totalMaximum);
          final overallAttendance = percent(totalAttended, totalConducted);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Performance Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Overall Marks: '
                        '${overallMarks.toStringAsFixed(1)}%',
                      ),
                      LinearProgressIndicator(
                        value: overallMarks / 100,
                        minHeight: 8,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        totalConducted == 0
                            ? 'Overall Attendance: Not available'
                            : 'Overall Attendance: '
                                  '${overallAttendance.toStringAsFixed(1)}%',
                      ),
                      LinearProgressIndicator(
                        value: totalConducted == 0
                            ? 0
                            : overallAttendance / 100,
                        minHeight: 8,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Subject-wise Marks (%)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 240,
                child: BarChart(
                  BarChartData(
                    minY: 0,
                    maxY: 100,
                    alignment: BarChartAlignment.spaceAround,
                    barGroups: [
                      for (int i = 0; i < docs.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: percent(
                                docs[i].data()['marks'] as num,
                                docs[i].data()['maxMarks'] as num,
                              ),
                              width: 16,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                    ],
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();

                            if (i < 0 ||
                                i >= docs.length ||
                                i.toDouble() != value) {
                              return const SizedBox.shrink();
                            }

                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                (i + 1).toString(),
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Text(
                'Chart labels correspond to the numbered '
                'subjects listed below.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text(
                'Subject Records',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              for (int i = 0; i < docs.length; i++)
                Builder(
                  builder: (context) {
                    final data = docs[i].data();
                    final marks = percent(
                      data['marks'] as num,
                      data['maxMarks'] as num,
                    );
                    final conducted = data['conducted'] as int;
                    final attendance = percent(
                      data['attended'] as num,
                      conducted,
                    );
                    final lowMarks = marks < 40;
                    final lowAttendance = conducted > 0 && attendance < 75;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}. ${data['subjectName']} '
                              '(${docs[i].id})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Marks: ${data['marks']}/'
                              '${data['maxMarks']} '
                              '(${marks.toStringAsFixed(1)}%)',
                            ),
                            Text(
                              conducted == 0
                                  ? 'Attendance: Not available'
                                  : 'Attendance: ${data['attended']}/'
                                        '$conducted '
                                        '(${attendance.toStringAsFixed(1)}%)',
                            ),
                            if (lowMarks || lowAttendance)
                              Text(
                                [
                                  if (lowMarks) 'Low marks',
                                  if (lowAttendance) 'Low attendance',
                                ].join(' • '),
                                style: const TextStyle(
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () => openForm(context, {
                                    ...data,
                                    'subjectCode': docs[i].id,
                                  }),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit'),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      deleteSubject(context, docs[i].id),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class SubjectFormScreen extends StatefulWidget {
  final String studentUsn;
  final Map<String, dynamic>? existing;

  const SubjectFormScreen({super.key, required this.studentUsn, this.existing});

  @override
  State<SubjectFormScreen> createState() => _SubjectFormScreenState();
}

class _SubjectFormScreenState extends State<SubjectFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController code;
  late final TextEditingController name;
  late final TextEditingController marks;
  late final TextEditingController maxMarks;
  late final TextEditingController attended;
  late final TextEditingController conducted;

  bool saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existing ?? {};

    code = TextEditingController(text: data['subjectCode']?.toString() ?? '');
    name = TextEditingController(text: data['subjectName']?.toString() ?? '');
    marks = TextEditingController(text: data['marks']?.toString() ?? '');
    maxMarks = TextEditingController(
      text: data['maxMarks']?.toString() ?? '50',
    );
    attended = TextEditingController(text: data['attended']?.toString() ?? '0');
    conducted = TextEditingController(
      text: data['conducted']?.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    for (final controller in [
      code,
      name,
      marks,
      maxMarks,
      attended,
      conducted,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget field(
    String label,
    TextEditingController controller, {
    bool numeric = false,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          if (numeric && int.tryParse(value.trim()) == null) {
            return 'Enter a whole number';
          }
          return null;
        },
      ),
    );
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;

    final obtained = int.parse(marks.text.trim());
    final maximum = int.parse(maxMarks.text.trim());
    final present = int.parse(attended.text.trim());
    final total = int.parse(conducted.text.trim());
    final subjectCode = code.text.trim().toUpperCase();

    if (!RegExp(r'^[A-Z0-9_-]{1,30}$').hasMatch(subjectCode) ||
        name.text.trim().length > 100 ||
        maximum <= 0 ||
        maximum > 1000 ||
        obtained < 0 ||
        obtained > maximum ||
        present < 0 ||
        total < 0 ||
        total > 1000 ||
        present > total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check the subject code, marks and attendance.'),
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final ref = FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentUsn)
          .collection('academics')
          .doc(subjectCode);

      final data = {
        'subjectCode': subjectCode,
        'subjectName': name.text.trim(),
        'marks': obtained,
        'maxMarks': maximum,
        'attended': present,
        'conducted': total,
      };

      if (widget.existing != null) {
        await ref.update(data);
      } else {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final existing = await transaction.get(ref);
          if (existing.exists) {
            throw Exception('Subject code already exists.');
          }
          transaction.set(ref, data);
        });
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to save subject: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Subject' : 'Edit Subject'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            field('Subject Code', code, enabled: widget.existing == null),
            field('Subject Name', name),
            field('Marks Obtained', marks, numeric: true),
            field('Maximum Marks', maxMarks, numeric: true),
            field('Classes Attended', attended, numeric: true),
            field('Classes Conducted', conducted, numeric: true),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Saving...' : 'Save Subject'),
            ),
          ],
        ),
      ),
    );
  }
}
