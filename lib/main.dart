import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Entry point. Wraps the app in a [ProviderScope] for Riverpod.
void main() {
  runApp(
    const ProviderScope(
      child: HeatingPlannerApp(),
    ),
  );
}
