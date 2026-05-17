import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/floor.dart';
import '../../data/models/project.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/app_preferences.dart';
import '../../repositories/building_repository.dart';
import '../../repositories/project_repository.dart';
import 'editor_screen.dart';

/// Entry screen showing all saved projects as a card grid.
///
/// Follows UI/UX §4.1 wireframe: 3–4 columns on desktop,
/// 2 columns on tablet, empty-state prompt when no projects exist.
class ProjectListScreen extends ConsumerWidget {
  /// Creates a [ProjectListScreen].
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          Padding(
            padding:
                const EdgeInsets.only(right: Spacing.md),
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.newProject),
              onPressed: () =>
                  _showNewProjectDialog(context, ref),
            ),
          ),
        ],
      ),
      body: projectsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            l10n.errorLoadingProjects(e.toString()),
          ),
        ),
        data: (projects) => projects.isEmpty
            ? _EmptyState(
                onNewProject: () =>
                    _showNewProjectDialog(context, ref),
              )
            : _ProjectGrid(projects: projects),
      ),
    );
  }

  Future<void> _showNewProjectDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<Project>(
      context: context,
      builder: (ctx) => const _NewProjectDialog(),
    );
    if (result == null) return;
    final dao = ref.read(projectDaoProvider);
    await upsertProject(dao, result);
    final buildingDao = ref.read(buildingDaoProvider);
    final floor = Floor(
      id: IdGenerator.newId(),
      name: l10n.defaultFloorName,
    );
    await upsertFloor(buildingDao, floor, result.id);
    unawaited(
      ref
          .read(lastOpenedProjectIdProvider.notifier)
          .set(result.id),
    );
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EditorScreen(projectId: result.id),
      ),
    );
  }
}

// ── Grid ──────────────────────────────────────────────────────────────────────

class _ProjectGrid extends StatelessWidget {
  const _ProjectGrid({required this.projects});

  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // 2 columns on tablet (< 600), 3 on medium, 4 on wide.
    final crossAxisCount = width < 600
        ? 2
        : width < 1100
            ? 3
            : 4;

    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: GridView.builder(
        gridDelegate:
            SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: Spacing.md,
          crossAxisSpacing: Spacing.md,
          childAspectRatio: 1.1,
        ),
        itemCount: projects.length,
        itemBuilder: (ctx, i) =>
            _ProjectCard(project: projects[i]),
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context)
        .extension<HeatingPlannerColors>()!;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () => _openProject(context, ref),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openProject(context, ref),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              // Thumbnail placeholder
              Expanded(
                child: Container(
                  color: colors.gridLine,
                  child: Icon(
                    Icons.home_work_outlined,
                    size: 48,
                    color: colors.wallFill,
                  ),
                ),
              ),
              // Footer with name + date + context menu
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: Spacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            style:
                                theme.textTheme.titleSmall,
                            overflow:
                                TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _relativeDate(
                              project.modifiedAt,
                              l10n,
                            ),
                            style: theme
                                .textTheme.bodySmall
                                ?.copyWith(
                              color: theme.colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ContextMenuButton(project: project),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProject(BuildContext context, WidgetRef ref) {
    unawaited(
      ref
          .read(lastOpenedProjectIdProvider.notifier)
          .set(project.id),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EditorScreen(projectId: project.id),
      ),
    );
  }

  static String _relativeDate(
    DateTime dt,
    AppLocalizations l10n,
  ) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.relativeJustNow;
    if (diff.inHours < 1) {
      return l10n.relativeMinutesAgo(diff.inMinutes);
    }
    if (diff.inDays < 1) {
      return l10n.relativeHoursAgo(diff.inHours);
    }
    if (diff.inDays < 7) {
      return l10n.relativeDaysAgo(diff.inDays);
    }
    if (diff.inDays < 30) {
      return l10n.relativeWeeksAgo(
        (diff.inDays / 7).round(),
      );
    }
    if (diff.inDays < 365) {
      return l10n.relativeMonthsAgo(
        (diff.inDays / 30).round(),
      );
    }
    return l10n.relativeYearsAgo(
      (diff.inDays / 365).round(),
    );
  }
}

// ── Context menu ──────────────────────────────────────────────────────────────

class _ContextMenuButton extends ConsumerWidget {
  const _ContextMenuButton({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<_CardAction>(
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (action) =>
          _handleAction(context, ref, action),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _CardAction.duplicate,
          child: Text(l10n.duplicateAction),
        ),
        PopupMenuItem(
          value: _CardAction.delete,
          child: Text(l10n.delete),
        ),
      ],
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _CardAction action,
  ) async {
    switch (action) {
      case _CardAction.duplicate:
        await _duplicate(context, ref);
      case _CardAction.delete:
        await _confirmDelete(context, ref);
    }
  }

  Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final copy = project.copyWith(
      id: IdGenerator.newId(),
      name: l10n.projectCopyName(project.name),
      createdAt: now,
      modifiedAt: now,
    );
    final dao = ref.read(projectDaoProvider);
    await upsertProject(dao, copy);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteProjectTitle),
        content: Text(
          l10n.deleteProjectContent(project.name),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () =>
                Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final dao = ref.read(projectDaoProvider);
    await deleteProject(dao, project.id);
  }
}

enum _CardAction { duplicate, delete }

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNewProject});

  final VoidCallback onNewProject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.home_work_outlined,
            size: 80,
            color: theme.colorScheme.onSurface
                .withValues(alpha: 0.3),
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            l10n.noProjectsYet,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.createFirstProject,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xl),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l10n.newProject),
            onPressed: onNewProject,
          ),
        ],
      ),
    );
  }
}

// ── New project dialog ────────────────────────────────────────────────────────

class _NewProjectDialog extends StatefulWidget {
  const _NewProjectDialog();

  @override
  State<_NewProjectDialog> createState() =>
      _NewProjectDialogState();
}

class _NewProjectDialogState
    extends State<_NewProjectDialog> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double _outdoorTempC = -12.0;
  double _indoorTempC = 20.0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.newProject),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.projectNameLabel,
                  hintText: l10n.projectNameHint,
                ),
                autofocus: true,
                textCapitalization:
                    TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l10n.nameIsRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: Spacing.lg),
              _TempSliderRow(
                label: l10n.designOutdoorTemperature,
                value: _outdoorTempC,
                min: -30.0,
                max: 10.0,
                onChanged: (v) =>
                    setState(() => _outdoorTempC = v),
              ),
              const SizedBox(height: Spacing.md),
              _TempSliderRow(
                label: l10n.defaultIndoorTemperature,
                value: _indoorTempC,
                min: 15.0,
                max: 30.0,
                onChanged: (v) =>
                    setState(() => _indoorTempC = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.create),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final project = Project(
      id: IdGenerator.newId(),
      name: _nameController.text.trim(),
      createdAt: now,
      modifiedAt: now,
      designOutdoorTempC: _outdoorTempC,
      defaultIndoorTempC: _indoorTempC,
    );
    Navigator.of(context).pop(project);
  }
}

/// Labelled slider row for a temperature field.
class _TempSliderRow extends StatelessWidget {
  const _TempSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              '${value.round()} °C',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          label: '${value.round()} °C',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
