// Tests for AppLocalizations resolution and
// spot-checked translations.
//
// Uses the generated lookupAppLocalizations() function
// to instantiate locale-specific translations without
// a BuildContext.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/l10n/app_localizations.dart';

void main() {
  group('English locale', () {
    late AppLocalizations l10n;

    setUp(() {
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    test('simple getters', () {
      expect(l10n.appTitle, 'HeatingPlanner');
      expect(l10n.newProject, 'New Project');
      expect(l10n.cancel, 'Cancel');
      expect(l10n.toolWall, 'Wall');
      expect(l10n.menuFile, 'File');
    });

    test('parameterised messages', () {
      expect(
        l10n.errorLoadingProjects('timeout'),
        'Error loading projects: timeout',
      );
      expect(
        l10n.deleteProjectContent('Villa'),
        'Delete "Villa"? This cannot be undone.',
      );
      expect(
        l10n.projectCopyName('My Plan'),
        'My Plan (copy)',
      );
      expect(l10n.statusBarZoom(150), 'Zoom: 150%');
    });

    test('plural messages', () {
      expect(l10n.statusBarWarnings(1), '1 warning');
      expect(l10n.statusBarWarnings(5), '5 warnings');
      expect(l10n.statusBarRooms(1), '1 room');
      expect(l10n.statusBarRooms(3), '3 rooms');
      expect(
        l10n.relativeWeeksAgo(1),
        '1 week ago',
      );
      expect(
        l10n.relativeWeeksAgo(4),
        '4 weeks ago',
      );
    });
  });

  group('German locale', () {
    late AppLocalizations l10n;

    setUp(() {
      l10n = lookupAppLocalizations(const Locale('de'));
    });

    test('simple getters', () {
      expect(l10n.appTitle, 'HeatingPlanner');
      expect(l10n.newProject, 'Neues Projekt');
      expect(l10n.cancel, 'Abbrechen');
      expect(l10n.toolWall, 'Wand');
      expect(l10n.menuFile, 'Datei');
    });

    test('parameterised messages', () {
      expect(
        l10n.errorLoadingProjects('timeout'),
        'Fehler beim Laden der Projekte: timeout',
      );
      expect(
        l10n.deleteProjectContent('Villa'),
        '"Villa" löschen? Dies kann nicht '
        'rückgängig gemacht werden.',
      );
      expect(
        l10n.projectCopyName('Mein Plan'),
        'Mein Plan (Kopie)',
      );
      expect(l10n.statusBarZoom(150), 'Zoom: 150%');
    });

    test('plural messages', () {
      expect(l10n.statusBarWarnings(1), '1 Warnung');
      expect(l10n.statusBarWarnings(5), '5 Warnungen');
      expect(l10n.statusBarRooms(1), '1 Raum');
      expect(l10n.statusBarRooms(3), '3 Räume');
      expect(l10n.relativeWeeksAgo(1), 'vor 1 Woche');
      expect(
        l10n.relativeWeeksAgo(4),
        'vor 4 Wochen',
      );
    });
  });

  group('unsupported locale', () {
    test('throws FlutterError for unknown locale', () {
      expect(
        () => lookupAppLocalizations(const Locale('fr')),
        throwsFlutterError,
      );
    });
  });
}
