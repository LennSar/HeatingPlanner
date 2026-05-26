# HeatingPlanner — Progress Tracker

This file is maintained by the prompt engineer. Update it whenever the user confirms a feature or fix is working. It is the authoritative answer to "is X already built?" — do not read source files to check.

---

## Legend

- ✅ Confirmed working by user
- 🔧 Prompt generated, not yet confirmed
- ❌ Known broken / pending fix
- 📋 Planned, no prompt yet

---

## Core Infrastructure

| Feature | Status | Notes |
|---------|--------|-------|
| Project creation & persistence | ✅ | SQLite via Drift |
| Floor creation & persistence | ✅ | Default floor created with project |
| Editor state restore on launch | ✅ | `initFromFloor`, `SaveStateMixin` |
| Auto-save on change | ✅ | SaveStateMixin dirty tracking |
| HSP export / import (.hsp) | ✅ | gzip JSON snapshot |
| Project settings persistence (outdoor/indoor temp etc.) | ✅ | Wired to DB via `projectProvider` |

---

## Rooms & Floor Plan

| Feature | Status | Notes |
|---------|--------|-------|
| Draw rooms (polygon tool) | ✅ | |
| Room persistence across restarts | ✅ | |
| Room properties panel | ✅ | |
| Rectangular room width/height in properties (editable) | ✅ | ADR-015; reuses ADR-012 reshape path |
| Move entire room (interior drag) | 🔧 | ADR-016; reuses room-draw reconciliation path |
| Wall thickness & inner-clear annotations | ✅ | ADR-017; Project defaults + per-wall `thicknessMm`/`anchorMode` |
| Project default wall material | 🔧 | ADR-020; three material defaults + auto-default constructions on every new wall, with cascade through Project Settings |

---

## Wall Constructions

| Feature | Status | Notes |
|---------|--------|-------|
| Wall construction editor | ✅ | |
| Save wall construction as preset | 🔧 | Prompt generated; `isPreset` added to model + DB migration needed |
| Load preset in other walls | 🔧 | Part of same prompt |
| Custom material library (file-backed, shareable) | 🔧 | ADR-021; user-pickable JSON file mirrored into `material_entries`. Two prompts generated: data/service + UI |

---

## Heating Zones & Circuits

| Feature | Status | Notes |
|---------|--------|-------|
| Place heating zone | ✅ | |
| Split rectangular heating zone in two halves | 📋 | ADR-018; Zone tool double-click (longest side) + Select tool right-click context menu; spec drafted, no prompt yet |
| Connect zone to distributor (circuit) | ✅ | |
| Zone color state (unconnected / noDemand / insufficient / marginal / sufficient) | ✅ | ADR-004 |
| Zone color update after distributor move | 🔧 | Prompt generated; geometric 50 mm connectivity check |
| Delete circuit/connection line | 🔧 | Prompt generated |
| Flow rate display in circuit properties | ✅ | |
| Flow velocity display in circuit properties | 🔧 | Prompt generated; `flowVelocityProvider` missing |
| Pressure loss display | ✅ | |

---

## Distributor

| Feature | Status | Notes |
|---------|--------|-------|
| Place distributor | ✅ | |
| Distributor rotation & width persistence | ✅ | `rotationDeg` + `widthMm` columns added to DB |
| Distributor move: teardown disconnected circuits | 🔧 | Prompt generated; `_moveExisting` needs circuit/zone teardown |

---

## Validation & Errors

| Feature | Status | Notes |
|---------|--------|-------|
| Validation rules HB-01, VR-01–VR-04 | ✅ | |
| VR-05 geometric circuit disconnection | 🔧 | Prompt generated |
| Errors/warnings tab (SeverityBadge) | 📋 | Milestone 1a |
| Hover over error → highlight element on canvas | 🔧 | Prompt generated; `hoveredElementProvider` needed |

---

## Calculations

| Feature | Status | Notes |
|---------|--------|-------|
| U-value calculation | ✅ | |
| Heat demand per room | ✅ | |
| Zone heat output | ✅ | |
| Floor/ceiling heat loss (Milestone 1b) | 📋 | Prompt not yet generated |

---

## UI / Platform

| Feature | Status | Notes |
|---------|--------|-------|
| Desktop native menu bar (Save / Save As) | 🔧 | Prompt generated; `desktop_menu.dart` was a stub |
| Tablet lifecycle export | ✅ | |

---

## Known Bugs (unresolved)

| Bug | Status |
|-----|--------|
| `objective_c.dylib` crash with `file_picker ^10.0.0` | ✅ Fixed — downgraded to `^8.1.2` |
| Startup hang due to missing `is_preset` DB column | ✅ Fixed — column + migration added |
| Rooms lost on restart | ✅ Fixed — default floor now created with project |
| Distributor rotation/width reset on restart | ✅ Fixed — columns added to DB table |
