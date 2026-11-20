import 'package:flutter/material.dart';

class PredictionUnavailableScreen extends StatelessWidget {
  const PredictionUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          Icons.auto_graph,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Prediction is not available yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'The previous sample-data estimate has been removed. This feature '
          'can be connected later to real student records and a validated '
          'prediction model or secure backend service.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
