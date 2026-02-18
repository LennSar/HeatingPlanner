import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'ui/screens/editor_screen.dart';

/// Root widget for the HeatingPlanner application.
///
/// Sets up [MaterialApp] with theming. Navigation will be replaced with
/// GoRouter once the screen set is stable.
class HeatingPlannerApp extends StatelessWidget {
  /// Creates the [HeatingPlannerApp].
  const HeatingPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HeatingPlanner',
      theme: AppTheme.light(),
      // TODO: restore ProjectListScreen as home.
      home: const EditorScreen(projectId: 'preview'),
      debugShowCheckedModeBanner: false,
    );
  }
}
