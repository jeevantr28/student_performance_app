import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A live, faculty-facing class dashboard for this existing Firestore shape:
///
/// students/{usn}
/// students/{usn}/academics/{subjectCode}
///
/// It joins the live `students` and collection-group `academics` streams in
/// memory. That means no new fields need to be added to existing records.
class ClassPerformanceDashboardScreen extends StatefulWidget {
  const ClassPerformanceDashboardScreen({super.key});

  @override
  State<ClassPerformanceDashboardScreen> createState() =>
      _ClassPerformanceDashboardScreenState();
}

class _ClassPerformanceDashboardScreenState
    extends State<ClassPerformanceDashboardScreen> {
  static const String _all = 'All';

  String _course = _all;
  String _semester = _all;
  String _section = _all;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('students').snapshots(),
      builder: (context, studentSnapshot) {
        if (studentSnapshot.hasError) {
          return _DashboardMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Unable to load students',
            message: 'Check the signed-in faculty account and Firestore rules.',
            onRetry: () => setState(() {}),
          );
        }

        if (!studentSnapshot.hasData) {
          return const _DashboardLoading(label: 'Loading student records…');
        }

        final students = studentSnapshot.data!.docs.toList()
          ..sort(
            (first, second) =>
                _studentName(first.data())
                    .compareTo(_studentName(second.data())),
          );

        final courseOptions = _uniqueSorted(
          students.map((student) => _text(student.data()['course'])),
        );
        final selectedCourse = courseOptions.contains(_course) ? _course : _all;

        final courseStudents = students.where(
          (student) =>
              selectedCourse == _all ||
              _text(student.data()['course']) == selectedCourse,
        );
        final semesterOptions = _uniqueSorted(
          courseStudents.map((student) => _text(student.data()['semester'])),
          semesterFirst: true,
        );
        final selectedSemester = semesterOptions.contains(_semester)
            ? _semester
            : _all;

        final courseSemesterStudents = courseStudents.where(
          (student) =>
              selectedSemester == _all ||
              _text(student.data()['semester']) == selectedSemester,
        );
        final sectionOptions = _uniqueSorted(
          courseSemesterStudents.map(
            (student) => _text(student.data()['section']),
          ),
        );
        final selectedSection = sectionOptions.contains(_section)
            ? _section
            : _all;

        final selectedStudents = courseSemesterStudents
            .where(
              (student) =>
                  selectedSection == _all ||
                  _text(student.data()['section']) == selectedSection,
            )
            .toList();

        return _LiveAcademicDashboard(
          students: selectedStudents,
          courseOptions: courseOptions,
          semesterOptions: semesterOptions,
          sectionOptions: sectionOptions,
          selectedCourse: selectedCourse,
          selectedSemester: selectedSemester,
          selectedSection: selectedSection,
          onCourseChanged: (value) => setState(() {
            _course = value;
            _semester = _all;
            _section = _all;
          }),
          onSemesterChanged: (value) => setState(() {
            _semester = value;
            _section = _all;
          }),
          onSectionChanged: (value) => setState(() => _section = value),
        );
      },
    );
  }
}

class _LiveAcademicDashboard extends StatelessWidget {
  const _LiveAcademicDashboard({
    required this.students,
    required this.courseOptions,
    required this.semesterOptions,
    required this.sectionOptions,
    required this.selectedCourse,
    required this.selectedSemester,
    required this.selectedSection,
    required this.onCourseChanged,
    required this.onSemesterChanged,
    required this.onSectionChanged,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> students;
  final List<String> courseOptions;
  final List<String> semesterOptions;
  final List<String> sectionOptions;
  final String selectedCourse;
  final String selectedSemester;
  final String selectedSection;
  final ValueChanged<String> onCourseChanged;
  final ValueChanged<String> onSemesterChanged;
  final ValueChanged<String> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    // No where() or orderBy() is used here, so Firestore does not need a
    // composite index. The selected class is joined on the client because the
    // course/semester/section values live on the parent student document.
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collectionGroup('academics')
          .snapshots(),
      builder: (context, academicSnapshot) {
        final filters = _ClassFilters(
          courseOptions: courseOptions,
          semesterOptions: semesterOptions,
          sectionOptions: sectionOptions,
          selectedCourse: selectedCourse,
          selectedSemester: selectedSemester,
          selectedSection: selectedSection,
          onCourseChanged: onCourseChanged,
          onSemesterChanged: onSemesterChanged,
          onSectionChanged: onSectionChanged,
        );

        if (academicSnapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              filters,
              const SizedBox(height: 16),
              const _DashboardMessageCard(
                icon: Icons.lock_outline,
                title: 'Unable to load academic records',
                message: 'Confirm that the nested academics rule allows approved faculty to read.',
              ),
            ],
          );
        }

        if (!academicSnapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              filters,
              const SizedBox(height: 28),
              const _DashboardLoading(label: 'Calculating class performance…'),
            ],
          );
        }

        final selectedStudentIds = students
            .map((student) => student.id)
            .toSet();
        final academicDocuments = academicSnapshot.data!.docs.where((document) {
          final parentStudentId = document.reference.parent.parent?.id;
          return parentStudentId != null &&
              selectedStudentIds.contains(parentStudentId);
        }).toList();
        final metrics = _ClassMetrics.fromDocuments(
          students,
          academicDocuments,
        );

        return _DashboardResults(filters: filters, metrics: metrics);
      },
    );
  }
}

class _DashboardResults extends StatelessWidget {
  const _DashboardResults({required this.filters, required this.metrics});

  final Widget filters;
  final _ClassMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        filters,
        const SizedBox(height: 20),
        Text(
          'Live class summary',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Updates automatically when student or academic records change.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        _MetricGrid(metrics: metrics),
        const SizedBox(height: 20),
        if (metrics.studentCount == 0)
          const _DashboardMessageCard(
            icon: Icons.people_outline,
            title: 'No students match this class',
            message: 'Change a filter or add student records first.',
          )
        else if (metrics.studentsWithValidAcademicData == 0)
          const _DashboardMessageCard(
            icon: Icons.menu_book_outlined,
            title: 'No valid academic data yet',
            message: 'Add a subject with maxMarks greater than zero or conducted classes greater than zero.',
          )
        else ...[
          _SubjectChart(subjects: metrics.subjects),
          const SizedBox(height: 20),
          _SubjectSummary(subjects: metrics.subjects),
          const SizedBox(height: 20),
          _SupportStudents(students: metrics.atRiskStudents),
        ],
        if (metrics.studentsWithoutAcademicData > 0) ...[
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${metrics.studentsWithoutAcademicData} student${metrics.studentsWithoutAcademicData == 1 ? '' : 's'} '
                'have no usable marks or attendance values and are excluded from percentage and support calculations.',
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ClassFilters extends StatelessWidget {
  const _ClassFilters({
    required this.courseOptions,
    required this.semesterOptions,
    required this.sectionOptions,
    required this.selectedCourse,
    required this.selectedSemester,
    required this.selectedSection,
    required this.onCourseChanged,
    required this.onSemesterChanged,
    required this.onSectionChanged,
  });

  final List<String> courseOptions;
  final List<String> semesterOptions;
  final List<String> sectionOptions;
  final String selectedCourse;
  final String selectedSemester;
  final String selectedSection;
  final ValueChanged<String> onCourseChanged;
  final ValueChanged<String> onSemesterChanged;
  final ValueChanged<String> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a class',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final useColumn = constraints.maxWidth < 620;
                final fields = [
                  _FilterDropDown(
                    label: 'Course',
                    value: selectedCourse,
                    allLabel: 'All courses',
                    options: courseOptions,
                    onChanged: onCourseChanged,
                  ),
                  _FilterDropDown(
                    label: 'Semester',
                    value: selectedSemester,
                    allLabel: 'All semesters',
                    options: semesterOptions,
                    onChanged: onSemesterChanged,
                  ),
                  _FilterDropDown(
                    label: 'Section',
                    value: selectedSection,
                    allLabel: 'All sections',
                    options: sectionOptions,
                    onChanged: onSectionChanged,
                  ),
                ];

                if (useColumn) {
                  return Column(
                    children: [
                      fields[0],
                      const SizedBox(height: 12),
                      fields[1],
                      const SizedBox(height: 12),
                      fields[2],
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 12),
                    Expanded(child: fields[1]),
                    const SizedBox(width: 12),
                    Expanded(child: fields[2]),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropDown extends StatelessWidget {
  const _FilterDropDown({
    required this.label,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String allLabel;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(value: 'All', child: Text(allLabel)),
        ...options.map(
          (option) => DropdownMenuItem(value: option, child: Text(option)),
        ),
      ],
      onChanged: (newValue) {
        if (newValue != null) onChanged(newValue);
      },
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final _ClassMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _MetricCard(
                icon: Icons.people_outline,
                label: 'Students',
                value: '${metrics.studentCount}',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _MetricCard(
                icon: Icons.school_outlined,
                label: 'Class marks',
                value: _percentage(metrics.classMarksPercentage),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _MetricCard(
                icon: Icons.calendar_month_outlined,
                label: 'Attendance',
                value: _percentage(metrics.classAttendancePercentage),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _MetricCard(
                icon: Icons.warning_amber_rounded,
                label: 'Need support',
                value: '${metrics.atRiskStudents.length}',
                warning: metrics.atRiskStudents.isNotEmpty,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SubjectChart extends StatelessWidget {
  const _SubjectChart({required this.subjects});

  final List<_SubjectTotals> subjects;

  @override
  Widget build(BuildContext context) {
    final chartSubjects = subjects
        .where((subject) => subject.marksPercentage != null)
        .take(8)
        .toList();
    if (chartSubjects.isEmpty) {
      return const _DashboardMessageCard(
        icon: Icons.bar_chart_outlined,
        title: 'No subject marks to chart',
        message: 'Each subject needs maxMarks greater than zero.',
      );
    }

    final chartColor = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subject-wise class marks',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              chartSubjects.length < subjects.length
                  ? 'Showing the first 8 subjects by code.'
                  : 'Total obtained marks ÷ total maximum marks.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: 100,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 38,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= chartSubjects.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              chartSubjects[index].code,
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(chartSubjects.length, (index) {
                    final percentage =
                        chartSubjects[index].marksPercentage ?? 0;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: percentage,
                          width: 18,
                          color: chartColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectSummary extends StatelessWidget {
  const _SubjectSummary({required this.subjects});

  final List<_SubjectTotals> subjects;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Subject summary', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...subjects.map(
          (subject) => Card(
            child: ListTile(
              title: Text('${subject.code} — ${subject.name}'),
              subtitle: Text(
                'Marks: ${_percentage(subject.marksPercentage)}  •  '
                'Attendance: ${_percentage(subject.attendancePercentage)}',
              ),
              trailing: SizedBox(
                width: 62,
                child: LinearProgressIndicator(
                  value: _progress(subject.marksPercentage),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SupportStudents extends StatelessWidget {
  const _SupportStudents({required this.students});

  final List<_StudentTotals> students;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Students who may need support',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (students.isEmpty)
          const _DashboardMessageCard(
            icon: Icons.check_circle_outline,
            title: 'No current support warning',
            message: 'Warnings appear below 50% marks or below 75% attendance.',
          )
        else
          ...students.map(
            (student) => Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: Text(student.name),
                subtitle: Text(
                  'Marks: ${_percentage(student.marksPercentage)}  •  '
                  'Attendance: ${_percentage(student.attendancePercentage)}',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _DashboardMessageCard(
          icon: icon,
          title: title,
          message: message,
          action: onRetry == null
              ? null
              : OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
        ),
      ),
    );
  }
}

class _DashboardMessageCard extends StatelessWidget {
  const _DashboardMessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(message),
                  if (action != null) ...[const SizedBox(height: 12), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassMetrics {
  const _ClassMetrics({
    required this.studentCount,
    required this.studentsWithValidAcademicData,
    required this.studentsWithoutAcademicData,
    required this.classMarksPercentage,
    required this.classAttendancePercentage,
    required this.subjects,
    required this.atRiskStudents,
  });

  static const minimumMarksPercentage = 50.0;
  static const minimumAttendancePercentage = 75.0;

  final int studentCount;
  final int studentsWithValidAcademicData;
  final int studentsWithoutAcademicData;
  final double? classMarksPercentage;
  final double? classAttendancePercentage;
  final List<_SubjectTotals> subjects;
  final List<_StudentTotals> atRiskStudents;

  factory _ClassMetrics.fromDocuments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> students,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> academicDocuments,
  ) {
    final studentTotals = <String, _StudentTotals>{
      for (final student in students)
        student.id: _StudentTotals(name: _studentName(student.data())),
    };
    final subjectTotals = <String, _SubjectTotals>{};

    var totalMarks = 0.0;
    var totalMaximum = 0.0;
    var totalAttended = 0.0;
    var totalConducted = 0.0;

    for (final document in academicDocuments) {
      final studentId = document.reference.parent.parent?.id;
      final student = studentId == null ? null : studentTotals[studentId];
      if (student == null) continue;

      final data = document.data();
      final subjectCode = _text(data['subjectCode']).isEmpty
          ? document.id
          : _text(data['subjectCode']);
      final subjectName = _text(data['subjectName']).isEmpty
          ? subjectCode
          : _text(data['subjectName']);
      final subject = subjectTotals.putIfAbsent(
        subjectCode,
        () => _SubjectTotals(code: subjectCode, name: subjectName),
      );

      final marks = _number(data['marks']);
      final maxMarks = _number(data['maxMarks']);
      if (marks != null && maxMarks != null && maxMarks > 0) {
        final safeMarks = marks.clamp(0, maxMarks).toDouble();
        student.marks += safeMarks;
        student.maxMarks += maxMarks;
        subject.marks += safeMarks;
        subject.maxMarks += maxMarks;
        totalMarks += safeMarks;
        totalMaximum += maxMarks;
      }

      final attended = _number(data['attended']);
      final conducted = _number(data['conducted']);
      if (attended != null && conducted != null && conducted > 0) {
        final safeAttended = attended.clamp(0, conducted).toDouble();
        student.attended += safeAttended;
        student.conducted += conducted;
        subject.attended += safeAttended;
        subject.conducted += conducted;
        totalAttended += safeAttended;
        totalConducted += conducted;
      }
    }

    final studentValues = studentTotals.values.toList()
      ..sort((first, second) => first.name.compareTo(second.name));
    final atRiskStudents = studentValues
        .where(
          (student) =>
              (student.marksPercentage != null &&
                  student.marksPercentage! < minimumMarksPercentage) ||
              (student.attendancePercentage != null &&
                  student.attendancePercentage! < minimumAttendancePercentage),
        )
        .toList();
    final orderedSubjects = subjectTotals.values.toList()
      ..sort((first, second) => first.code.compareTo(second.code));
    final studentsWithData = studentValues
        .where((student) => student.hasValidAcademicData)
        .length;

    return _ClassMetrics(
      studentCount: students.length,
      studentsWithValidAcademicData: studentsWithData,
      studentsWithoutAcademicData: students.length - studentsWithData,
      classMarksPercentage: _divideAsPercentage(totalMarks, totalMaximum),
      classAttendancePercentage: _divideAsPercentage(
        totalAttended,
        totalConducted,
      ),
      subjects: orderedSubjects,
      atRiskStudents: atRiskStudents,
    );
  }
}

class _StudentTotals {
  _StudentTotals({required this.name});

  final String name;
  double marks = 0;
  double maxMarks = 0;
  double attended = 0;
  double conducted = 0;

  double? get marksPercentage => _divideAsPercentage(marks, maxMarks);
  double? get attendancePercentage => _divideAsPercentage(attended, conducted);
  bool get hasValidAcademicData =>
      marksPercentage != null || attendancePercentage != null;
}

class _SubjectTotals {
  _SubjectTotals({required this.code, required this.name});

  final String code;
  final String name;
  double marks = 0;
  double maxMarks = 0;
  double attended = 0;
  double conducted = 0;

  double? get marksPercentage => _divideAsPercentage(marks, maxMarks);
  double? get attendancePercentage => _divideAsPercentage(attended, conducted);
}

String _studentName(Map<String, dynamic> data) {
  final name = _text(data['name']);
  return name.isEmpty ? 'Unnamed student' : name;
}

String _text(Object? value) => value?.toString().trim() ?? '';

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_text(value));
}

double? _divideAsPercentage(double numerator, double denominator) {
  if (denominator <= 0) return null;
  return numerator / denominator * 100;
}

double _progress(double? percentage) {
  if (percentage == null) return 0;
  return percentage.clamp(0, 100).toDouble() / 100;
}

String _percentage(double? value) =>
    value == null ? 'Not available' : '${value.toStringAsFixed(1)}%';

List<String> _uniqueSorted(
  Iterable<String> values, {
  bool semesterFirst = false,
}) {
  final result = values.where((value) => value.isNotEmpty).toSet().toList();
  result.sort((first, second) {
    if (semesterFirst) {
      final firstNumber = int.tryParse(first);
      final secondNumber = int.tryParse(second);
      if (firstNumber != null && secondNumber != null) {
        return firstNumber.compareTo(secondNumber);
      }
    }
    return first.compareTo(second);
  });
  return result;
}
