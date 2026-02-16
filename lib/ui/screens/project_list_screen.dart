import 'package:flutter/material.dart';

/// Screen that lists all saved projects and allows creating new ones.
class ProjectListScreen extends StatelessWidget {
  /// Creates a [ProjectListScreen].
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(frontend): implement project list with Riverpod.
    return const Scaffold(
      body: Center(child: Text('Projects')),
    );
  }
}
