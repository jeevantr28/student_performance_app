import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'class_performance_dashboard_screen.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'prediction_unavailable_screen.dart';
import 'student_management_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const StudentPerformanceApp());
}

class StudentPerformanceApp extends StatelessWidget {
  const StudentPerformanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Student Performance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class Student {
  const Student({
    required this.id,
    required this.name,
    required this.course,
    required this.math,
    required this.science,
    required this.english,
    required this.attendance,
  });

  final String id;
  final String name;
  final String course;
  final double math;
  final double science;
  final double english;
  final double attendance;

  double get average => (math + science + english) / 3;

  bool get isAtRisk => average < 50 || attendance < 75;

  String get grade {
    if (average >= 85) return 'A';
    if (average >= 70) return 'B';
    if (average >= 55) return 'C';
    if (average >= 40) return 'D';
    return 'F';
  }
}

const students = <Student>[
  Student(
    id: 'STU001',
    name: 'Aarav Sharma',
    course: 'BCA - Semester 5',
    math: 88,
    science: 82,
    english: 90,
    attendance: 94,
  ),
  Student(
    id: 'STU002',
    name: 'Diya Patel',
    course: 'BCA - Semester 5',
    math: 76,
    science: 81,
    english: 72,
    attendance: 88,
  ),
  Student(
    id: 'STU003',
    name: 'Kabir Singh',
    course: 'BCA - Semester 5',
    math: 48,
    science: 52,
    english: 45,
    attendance: 70,
  ),
  Student(
    id: 'STU004',
    name: 'Meera Nair',
    course: 'BCA - Semester 5',
    math: 92,
    science: 86,
    english: 89,
    attendance: 97,
  ),
  Student(
    id: 'STU005',
    name: 'Rohan Gupta',
    course: 'BCA - Semester 5',
    math: 61,
    science: 58,
    english: 65,
    attendance: 73,
  ),
];

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _titles = [
    'Class Performance',
    'Student Management',
    'Prediction',
  ];

  static const _screens = <Widget>[
    ClassPerformanceDashboardScreen(),
    StudentManagementScreen(),
    PredictionUnavailableScreen(),
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
       actions: [
  IconButton(
    tooltip: 'Logout',
    icon: const Icon(Icons.logout),
    onPressed: () async {
      await FirebaseAuth.instance.signOut();
    },
  ),
],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Students',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_graph_outlined),
            selectedIcon: Icon(Icons.auto_graph),
            label: 'Predict',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onStudentTap});

  final ValueChanged<Student> onStudentTap;

  @override
  Widget build(BuildContext context) {
    final average =
        students.map((student) => student.average).reduce((a, b) => a + b) /
        students.length;
    final attendance =
        students.map((student) => student.attendance).reduce((a, b) => a + b) /
        students.length;
    final atRisk = students.where((student) => student.isAtRisk).length;
    final topStudents = [...students]
      ..sort((a, b) => b.average.compareTo(a.average));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text('Here is a quick view of the current class performance.'),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      label: 'Students',
                      value: '${students.length}',
                      icon: Icons.people,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      label: 'Class average',
                      value: '${average.toStringAsFixed(1)}%',
                      icon: Icons.school,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      label: 'Attendance',
                      value: '${attendance.toStringAsFixed(1)}%',
                      icon: Icons.calendar_month,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      label: 'Need support',
                      value: '$atRisk',
                      icon: Icons.warning_amber,
                      isWarning: atRisk > 0,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Top performers', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: topStudents.take(3).map((student) {
                return StudentListTile(
                  student: student,
                  onTap: () => onStudentTap(student),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: atRisk == 0
                ? null
                : Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(atRisk == 0 ? Icons.check_circle : Icons.info_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      atRisk == 0
                          ? 'Every student is currently meeting the support threshold.'
                          : '$atRisk student${atRisk == 1 ? '' : 's'} may need extra support. Open Analysis for details.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.isWarning = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isWarning
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

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key, required this.onStudentTap});

  final ValueChanged<Student> onStudentTap;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase().trim();
    final filteredStudents = students.where((student) {
      return student.name.toLowerCase().contains(query) ||
          student.id.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search by name or ID',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: filteredStudents.isEmpty
              ? const Center(child: Text('No students match your search.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: filteredStudents.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    return Card(
                      child: StudentListTile(
                        student: student,
                        onTap: () => widget.onStudentTap(student),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class StudentListTile extends StatelessWidget {
  const StudentListTile({super.key, required this.student, this.onTap});

  final Student student;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final averageColor = student.isAtRisk
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(child: Text(student.name.substring(0, 1))),
      title: Text(student.name),
      subtitle: Text('${student.id} • ${student.course}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${student.average.toStringAsFixed(1)}%',
            style: TextStyle(color: averageColor, fontWeight: FontWeight.bold),
          ),
          Text(
            'Grade ${student.grade}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class StudentDetailScreen extends StatelessWidget {
  const StudentDetailScreen({super.key, required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 34,
                child: Text(
                  student.name.substring(0, 1),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                student.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Center(child: Text('${student.id} • ${student.course}')),
            const SizedBox(height: 24),
            Text(
              'Academic record',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DetailMetric(
                    label: 'Mathematics',
                    value: '${student.math}%',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DetailMetric(
                    label: 'Science',
                    value: '${student.science}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DetailMetric(
                    label: 'English',
                    value: '${student.english}%',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DetailMetric(
                    label: 'Attendance',
                    value: '${student.attendance}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DetailMetric(
              label: 'Overall average',
              value:
                  '${student.average.toStringAsFixed(1)}%  •  Grade ${student.grade}',
            ),
            const SizedBox(height: 20),
            Card(
              color: student.isAtRisk
                  ? Theme.of(context).colorScheme.errorContainer
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  student.isAtRisk
                      ? 'Support recommended: this student has low marks or attendance below 75%.'
                      : 'This student is meeting the current academic and attendance thresholds.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailMetric extends StatelessWidget {
  const DetailMetric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final atRiskStudents = students
        .where((student) => student.isAtRisk)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Class performance',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'The bar shows each student\'s average across three subjects.',
        ),
        const SizedBox(height: 16),
        ...students.map((student) => PerformanceBar(student: student)),
        const SizedBox(height: 20),
        Text(
          'Students who may need support',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (atRiskStudents.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No students currently meet the support-warning criteria.',
              ),
            ),
          )
        else
          ...atRiskStudents.map(
            (student) => Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber),
                title: Text(student.name),
                subtitle: Text(
                  'Average ${student.average.toStringAsFixed(1)}% • Attendance ${student.attendance.toStringAsFixed(0)}%',
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Current rule: show a support warning when the average is below 50% or attendance is below 75%. You can change these values later.',
        ),
      ],
    );
  }
}

class PerformanceBar extends StatelessWidget {
  const PerformanceBar({super.key, required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final color = student.isAtRisk
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  student.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('${student.average.toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: student.average / 100,
              minHeight: 10,
              borderRadius: BorderRadius.circular(6),
              color: color,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Attendance: ${student.attendance.toStringAsFixed(0)}%',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  String? _selectedStudentId;
  bool _showResult = false;

  @override
  Widget build(BuildContext context) {
    final selectedStudent = _selectedStudentId == null
        ? null
        : students.firstWhere((student) => student.id == _selectedStudentId);
    final predictedScore = selectedStudent == null
        ? 0
        : ((selectedStudent.average * 0.7 + selectedStudent.attendance * 0.3)
                  .round()
                  .clamp(0, 100))
              .toInt();
    final needsSupport =
        selectedStudent != null &&
        (selectedStudent.isAtRisk || predictedScore < 60);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_graph,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Prediction prototype',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'This is a transparent demonstration, not a machine-learning model. It combines current marks (70%) and attendance (30%).',
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _selectedStudentId,
            decoration: const InputDecoration(
              labelText: 'Choose a student',
              border: OutlineInputBorder(),
            ),
            items: students
                .map(
                  (student) => DropdownMenuItem<String>(
                    value: student.id,
                    child: Text('${student.name} (${student.id})'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _selectedStudentId = value;
              _showResult = false;
            }),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: selectedStudent == null
                  ? null
                  : () => setState(() => _showResult = true),
              icon: const Icon(Icons.calculate),
              label: const Text('Show demo estimate'),
            ),
          ),
          if (_showResult && selectedStudent != null) ...[
            const SizedBox(height: 24),
            Card(
              color: needsSupport
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Demo result for ${selectedStudent.name}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$predictedScore%',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      needsSupport
                          ? 'Current data suggests that early academic support may be helpful.'
                          : 'Current data suggests steady progress. Keep monitoring the student.',
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Later, this screen can send real student features to a trained ML model or a secure backend API.',
          ),
        ],
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Unable to check login status.')),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == null) {
          return const LoginScreen();
        }

        return const HomeShell();
      },
    );
  }
}
