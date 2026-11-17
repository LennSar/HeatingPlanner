// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'HeatingPlanner';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get settingsDrawingGridSize => 'Drawing Grid Size';

  @override
  String get newProject => 'New Project';

  @override
  String errorLoadingProjects(String error) {
    return 'Error loading projects: $error';
  }

  @override
  String get noProjectsYet => 'No projects yet';

  @override
  String get createFirstProject =>
      'Create your first heating plan to get started.';

  @override
  String get projectNameLabel => 'Project name *';

  @override
  String get projectNameHint => 'e.g. Villa Schmidt';

  @override
  String get nameIsRequired => 'Name is required';

  @override
  String get designOutdoorTemperature => 'Design outdoor temperature';

  @override
  String get defaultIndoorTemperature => 'Default indoor temperature';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get duplicateAction => 'Duplicate';

  @override
  String get delete => 'Delete';

  @override
  String get deleteProjectTitle => 'Delete project?';

  @override
  String deleteProjectContent(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get defaultFloorName => 'Ground Floor';

  @override
  String projectCopyName(String name) {
    return '$name (copy)';
  }

  @override
  String get relativeJustNow => 'Just now';

  @override
  String relativeMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String relativeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String relativeDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String relativeWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks ago',
      one: '1 week ago',
    );
    return '$_temp0';
  }

  @override
  String relativeMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String relativeYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String get toolSelect => 'Select';

  @override
  String get toolWall => 'Wall';

  @override
  String get toolWindow => 'Window';

  @override
  String get toolDoor => 'Door';

  @override
  String get toolFloorZone => 'Floor Zone';

  @override
  String get toolWallZone => 'Wall Zone';

  @override
  String get toolDistributor => 'Distributor';

  @override
  String get toolPipe => 'Connection pipes';

  @override
  String get toolMeasure => 'Measure';

  @override
  String get tooltipOpen => 'Open (Ctrl+O)';

  @override
  String get tooltipSave => 'Save (Ctrl+S)';

  @override
  String get tooltipSaveAs => 'Save As (Ctrl+Shift+S)';

  @override
  String get tooltipDashboard => 'Dashboard';

  @override
  String get tooltipProjectSettings => 'Project Settings';

  @override
  String statusBarZoom(int percent) {
    return 'Zoom: $percent%';
  }

  @override
  String statusBarWarnings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count warnings',
      one: '1 warning',
    );
    return '$_temp0';
  }

  @override
  String statusBarRooms(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rooms',
      one: '1 room',
    );
    return '$_temp0';
  }

  @override
  String get wallToolLabel => 'Wall:';

  @override
  String get tooltipOrthoSnap => 'Ortho snap — H/V only';

  @override
  String get orthoLabel => 'Ortho';

  @override
  String get tooltipRectangleMode => 'Rectangle mode';

  @override
  String get rectangleLabel => 'Rectangle';

  @override
  String get saving => 'Saving…';

  @override
  String get menuFile => 'File';

  @override
  String get menuNew => 'New';

  @override
  String get menuOpen => 'Open…';

  @override
  String get menuSave => 'Save';

  @override
  String get menuSaveAs => 'Save As…';

  @override
  String get menuExportPdf => 'Export PDF…';

  @override
  String get menuExportCsv => 'Export CSV…';

  @override
  String get closeProject => 'Close Project';

  @override
  String get menuQuit => 'Quit HeatingPlanner';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuUndo => 'Undo';

  @override
  String get menuRedo => 'Redo';

  @override
  String get menuDelete => 'Delete';

  @override
  String get menuSelectAll => 'Select All';

  @override
  String get menuView => 'View';

  @override
  String get menuZoomIn => 'Zoom In';

  @override
  String get menuZoomOut => 'Zoom Out';

  @override
  String get menuZoomToFit => 'Zoom to Fit';

  @override
  String get menuTogglePropertiesPanel => 'Toggle Properties Panel';

  @override
  String get menuToggleDashboard => 'Toggle Dashboard';

  @override
  String get menuTools => 'Tools';

  @override
  String get menuDrawWall => 'Draw Wall';

  @override
  String get menuPlaceWindow => 'Place Window';

  @override
  String get menuPlaceDoor => 'Place Door';

  @override
  String get menuDrawFloorZone => 'Draw Floor Zone';

  @override
  String get menuPlaceDistributor => 'Place Distributor';

  @override
  String get menuRoutePipe => 'Route Connection Pipes';

  @override
  String get menuHelp => 'Help';

  @override
  String get menuAbout => 'About HeatingPlanner';

  @override
  String get menuDocumentation => 'Documentation';

  @override
  String get dialogSaveProjectAs => 'Save Project As';

  @override
  String get properties => 'Properties';

  @override
  String get close => 'Close';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get savingToFile => 'Saving to file…';

  @override
  String get exportOutOfDate =>
      'File export out of date — press Ctrl+S to update';

  @override
  String get allChangesSaved => 'All changes saved to file';

  @override
  String get newRoomDetected => 'New Room Detected';

  @override
  String get roomNameLabel => 'Room name';

  @override
  String get distributorAlreadyPlaced => 'Distributor already placed';

  @override
  String get distributorAlreadyPlacedContent =>
      'A distributor already exists on this floor.\nMove it to the new position, or replace it with a fresh one?';

  @override
  String get move => 'Move';

  @override
  String get replace => 'Replace';

  @override
  String get deleteDistributorTitle => 'Delete distributor?';

  @override
  String get deleteDistributorContent =>
      'This will remove the distributor from the floor plan.';

  @override
  String get room => 'Room';

  @override
  String get nameLabel => 'Name';

  @override
  String targetTemperatureValue(String temp) {
    return 'Target Temperature: $temp °C';
  }

  @override
  String get heatedRoomLabel => 'Heated room';

  @override
  String assumedTemperatureValue(String temp) {
    return 'Assumed Temperature: $temp °C';
  }

  @override
  String get unheatedRoomNote =>
      'Unheated space — excluded from heating demand. Its temperature is used as the adjacent temperature for neighbouring heated rooms.';

  @override
  String get airChangeRate => 'Air Change Rate';

  @override
  String get custom => 'Custom';

  @override
  String get rateLabel => 'Rate';

  @override
  String get windowNotFound => 'Window not found';

  @override
  String get doorNotFound => 'Door not found';

  @override
  String get typeLabel => 'Type';

  @override
  String get widthLabel => 'Width';

  @override
  String get heightLabel => 'Height';

  @override
  String get rectangularRoomDimensions => 'Dimensions';

  @override
  String get roomTooSmallCm => 'Room too small (min 10×10 cm)';

  @override
  String get sillHeight => 'Sill Height';

  @override
  String get uValueLabel => 'U-Value';

  @override
  String get circuitZoneRoom => 'Zone / Room';

  @override
  String get circuitLengthM => 'Length (m)';

  @override
  String get circuitFlowKgH => 'Flow (kg/h)';

  @override
  String get circuitValveKpa => 'Valve (kPa)';

  @override
  String get circuitStatus => 'Status';

  @override
  String get circuitNotFound => 'Circuit not found';

  @override
  String get heatingCircuit => 'Heating Circuit';

  @override
  String get supplyPipeInsulation => 'Supply pipe insulation';

  @override
  String get insulationNone => 'None (in screed)';

  @override
  String get insulationConduit => 'Corrugated conduit';

  @override
  String get insulationLayer => 'Insulation layer';

  @override
  String get pipeLengths => 'Pipe lengths';

  @override
  String get supplyRoute => 'Supply route';

  @override
  String get returnRoute => 'Return route';

  @override
  String get zoneTube => 'Zone tube';

  @override
  String get totalTube => 'Total tube';

  @override
  String get hydraulics => 'Hydraulics';

  @override
  String get flowRate => 'Flow rate';

  @override
  String get flowVelocity => 'Flow velocity';

  @override
  String get pressureLossLabel => 'Pressure loss';

  @override
  String get heatOutput => 'Heat output';

  @override
  String get deleteCircuit => 'Delete circuit';

  @override
  String get distributor => 'Distributor';

  @override
  String positionLabel(int x, int y) {
    return 'Position: ($x mm, $y mm)';
  }

  @override
  String get supplyTemperature => 'Supply Temperature';

  @override
  String get returnTemperature => 'Return Temperature';

  @override
  String get pump => 'Pump';

  @override
  String get minPumpPressure => 'Min. required pump pressure';

  @override
  String get pumpCapacityOptional => 'Pump Capacity (optional)';

  @override
  String get saveAsPreset => 'Save as preset';

  @override
  String get presetName => 'Preset name';

  @override
  String get savedAsPreset => 'Saved as preset';

  @override
  String get loadPreset => 'Load preset';

  @override
  String get load => 'Load';

  @override
  String get constructionName => 'Construction name';

  @override
  String get addLayer => 'Add Layer';

  @override
  String get noMaterialsAvailable =>
      'No materials available — try restarting the app';

  @override
  String get layerStack => 'Layer Stack  (outside → inside)';

  @override
  String get surfaceResistances => 'Surface resistances (m²K/W):';

  @override
  String get wallConstructionTitle => 'Wall Construction';

  @override
  String get newConstructionDefault => 'New Construction';

  @override
  String get uValueEmpty => 'U-Value: —';

  @override
  String get rValueEmpty => 'R: —';

  @override
  String uValueDisplay(String value) {
    return 'U  $value W/(m²K)';
  }

  @override
  String rValueDisplay(String value) {
    return 'R  $value m²K/W';
  }

  @override
  String temperatureProfileWithRange(String indoor, String outdoor) {
    return 'Temperature Profile  ($indoor°C → $outdoor°C)';
  }

  @override
  String get clearGapTooltip =>
      'Clear distance between studs, edge to edge — not centre-to-centre. Centre-to-centre spacing = stud width + clear gap.';

  @override
  String get addStudTooltip => 'Add timber stud (inhomogeneous layer)';

  @override
  String get removeStudTooltip => 'Remove stud definition';

  @override
  String get timberStudLabel => 'Timber stud:';

  @override
  String get studWidthLabel => 'stud width';

  @override
  String get clearGapLabel => 'clear gap';

  @override
  String get studWidthHint => 'width';

  @override
  String get studGapHint => 'gap';

  @override
  String get failedLoadMaterials => 'Failed to load materials.';

  @override
  String get noMaterialsInPicker => 'No materials available.';

  @override
  String get noMatchingMaterials => 'No matching materials.';

  @override
  String presetUValueLine(String value) {
    return 'U = $value';
  }

  @override
  String get heatingZone => 'Heating Zone';

  @override
  String tubeSpacingValue(int value) {
    return 'Tube Spacing: $value mm';
  }

  @override
  String heightValue(int value) {
    return 'Height: $value mm';
  }

  @override
  String borderDistanceValue(int value) {
    return 'Border Distance: $value mm';
  }

  @override
  String get layoutPattern => 'Layout Pattern';

  @override
  String get layoutPattern_meander => 'Meander';

  @override
  String get layoutPattern_meanderHint =>
      'Single serpentine; cools from one side to the other';

  @override
  String get layoutPattern_doubleMeander => 'Double meander';

  @override
  String get layoutPattern_doubleMeanderHint =>
      'Supply and return side by side; even temperature';

  @override
  String get layoutPattern_counterflow => 'Counterflow spiral';

  @override
  String get layoutPattern_counterflowHint =>
      'Spirals in and back out; most even temperature';

  @override
  String get layoutPattern_edgeZoneMeander => 'Meander with edge zone';

  @override
  String get layoutPattern_edgeZoneMeanderHint =>
      'Denser tubes along the exterior wall, fed first';

  @override
  String get tubeType => 'Tube Type';

  @override
  String get zoneOutput => 'Zone Output';

  @override
  String get rValueLabel => 'R value';

  @override
  String get searchMaterials => 'Search materials…';

  @override
  String get rotateDistributor => 'Rotate distributor';

  @override
  String get projectSettings => 'Project Settings';

  @override
  String get designOutdoorTempDesc =>
      'Used in all heat-demand calculations (EN 12831).';

  @override
  String get defaultIndoorTempDesc =>
      'Applied to new rooms when they are created.';

  @override
  String get defaultRoomHeight => 'Default Room Height';

  @override
  String get defaultRoomHeightDesc =>
      'Used as the default height for wall heating zones.';

  @override
  String get unheatedSpaceTemp => 'Unheated Space Temperature';

  @override
  String get unheatedSpaceTempDesc =>
      'Default temperature used for unheated basements, attics, and adjacent unheated spaces.';

  @override
  String get drawingGridSizeDesc =>
      'Snap interval for walls, zones, and other elements on the canvas.';

  @override
  String get designOutdoorTempRange => '−50 to +10 °C';

  @override
  String get defaultIndoorTempRange => '15 to 30 °C';

  @override
  String get defaultRoomHeightRange => '2000 to 6000 mm';

  @override
  String get unheatedSpaceTempRange => '0 to 25 °C';

  @override
  String get tabHeatBalance => 'Heat Balance';

  @override
  String get tabHydraulic => 'Hydraulic';

  @override
  String get tabWarnings => 'Warnings';

  @override
  String warningsWithCount(int count) {
    return 'Warnings ($count)';
  }

  @override
  String get filterAll => 'All';

  @override
  String get filterErrorsOnly => 'Errors only';

  @override
  String get filterWarningsOnly => 'Warnings only';

  @override
  String get filterInfoOnly => 'Info only';

  @override
  String get filterLabel => 'Filter';

  @override
  String get noIssuesFound => 'No issues found';

  @override
  String get emptyHeatBalance => 'Draw rooms to see the heat balance.';

  @override
  String get demand => 'Demand';

  @override
  String get output => 'Output';

  @override
  String get balance => 'Balance';

  @override
  String get emptyHydraulic =>
      'Add a distributor and connect heating zones to see hydraulic data.';

  @override
  String get pressureLossByCircuit => 'Pressure Loss by Circuit (kPa)';

  @override
  String get pipeLoss => 'Pipe loss';

  @override
  String get valveThrottling => 'Valve throttling';

  @override
  String get flowRateDistribution => 'Flow Rate Distribution';

  @override
  String get unsavedExportFile => 'Unsaved changes';

  @override
  String unsavedExportContent(String name) {
    return '\"$name\" has changes that have not been saved to its .hsp file.\n\nSave them before closing?';
  }

  @override
  String unsavedNeverSavedContent(String name) {
    return '\"$name\" has not been saved yet. The project file (.hsp) is the only permanent copy — if you close without saving, it will be discarded.\n\nSave it now?';
  }

  @override
  String get removeFromList => 'Remove from list';

  @override
  String get deleteFile => 'Delete file…';

  @override
  String get deleteFileTitle => 'Delete project file?';

  @override
  String deleteFileContent(String name) {
    return 'Permanently delete the file for \"$name\"? This cannot be undone.';
  }

  @override
  String deleteFileFailed(String path) {
    return 'Removed from the list, but the file could not be deleted (it may be outside the app\'s access):\n$path';
  }

  @override
  String basedOnFile(String fileName) {
    return 'File: $fileName';
  }

  @override
  String get fileMissing => 'File missing';

  @override
  String fileMissingMessage(String path) {
    return 'The file could not be found:\n$path';
  }

  @override
  String fileOpenFailed(String error) {
    return 'Could not open the project: $error';
  }

  @override
  String get quitAnyway => 'Quit Anyway';

  @override
  String get saveFileAndQuit => 'Save File and Quit';

  @override
  String get closeWithoutSaving => 'Close Without Saving';

  @override
  String get saveFileAndClose => 'Save File and Close';

  @override
  String get roomNotFound => 'Room not found';

  @override
  String get floorArea => 'Floor Area';

  @override
  String get roomVolume => 'Room Volume';

  @override
  String get wallsCount => 'Walls';

  @override
  String get heatDemand => 'Heat Demand';

  @override
  String get transmissionQt => 'Transmission Qᵀ';

  @override
  String get assignConstructionsHint =>
      'Assign constructions to walls for transmission loss.';

  @override
  String get transmissionFloor => 'Transmission — floor';

  @override
  String get transmissionCeiling => 'Transmission — ceiling';

  @override
  String get ventilationQv => 'Ventilation Qᴠ';

  @override
  String get totalHeatDemand => 'Total Heat Demand';

  @override
  String get specificHeatDemand => 'Specific Heat Demand';

  @override
  String get envelopeFloorCeiling => 'Envelope — Floor & Ceiling';

  @override
  String get floorLabel => 'Floor';

  @override
  String get ceilingLabel => 'Ceiling';

  @override
  String get whatsBelow => 'What\'s below?';

  @override
  String get whatsAbove => 'What\'s above?';

  @override
  String get floorConstruction => 'Floor construction';

  @override
  String get roofCeilingConstruction => 'Roof / ceiling construction';

  @override
  String get notAssigned => 'Not assigned';

  @override
  String get assignAction => '+ Assign';

  @override
  String get editAction => 'Edit';

  @override
  String get adjacentRoomTemp => 'Adjacent room temp.';

  @override
  String get unheatedSpaceTempShort => 'Unheated space temp.';

  @override
  String defaultHint(String value) {
    return '$value (default)';
  }

  @override
  String get resetToProjectDefault => 'Reset to project default';

  @override
  String get boundaryGround => 'Ground (slab on grade)';

  @override
  String get boundaryUnheatedBelow =>
      'Unheated space (basement / garage / crawlspace)';

  @override
  String get boundaryAdjacentBelow =>
      'Adjacent heated room (floor above another room)';

  @override
  String get boundaryExteriorRoof => 'Exterior / Roof';

  @override
  String get boundaryUnheatedAbove =>
      'Unheated space (attic / garage / crawlspace)';

  @override
  String get boundaryAdjacentAbove =>
      'Adjacent heated room (ceiling below another room)';

  @override
  String get acrStandardRoom => 'Standard room';

  @override
  String get acrKitchen => 'Kitchen';

  @override
  String get acrBathroom => 'Bathroom';

  @override
  String get acrUtilityRoom => 'Utility room';

  @override
  String get acrServerRoom => 'Server room';

  @override
  String circuitsWithCount(int count) {
    return 'Circuits ($count)';
  }

  @override
  String get circuitDeltaPKpa => 'Δp (kPa)';

  @override
  String get noCircuits => 'No circuits';

  @override
  String get noCircuitsHint =>
      'Add a distributor and draw heating zones to see circuit data here.';

  @override
  String get wallSegment => 'Wall Segment';

  @override
  String get lengthLabel => 'Length';

  @override
  String get orientationLabel => 'Orientation';

  @override
  String get constructionLabel => 'Construction';

  @override
  String get addConstruction => 'Add Construction';

  @override
  String get editConstruction => 'Edit Construction';

  @override
  String get surfaceMaterial => 'Surface Material';

  @override
  String get flooringMaterial => 'Flooring Material';

  @override
  String get customEllipsis => 'Custom…';

  @override
  String get zoneArea => 'Zone Area';

  @override
  String get tubeLengthLabel => 'Tube Length';

  @override
  String get specificOutput => 'Specific Output';

  @override
  String get totalOutput => 'Total Output';

  @override
  String get errorLoadingTubeTypes => 'Error loading tube types';

  @override
  String get errorLoadingFlooringMaterials =>
      'Error loading flooring materials';

  @override
  String get projectSummary => 'Project Summary';

  @override
  String get rooms => 'Rooms';

  @override
  String get walls => 'Walls';

  @override
  String get totalArea => 'Total Area';

  @override
  String get selectElementHint =>
      'Select an element on the canvas to see its properties.';

  @override
  String get wallNotFound => 'Wall not found';

  @override
  String get typeWallLabel => 'Type';

  @override
  String get surfaceTemperature => 'Surface Temperature';

  @override
  String get materialCategory_masonry => 'Masonry';

  @override
  String get materialCategory_concreteScreed => 'Concrete & Screed';

  @override
  String get materialCategory_insulationBoards => 'Insulation boards';

  @override
  String get materialCategory_looseFillBlowIn => 'Loose fill / Blow-in';

  @override
  String get materialCategory_wood => 'Wood';

  @override
  String get materialCategory_plasterMortar => 'Plaster & Mortar';

  @override
  String get materialCategory_boardMaterials => 'Board materials';

  @override
  String get materialCategory_floorCovering => 'Floor covering';

  @override
  String get materialCategory_glass => 'Glass';

  @override
  String get materialSubcategory_historicBrick => 'Historic brick';

  @override
  String get materialSubcategory_modernThermalBrick => 'Modern thermal brick';

  @override
  String get materialSubcategory_calciumSilicate => 'Calcium silicate';

  @override
  String get materialSubcategory_aacAeratedConcrete => 'AAC / Aerated concrete';

  @override
  String get materialSubcategory_normalConcrete => 'Normal concrete';

  @override
  String get materialSubcategory_lightweightConcrete => 'Lightweight concrete';

  @override
  String get materialSubcategory_screed => 'Screed';

  @override
  String get materialSubcategory_rigidFoamEps => 'Rigid foam, EPS';

  @override
  String get materialSubcategory_rigidFoamXps => 'Rigid foam, XPS';

  @override
  String get materialSubcategory_rigidFoamPurPir => 'Rigid foam, PUR/PIR';

  @override
  String get materialSubcategory_rigidFoamPhenolic => 'Rigid foam, phenolic';

  @override
  String get materialSubcategory_stoneWoolBoard => 'Stone wool board';

  @override
  String get materialSubcategory_glassWoolBoardRoll => 'Glass wool board/roll';

  @override
  String get materialSubcategory_woodFibre => 'Wood fibre';

  @override
  String get materialSubcategory_calciumSilicateBoard =>
      'Calcium silicate board';

  @override
  String get materialSubcategory_cellularGlass => 'Cellular glass';

  @override
  String get materialSubcategory_cork => 'Cork';

  @override
  String get materialSubcategory_vacuumInsulation => 'Vacuum insulation';

  @override
  String get materialSubcategory_cellulose => 'Cellulose';

  @override
  String get materialSubcategory_mineralWoolBlowIn => 'Mineral wool blow-in';

  @override
  String get materialSubcategory_perlite => 'Perlite';

  @override
  String get materialSubcategory_vermiculite => 'Vermiculite';

  @override
  String get materialSubcategory_naturalFibre => 'Natural fibre';

  @override
  String get materialSubcategory_structuralTimber => 'Structural timber';

  @override
  String get materialSubcategory_engineeredWood => 'Engineered wood';

  @override
  String get materialSubcategory_cementLime => 'Cement/Lime';

  @override
  String get materialSubcategory_clay => 'Clay';

  @override
  String get materialSubcategory_gypsum => 'Gypsum';

  @override
  String get materialSubcategory_insulationPlaster => 'Insulation plaster';

  @override
  String get materialSubcategory_gypsumBoard => 'Gypsum board';

  @override
  String get materialSubcategory_tileNaturalStone => 'Tile / Natural stone';

  @override
  String get materialSubcategory_woodLaminateVinyl => 'Wood / Laminate / Vinyl';

  @override
  String get perfDashboard_tabHeatBalance => 'Heat Balance';

  @override
  String get perfDashboard_tabHydraulic => 'Hydraulic';

  @override
  String get perfDashboard_tabWarnings => 'Warnings';

  @override
  String perfDashboard_warningsHeader(int count) {
    return 'Warnings ($count)';
  }

  @override
  String get perfDashboard_filterErrorsOnly => 'Errors only';

  @override
  String get perfDashboard_filterWarningsOnly => 'Warnings only';

  @override
  String get perfDashboard_filterInfoOnly => 'Info only';

  @override
  String get perfDashboard_noIssuesFound => 'No issues found';

  @override
  String get perfDashboard_emptyHeatBalance =>
      'Draw rooms to see the heat balance.';

  @override
  String get perfDashboard_legendDemand => 'Demand';

  @override
  String get perfDashboard_legendOutput => 'Output';

  @override
  String get perfDashboard_legendBalance => 'Balance';

  @override
  String get perfDashboard_legendPipeLoss => 'Pipe loss';

  @override
  String get perfDashboard_legendValveThrottling => 'Valve throttling';

  @override
  String get severity_error => 'Error';

  @override
  String get severity_warning => 'Warning';

  @override
  String get severity_info => 'Info';

  @override
  String get zoneMissing_noCircuitConnected => 'No circuit connected';

  @override
  String get zoneMissing_noDistributorPlaced => 'No distributor placed';

  @override
  String get zoneMissing_noTubeTypeSelected => 'No tube type selected';

  @override
  String get zoneMissing_noFlooringMaterialSelected =>
      'No flooring material selected';

  @override
  String get zoneMissing_noTubeTypesAvailable => 'No tube types available';

  @override
  String get roomMissing_noExteriorWallsDefined => 'No exterior walls defined';

  @override
  String get circuit_fullHeatOutputToTransitRoom =>
      'Full heat output to transit room';

  @override
  String get circuit_noHeatOutputToTransitRoom =>
      'No heat output to transit room';

  @override
  String get opening_updateWindow => 'Update window';

  @override
  String get opening_updateDoor => 'Update door';

  @override
  String get undo_rotateDistributor => 'Rotate distributor';

  @override
  String get undo_deleteWall => 'Delete wall';

  @override
  String get undo_deleteRoom => 'Delete room';

  @override
  String get undo_deleteWindow => 'Delete window';

  @override
  String get undo_deleteDoor => 'Delete door';

  @override
  String get undo_deleteCircuit => 'Delete circuit';

  @override
  String get undo_deleteZone => 'Delete zone';

  @override
  String get undo_deleteDistributor => 'Delete distributor';

  @override
  String get undo_createZone => 'Create zone';

  @override
  String get undo_createWallZone => 'Create wall zone';

  @override
  String get undo_splitZone => 'Split zone';

  @override
  String get undo_moveZoneBoundary => 'Move zone boundary';

  @override
  String get undo_drawConnectionPipe => 'Draw connection pipes';

  @override
  String get undo_editConnectionPipe => 'Edit connection pipe';

  @override
  String get circuit_routeMustEndInZoneToast =>
      'The connection pipe must end inside its heating zone.';

  @override
  String get route_doubleClickInZoneToast =>
      'Double-click inside a heating zone to connect the pipes.';

  @override
  String route_allOutletsInUseToast(int count) {
    return 'All $count outlets of the distributor are in use. Raise the number of circuit outlets in the distributor properties.';
  }

  @override
  String get distributorOutlets => 'Circuit outlets';

  @override
  String distributorOutletsInUse(int used, int count) {
    return '$used of $count in use';
  }

  @override
  String get route_zoneAlreadyConnectedToast =>
      'This heating zone is already connected.';

  @override
  String get connectionPipes => 'Connection pipes';

  @override
  String get circuit_pipeSpacing => 'Distance between supply and return';

  @override
  String get circuit_zoneClearance => 'Distance to heating zones';

  @override
  String get circuit_wallClearance => 'Distance to walls';

  @override
  String get circuit_swapSupplyReturn => 'Swap supply and return';

  @override
  String circuit_distanceRange(int min, int max) {
    return '$min–$max mm';
  }

  @override
  String get zoneContextMenu_delete => 'Delete';

  @override
  String get zoneContextMenu_splitVertically => 'Split vertically';

  @override
  String get zoneContextMenu_splitHorizontally => 'Split horizontally';

  @override
  String get zoneContextMenu_splitDisabledTooltip =>
      'This zone\'s shape cannot be split into two halves.';

  @override
  String get zone_splitNonRectangularToast =>
      'This zone\'s shape cannot be split into two halves in that direction.';

  @override
  String get zone_splitTooSmallToast =>
      'Zone too small to split (each half must be ≥ 100 mm).';

  @override
  String canvas_defaultRoomName(int roomNumber) {
    return 'Room $roomNumber';
  }

  @override
  String get defaultWallThicknesses => 'Default wall thicknesses';

  @override
  String get defaultWallThicknessesDesc =>
      'Used for unassigned walls (no construction). Editing a value re-anchors every matching wall in one undo step.';

  @override
  String get wallTypeExterior => 'Exterior';

  @override
  String get wallTypeInteriorShared => 'Interior (shared)';

  @override
  String get wallTypePartition => 'Partition';

  @override
  String get wallThicknessRangeCm => '5–100 cm';

  @override
  String get wallThicknessInvalidToast => 'Wall thickness must be 5–100 cm';

  @override
  String get defaultWallMaterials => 'Default wall materials';

  @override
  String get defaultWallMaterialsDesc =>
      'Changes here update walls you have not customised individually.';

  @override
  String get defaultExteriorMaterial => 'Default exterior material';

  @override
  String get defaultInteriorMaterial => 'Default interior material';

  @override
  String get defaultPartitionMaterial => 'Default partition material';

  @override
  String get defaultTubeTypes => 'Default tube types';

  @override
  String get defaultTubeTypesDesc =>
      'Tube type assigned to newly drawn heating zones.';

  @override
  String get defaultFloorTubeType => 'Floor heating';

  @override
  String get defaultWallTubeType => 'Wall heating';

  @override
  String get layerStackRequiresOneLayer =>
      'A construction must have at least one layer.';

  @override
  String get customMaterialPickerNewRow => 'New custom material…';

  @override
  String get customMaterialPickerManageRow => 'Manage custom materials…';

  @override
  String get customMaterialChip => 'Custom';

  @override
  String get customMaterialDialogAddTitle => 'Add Custom Material';

  @override
  String get customMaterialDialogEditTitle => 'Edit Custom Material';

  @override
  String get customMaterialFieldName => 'Name';

  @override
  String get customMaterialFieldLocation => 'Location';

  @override
  String get customMaterialPathStartUnder => 'Start under';

  @override
  String get customMaterialPathRootOption => '(root)';

  @override
  String get customMaterialPathAddSubcategory => '+ Add subcategory';

  @override
  String get customMaterialPathStartUnderHint => 'Pick a starting location';

  @override
  String get customMaterialPathSegmentRequired => 'Subcategory name required';

  @override
  String get customMaterialPathSegmentNoSlash => 'Must not contain \'/\'';

  @override
  String get customMaterialFieldManufacturer => 'Manufacturer';

  @override
  String get customMaterialManufacturerHint => 'Custom';

  @override
  String get customMaterialFieldLambda => 'λ (W/(m·K))';

  @override
  String get customMaterialFieldDensity => 'Density (kg/m³)';

  @override
  String get customMaterialFieldSpecificHeat => 'Specific heat (J/(kg·K))';

  @override
  String get customMaterialFieldSourceUrl => 'Source URL';

  @override
  String get customMaterialButtonCancel => 'Cancel';

  @override
  String get customMaterialButtonSave => 'Save';

  @override
  String get customMaterialButtonAdd => 'Add';

  @override
  String get customMaterialValidationRequired => 'Required';

  @override
  String customMaterialValidationMaxChars(int max) {
    return 'Maximum $max characters';
  }

  @override
  String customMaterialValidationRange(String min, String max) {
    return 'Allowed range: $min–$max';
  }

  @override
  String get customMaterialValidationDuplicateName =>
      'A custom material with this name already exists';

  @override
  String get customMaterialFileWriteFailedToast =>
      'Could not save to library file. Check disk space or permissions and try again.';

  @override
  String get manageCustomMaterialsTitle => 'Custom Materials';

  @override
  String get manageCustomMaterialsAdd => 'Add';

  @override
  String get manageCustomMaterialsBrowse => 'Browse…';

  @override
  String get manageCustomMaterialsResetToDefault => 'Reset to default';

  @override
  String get manageCustomMaterialsReload => 'Reload from file';

  @override
  String get manageCustomMaterialsSearchHint => 'Search…';

  @override
  String get manageCustomMaterialsEmptyTitle => 'No custom materials yet.';

  @override
  String get manageCustomMaterialsEmptyHint =>
      'Press \"+ Add\" to create your first one.';

  @override
  String get manageCustomMaterialsNoMatches => 'No matches.';

  @override
  String get manageCustomMaterialsRowEdit => 'Edit';

  @override
  String get manageCustomMaterialsRowDelete => 'Delete';

  @override
  String manageCustomMaterialsDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get manageCustomMaterialsDeleteBody =>
      'This will remove it from your custom material library file and from the in-app database.';

  @override
  String manageCustomMaterialsBlockedTitle(String name) {
    return '\"$name\" is in use';
  }

  @override
  String manageCustomMaterialsBlockedBody(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count layers',
      one: '1 layer',
    );
    return '\"$name\" is used in $_temp0:';
  }

  @override
  String get manageCustomMaterialsBlockedFooter =>
      'Remove or reassign those layers first, then try again.';

  @override
  String get manageCustomMaterialsBlockedOk => 'OK';

  @override
  String manageCustomMaterialsDeletedToast(String name) {
    return 'Deleted \"$name\"';
  }

  @override
  String manageCustomMaterialsReloadedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reloaded $count custom materials',
      one: 'Reloaded 1 custom material',
    );
    return '$_temp0';
  }

  @override
  String get settingsCustomMaterialLibraryTitle => 'Custom material library';

  @override
  String get settingsCustomMaterialLibraryDefaultChip => '(default)';

  @override
  String get settingsCustomMaterialLibraryManageButton => 'Manage materials…';

  @override
  String settingsCustomMaterialLibraryStatusLoaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Loaded $count custom materials',
      one: 'Loaded 1 custom material',
    );
    return '$_temp0';
  }

  @override
  String get settingsCustomMaterialLibraryStatusError =>
      'File could not be loaded — check the path and try Reload';

  @override
  String get settingsCustomMaterialLibraryResetTitle =>
      'Switch back to the default library file?';

  @override
  String get settingsCustomMaterialLibraryResetBody =>
      'Your custom materials from the current file will no longer appear unless you Browse back to it. The current file on disk is not modified.';

  @override
  String get settingsCustomMaterialLibraryFilePickerTitle =>
      'Pick custom material library';

  @override
  String get tooltipRoomSummary => 'Room summary';

  @override
  String get roomSummary_title => 'Room summary';

  @override
  String get roomSummary_empty => 'Draw a room to see its heat balance.';

  @override
  String get roomSummary_colRoom => 'Room / circuit';

  @override
  String get roomSummary_colArea => 'Heated area';

  @override
  String get roomSummary_colDemand => 'Heat demand';

  @override
  String get roomSummary_colTemps => 'Supply / return';

  @override
  String get roomSummary_colFlow => 'Flow rate';

  @override
  String get roomSummary_colSpecificOutput => 'Heat flux';

  @override
  String get roomSummary_colOutput => 'Delivered heat';

  @override
  String get roomSummary_colDifference => 'Difference';

  @override
  String get roomSummary_colSurfaceTemp => 'Surface temp.';

  @override
  String get roomSummary_colTube => 'Tube';

  @override
  String get roomSummary_colPressureLoss => 'Pressure loss';

  @override
  String get roomSummary_colLengthInRoom => 'Tube in room';

  @override
  String get roomSummary_colLengthTotal => 'Incl. connection pipes';

  @override
  String get roomSummary_total => 'Total';

  @override
  String roomSummary_circuit(int number) {
    return 'Circuit $number';
  }

  @override
  String roomSummary_wallCircuit(int number) {
    return 'Circuit $number (wall)';
  }

  @override
  String get roomSummary_zoneNotConnected => 'Zone not connected';

  @override
  String get roomSummary_unheated => 'unheated';

  @override
  String get roomSummary_demandIncomplete =>
      'The heat demand of at least one room cannot be calculated yet (wall construction missing). Those rooms are not part of the total.';

  @override
  String get roomSummary_notes =>
      'Heat demand: EN 12831. Delivered heat: EN 1264-2 for the distributor\'s supply and return temperature, the room temperature, tube spacing, tube and floor covering, assuming 45 mm cement screed above the tube. Flow rate: delivered heat ÷ (4.186 kJ/(kg·K) × temperature spread), in litres at 992.2 kg/m³ (water at 40 °C). Pressure loss: Darcy–Weisbach for the tube\'s inner diameter over the tube in the room and both connection pipes, plus 40 % for bends and fittings.';

  @override
  String get undo_editTubePath => 'Edit tube path';

  @override
  String get undo_drawTubePath => 'Draw tube path';

  @override
  String get undo_resetTubePath => 'Reset tube path';

  @override
  String get tube_clickFloorZoneToast => 'Click inside a floor heating zone.';

  @override
  String get tube_mustStayInZoneToast =>
      'The tube must stay inside its heating zone.';

  @override
  String get tube_placeCornersToast =>
      'Place at least one corner before finishing.';

  @override
  String tube_drawHint(String lengthM) {
    return 'Tube length: $lengthM m — double-click to finish, Ctrl+Z / Backspace removes the last corner, Ctrl+Y puts it back, hold Alt to place freely';
  }

  @override
  String get tube_editHint =>
      'Drag a corner or a run · double-click a run to add a corner · select a corner and press Delete to remove it · hold Alt to place freely';

  @override
  String get zoneTubePath => 'Tube path';

  @override
  String get zoneTubePathAutomatic => 'Automatic — laid out from the pattern';

  @override
  String get zoneTubePathManual => 'Manual — edited or drawn by hand';

  @override
  String get zoneTubePathEdit => 'Edit';

  @override
  String get zoneTubePathDraw => 'Draw manually';

  @override
  String get zoneTubePathReset => 'Reset to automatic';

  @override
  String get zoneTubeSnap => 'Snap tube corners';

  @override
  String get zoneTubeSnapDesc =>
      'Square segments, rows a whole spacing apart. Hold Alt to place a single corner freely.';

  @override
  String get zoneTubePatternIgnored =>
      'The tube is drawn by hand, so the pattern is not applied. Choosing a pattern resets the tube to automatic.';

  @override
  String get zoneTubePathDone => 'Done';

  @override
  String get zoneTubeDrawStartHint =>
      'Click inside this zone to start the tube, click corners, double-click to finish. Ctrl+Z takes back a corner, Escape cancels.';
}
