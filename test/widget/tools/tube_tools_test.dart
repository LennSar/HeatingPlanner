// ADR-046: TubeEditTool and TubeDrawTool — editing the automatic tube
// layout of a floor zone and drawing it by hand. The tools are exercised
// directly through a stub EditorCallbacks, as in route_draw_tool_test.dart.
//
// Covered:
//   TE-1 … TE-8   edit tool: freeze on first change, corner and run drags
//                 with and without snapping, Alt, insert, delete, Escape,
//                 zone pick
//   TE-9, TE-10   edit tool: Ctrl+Z / Ctrl+Y of committed changes; Ctrl+Z
//                 during a drag reverts the drag
//   TD-1 … TD-7   draw tool: entry to exit, snapping, Alt and the switch,
//                 refused corners, Backspace / Escape, unconnected zone,
//                 no floor zone
//   TD-8          draw tool: Ctrl+Z / Ctrl+Y per corner while drawing
//   UR-1          the undo service gives the active tool the first chance

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heating_planner/data/models/enums.dart';
import 'package:heating_planner/data/models/heating_zone.dart';
import 'package:heating_planner/data/models/point2d.dart';
import 'package:heating_planner/l10n/app_localizations.dart';
import 'package:heating_planner/l10n/app_localizations_en.dart';
import 'package:heating_planner/ui/canvas/painters/interaction_data.dart';
import 'package:heating_planner/ui/canvas/tools/editor_callbacks.dart';
import 'package:heating_planner/ui/canvas/tools/modifier_draw_tool.dart';
import 'package:heating_planner/ui/canvas/tools/tube_draw_tool.dart';
import 'package:heating_planner/ui/canvas/tools/tube_edit_tool.dart';
import 'package:heating_planner/ui/canvas/tools/undo_redo_service.dart';

/// Wires [tool]'s in-tool undo / redo into [undo], as the canvas does.
void _hook(UndoRedoService undo, dynamic tool) {
  undo.toolUndo = () => tool.undoInTool() as bool;
  undo.toolRedo = () => tool.redoInTool() as bool;
}

// ── Stub EditorCallbacks ─────────────────────────────────────────────────────

/// Implements only what the tube tools use; everything else is a no-op.
class _StubCallbacks implements EditorCallbacks {
  _StubCallbacks(List<HeatingZone> zones) : _zones = [...zones];

  @override
  final AppLocalizations l10n = AppLocalizationsEn();

  final List<HeatingZone> _zones;
  final List<String> toasts = [];
  final List<String?> selected = [];

  /// Number of persisted (non-transient) zone updates.
  int commits = 0;

  @override
  List<HeatingZone> get currentZones => List.unmodifiable(_zones);
  @override
  void updateZone(HeatingZone zone) {
    commits++;
    _replace(zone);
  }

  @override
  void updateZoneTransient(HeatingZone zone) => _replace(zone);
  @override
  void showToast(String message) => toasts.add(message);
  @override
  void selectElement(String? type, String? id) => selected.add(id);
  @override
  double get currentZoom => 0.1; // 10 px handle radius → 100 mm
  @override
  double get currentGridSpacingMm => 100;

  void _replace(HeatingZone zone) {
    final i = _zones.indexWhere((z) => z.id == zone.id);
    _zones[i] = zone;
  }

  HeatingZone get zone => _zones.first;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ── Fixtures ─────────────────────────────────────────────────────────────────

// 4 m × 3 m floor zone, connected; the pipes arrive at its left edge.
const _zone = HeatingZone(
  id: 'zone-1',
  roomId: 'room-1',
  polygon: [
    Point2D(x: 0, y: 0),
    Point2D(x: 4000, y: 0),
    Point2D(x: 4000, y: 3000),
    Point2D(x: 0, y: 3000),
  ],
  tubeSpacingMm: 150,
  tubeTypeId: 'tube-1',
  flooringMaterialId: 'mat-1',
  circuitId: 'circuit-1',
);

// The "automatic" layout the stub reports: entry (0, 200), two rows,
// exit (0, 500).
const _auto = [
  Point2D(x: 0, y: 200),
  Point2D(x: 3800, y: 200),
  Point2D(x: 3800, y: 350),
  Point2D(x: 200, y: 350),
  Point2D(x: 200, y: 500),
  Point2D(x: 0, y: 500),
];

List<Point2D>? Function(String) _cornersOf(_StubCallbacks cb) =>
    (id) => cb.currentZones
        .where((z) => z.id == id)
        .map((z) => z.manualTubePath ?? _auto)
        .firstOrNull;

TubeEditTool _editTool(
  _StubCallbacks cb,
  UndoRedoService undo, {
  bool snap = true,
}) => TubeEditTool(
  callbacks: cb,
  onStateChanged: () {},
  undoRedo: undo,
  tubeCorners: _cornersOf(cb),
  snapEnabled: () => snap,
)..zoneId = _zone.id;

TubeDrawTool _drawTool(
  _StubCallbacks cb,
  UndoRedoService undo, {
  bool snap = true,
}) => TubeDrawTool(
  callbacks: cb,
  onStateChanged: () {},
  undoRedo: undo,
  tubeCorners: _cornersOf(cb),
  bendRadiusMm: (_) => 80,
  snapEnabled: () => snap,
);

/// Press at [from], drag to [to], release.
void _drag(TubeEditTool tool, Point2D from, Point2D to) {
  tool.onPointerDown(from, kPrimaryButton);
  tool.onDragUpdate(to);
  tool.onDragEnd(to);
}

const _mouse = PointerDeviceKind.mouse;

/// Two taps at [p] within the double-click window.
void _doubleTap(dynamic tool, Point2D p) {
  tool.onTap(p, _mouse);
  tool.onTap(p, _mouse);
}

void main() {
  setUpAll(() => ModifierDrawTool.debugDisableHardwareSync = true);
  tearDownAll(() => ModifierDrawTool.debugDisableHardwareSync = false);

  group('TubeEditTool', () {
    test('TE-1 the first drag stores the automatic layout as manual; '
        'undo makes the zone automatic again', () {
      final cb = _StubCallbacks([_zone]);
      final undo = UndoRedoService();
      final tool = _editTool(cb, undo);

      _drag(
        tool,
        const Point2D(x: 3800, y: 350),
        const Point2D(x: 3510, y: 340),
      );

      final path = cb.zone.manualTubePath!;
      expect(path.length, _auto.length);
      // Snapped: y lines up with its neighbour (350), x to the grid.
      expect(path[2], const Point2D(x: 3500, y: 350));
      expect(path.first, _auto.first);
      expect(path.last, _auto.last);
      expect(cb.commits, 1);

      undo.undo();
      expect(cb.zone.manualTubePath, isNull);
    });

    test('TE-2 a dragged row moves across itself in whole spacings', () {
      final cb = _StubCallbacks([_zone]);
      final tool = _editTool(cb, UndoRedoService());

      // Row 3 (y = 350, x 200 … 3800) dragged down 230 mm, right 90 mm.
      _drag(
        tool,
        const Point2D(x: 2000, y: 350),
        const Point2D(x: 2090, y: 580),
      );

      final path = cb.zone.manualTubePath!;
      expect(path[2], const Point2D(x: 3800, y: 650));
      expect(path[3], const Point2D(x: 200, y: 650));
    });

    test('TE-3 Alt drags freely', () {
      final cb = _StubCallbacks([_zone]);
      final tool = _editTool(cb, UndoRedoService())
        ..updateModifiers(shift: false, ctrl: false, alt: true);

      _drag(
        tool,
        const Point2D(x: 2000, y: 350),
        const Point2D(x: 2090, y: 580),
      );

      final path = cb.zone.manualTubePath!;
      expect(path[2], const Point2D(x: 3890, y: 580));
    });

    test('TE-4 with snapping switched off a corner follows the cursor', () {
      final cb = _StubCallbacks([_zone]);
      final tool = _editTool(cb, UndoRedoService(), snap: false);

      _drag(
        tool,
        const Point2D(x: 3800, y: 350),
        const Point2D(x: 3512, y: 337),
      );

      expect(cb.zone.manualTubePath![2], const Point2D(x: 3512, y: 337));
    });

    test('TE-5 a double-click on a run adds a corner', () {
      final cb = _StubCallbacks([_zone]);
      final tool = _editTool(cb, UndoRedoService());

      _doubleTap(tool, const Point2D(x: 1000, y: 210));

      final path = cb.zone.manualTubePath!;
      expect(path.length, _auto.length + 1);
      expect(path[1], const Point2D(x: 1000, y: 200));
    });

    test('TE-6 a selected corner is removed with Delete; ends have no '
        'handle', () {
      final cb = _StubCallbacks([_zone]);
      final tool = _editTool(cb, UndoRedoService());

      tool.onTap(const Point2D(x: 200, y: 500), _mouse);
      final data = tool.getInteractionData()! as TubePathData;
      expect(data.selectedHandleIndex, 3);
      expect(data.handles.length, _auto.length - 2);
      tool.onDelete();

      final path = cb.zone.manualTubePath!;
      expect(path.length, _auto.length - 1);
      expect(path.contains(const Point2D(x: 200, y: 500)), isFalse);

      // An end cannot be selected or removed.
      tool.onTap(_auto.first, _mouse);
      tool.onDelete();
      expect(cb.zone.manualTubePath!.first, _auto.first);
    });

    test('TE-7 Escape during a drag reverts it', () {
      final cb = _StubCallbacks([_zone]);
      final tool = _editTool(cb, UndoRedoService());

      tool.onPointerDown(const Point2D(x: 3800, y: 350), kPrimaryButton);
      tool.onDragUpdate(const Point2D(x: 3000, y: 900));
      expect(cb.zone.manualTubePath, isNotNull);
      tool.cancel();

      expect(cb.zone.manualTubePath, isNull);
      expect(cb.commits, 0);
    });

    test('TE-8 a click picks the zone to edit; outside every zone a toast', () {
      final cb = _StubCallbacks([_zone]);
      final tool = TubeEditTool(
        callbacks: cb,
        onStateChanged: () {},
        undoRedo: UndoRedoService(),
        tubeCorners: _cornersOf(cb),
        snapEnabled: () => true,
      );

      tool.onTap(const Point2D(x: 9000, y: 9000), _mouse);
      expect(cb.toasts, [cb.l10n.tube_clickFloorZoneToast]);

      tool.onTap(const Point2D(x: 2000, y: 2000), _mouse);
      expect(tool.zoneId, _zone.id);
      expect(cb.selected, [_zone.id]);
    });

    test('TE-9 Ctrl+Z / Ctrl+Y undo and redo a committed change; the '
        'overlay follows', () {
      final cb = _StubCallbacks([_zone]);
      final undo = UndoRedoService();
      final tool = _editTool(cb, undo);
      _hook(undo, tool);

      _drag(
        tool,
        const Point2D(x: 3800, y: 350),
        const Point2D(x: 3510, y: 340),
      );
      _drag(
        tool,
        const Point2D(x: 2000, y: 350),
        const Point2D(x: 2000, y: 650),
      );
      final second = cb.zone.manualTubePath!;

      undo.undo(); // the run drag
      expect(cb.zone.manualTubePath![2], const Point2D(x: 3500, y: 350));
      expect(
        (tool.getInteractionData()! as TubePathData).corners[2],
        const Point2D(x: 3500, y: 350),
      );
      undo.undo(); // the corner drag — back to automatic
      expect(cb.zone.manualTubePath, isNull);

      undo.redo();
      undo.redo();
      expect(cb.zone.manualTubePath, second);
    });

    test('TE-10 Ctrl+Z during a drag reverts the drag only', () {
      final cb = _StubCallbacks([_zone]);
      final undo = UndoRedoService();
      final tool = _editTool(cb, undo);
      _hook(undo, tool);
      _drag(
        tool,
        const Point2D(x: 3800, y: 350),
        const Point2D(x: 3510, y: 340),
      );
      final committed = cb.zone.manualTubePath!;

      tool.onPointerDown(const Point2D(x: 2000, y: 200), kPrimaryButton);
      tool.onDragUpdate(const Point2D(x: 2000, y: 900));
      undo.undo();

      expect(cb.zone.manualTubePath, committed);
      expect(undo.canUndo, isTrue); // the corner drag is still there
    });
  });

  group('TubeDrawTool', () {
    test(
      'TD-1 a tube is drawn from the entry to the exit; one undo step',
      () async {
        final cb = _StubCallbacks([_zone]);
        final undo = UndoRedoService();
        final tool = _drawTool(cb, undo);

        tool.onTap(const Point2D(x: 100, y: 150), _mouse); // start at entry
        // Row along y = 200 — the click is pulled onto the row.
        tool.onTap(const Point2D(x: 3790, y: 260), _mouse);
        // Step down one spacing — a separate click, not a double-click.
        await Future<void>.delayed(const Duration(milliseconds: 350));
        tool.onTap(const Point2D(x: 3800, y: 330), _mouse);
        // Back along the second row, finished with a double-click.
        _doubleTap(tool, const Point2D(x: 300, y: 350));

        final path = cb.zone.manualTubePath!;
        expect(path, const [
          Point2D(x: 0, y: 200), // entry
          // No column yet: the row end snaps to the 100 mm grid.
          Point2D(x: 3800, y: 200),
          // One spacing below the row.
          Point2D(x: 3800, y: 350),
          // A whole number of spacings from the turn column.
          Point2D(x: 350, y: 350),
          Point2D(x: 0, y: 500), // exit
        ]);
        expect(tool.isDrawing, isFalse);

        undo.undo();
        expect(cb.zone.manualTubePath, isNull);
      },
    );

    test('TD-2 Alt places a corner freely', () {
      final cb = _StubCallbacks([_zone]);
      final tool = _drawTool(cb, UndoRedoService());

      tool.onTap(const Point2D(x: 100, y: 150), _mouse);
      tool.updateModifiers(shift: false, ctrl: false, alt: true);
      tool.onTap(const Point2D(x: 1234, y: 567), _mouse);
      final data = tool.getInteractionData()! as TubePathData;

      expect(data.corners[1], const Point2D(x: 1234, y: 567));
      expect(data.drawing, isTrue);
      expect(data.lengthMm, greaterThan(0));
    });

    test('TD-3 with snapping switched off corners follow the cursor', () {
      final cb = _StubCallbacks([_zone]);
      final tool = _drawTool(cb, UndoRedoService(), snap: false);

      tool.onTap(const Point2D(x: 100, y: 150), _mouse);
      tool.onTap(const Point2D(x: 1234, y: 567), _mouse);

      final data = tool.getInteractionData()! as TubePathData;
      expect(data.corners[1], const Point2D(x: 1234, y: 567));
    });

    test('TD-4 a corner outside the zone is refused', () {
      final cb = _StubCallbacks([_zone]);
      final tool = _drawTool(cb, UndoRedoService(), snap: false);

      tool.onTap(const Point2D(x: 100, y: 150), _mouse);
      tool.onTap(const Point2D(x: 5000, y: 200), _mouse);

      expect(cb.toasts, [cb.l10n.tube_mustStayInZoneToast]);
      final data = tool.getInteractionData()! as TubePathData;
      // Entry + cursor preview only.
      expect(data.corners.length, 2);
    });

    test('TD-5 Backspace removes the last corner, Escape discards', () {
      final cb = _StubCallbacks([_zone]);
      final tool = _drawTool(cb, UndoRedoService(), snap: false);

      tool.onTap(const Point2D(x: 100, y: 150), _mouse);
      tool.onTap(const Point2D(x: 1000, y: 200), _mouse);
      tool.onTap(const Point2D(x: 1000, y: 800), _mouse);
      tool.onDelete();
      tool.onPointerMove(const Point2D(x: 1000, y: 200));
      expect((tool.getInteractionData()! as TubePathData).corners.length, 3);

      tool.cancel();
      expect(tool.isDrawing, isFalse);
      expect(cb.zone.manualTubePath, isNull);
    });

    test('TD-6 an unconnected zone starts at the click and ends at the '
        'last corner', () {
      final cb = _StubCallbacks([_zone.copyWith(circuitId: null)]);
      final tool = _drawTool(cb, UndoRedoService(), snap: false);

      tool.onTap(const Point2D(x: 500, y: 500), _mouse);
      tool.onTap(const Point2D(x: 3000, y: 500), _mouse);
      _doubleTap(tool, const Point2D(x: 3000, y: 1500));

      expect(cb.zone.manualTubePath, const [
        Point2D(x: 500, y: 500),
        Point2D(x: 3000, y: 500),
        Point2D(x: 3000, y: 1500),
      ]);
    });

    test('TD-7 a click outside every floor zone does not start a tube', () {
      final cb = _StubCallbacks([
        _zone.copyWith(zoneType: ZoneType.wallHeating),
      ]);
      final tool = _drawTool(cb, UndoRedoService());

      tool.onTap(const Point2D(x: 100, y: 150), _mouse);
      expect(tool.isDrawing, isFalse);
      expect(cb.toasts, [cb.l10n.tube_clickFloorZoneToast]);
    });
    test('TD-8 Ctrl+Z takes back the last corner, Ctrl+Y puts it back; '
        'a finished tube is one undo step', () async {
      final cb = _StubCallbacks([_zone]);
      final undo = UndoRedoService();
      final tool = _drawTool(cb, undo, snap: false);
      _hook(undo, tool);

      tool.onTap(const Point2D(x: 100, y: 150), _mouse); // entry
      tool.onTap(const Point2D(x: 1000, y: 200), _mouse);
      tool.onTap(const Point2D(x: 1000, y: 800), _mouse);
      tool.onPointerMove(const Point2D(x: 1000, y: 800));
      int corners() =>
          (tool.getInteractionData()! as TubePathData).corners.length;
      expect(corners(), 4); // entry, 2 corners, cursor

      undo.undo();
      expect(corners(), 3);
      undo.redo();
      expect(corners(), 4);
      expect(undo.canUndo, isFalse); // nothing went onto the stack

      // A new corner clears what Ctrl+Y could put back.
      undo.undo();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      tool.onTap(const Point2D(x: 2000, y: 200), _mouse);
      undo.redo();
      expect(corners(), 4);

      _doubleTap(tool, const Point2D(x: 2000, y: 1000));
      expect(cb.zone.manualTubePath, isNotNull);
      undo.undo(); // the whole tube
      expect(cb.zone.manualTubePath, isNull);
      undo.redo();
      expect(cb.zone.manualTubePath, isNotNull);

      // Ctrl+Z on the starting point alone ends the drawing.
      tool.onTap(const Point2D(x: 100, y: 150), _mouse);
      expect(tool.isDrawing, isTrue);
      undo.undo();
      expect(tool.isDrawing, isFalse);
      expect(cb.zone.manualTubePath, isNotNull);
    });
  });

  group('UndoRedoService', () {
    test('UR-1 the active tool gets the first chance; every change bumps '
        'the revision', () {
      final undo = UndoRedoService();
      var toolTakes = true;
      var toolCalls = 0;
      undo.toolUndo = () {
        toolCalls++;
        return toolTakes;
      };
      final log = <String>[];
      final revisions = <int>[];
      undo.revision.addListener(() => revisions.add(undo.revision.value));
      undo.execute(_LogCommand(log));

      undo.undo();
      expect(toolCalls, 1);
      expect(log, ['do']); // the stack was left alone
      toolTakes = false;
      undo.undo();
      expect(log, ['do', 'undo']);
      undo.redo();
      expect(log, ['do', 'undo', 'do']);
      expect(revisions, [1, 2, 3, 4]);
    });
  });
}

class _LogCommand extends Command {
  _LogCommand(this.log);
  final List<String> log;
  @override
  String get label => 'log';
  @override
  void execute() => log.add('do');
  @override
  void undo() => log.add('undo');
}
