// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'HeatingPlanner';

  @override
  String get settingsLanguageLabel => 'Sprache';

  @override
  String get languageEnglish => 'Englisch';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get settingsDrawingGridSize => 'Rasterweite';

  @override
  String get newProject => 'Neues Projekt';

  @override
  String errorLoadingProjects(String error) {
    return 'Fehler beim Laden der Projekte: $error';
  }

  @override
  String get noProjectsYet => 'Noch keine Projekte';

  @override
  String get createFirstProject => 'Erstellen Sie Ihren ersten Heizungsplan.';

  @override
  String get projectNameLabel => 'Projektname *';

  @override
  String get projectNameHint => 'z.B. Villa Schmidt';

  @override
  String get nameIsRequired => 'Name ist erforderlich';

  @override
  String get designOutdoorTemperature => 'Normaußentemperatur';

  @override
  String get defaultIndoorTemperature => 'Standard-Raumtemperatur';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get create => 'Erstellen';

  @override
  String get duplicateAction => 'Duplizieren';

  @override
  String get delete => 'Löschen';

  @override
  String get deleteProjectTitle => 'Projekt löschen?';

  @override
  String deleteProjectContent(String name) {
    return '\"$name\" löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get defaultFloorName => 'Erdgeschoss';

  @override
  String projectCopyName(String name) {
    return '$name (Kopie)';
  }

  @override
  String get relativeJustNow => 'Gerade eben';

  @override
  String relativeMinutesAgo(int count) {
    return 'vor $count Min.';
  }

  @override
  String relativeHoursAgo(int count) {
    return 'vor $count Std.';
  }

  @override
  String relativeDaysAgo(int count) {
    return 'vor $count T.';
  }

  @override
  String relativeWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Wochen',
      one: 'vor 1 Woche',
    );
    return '$_temp0';
  }

  @override
  String relativeMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Monaten',
      one: 'vor 1 Monat',
    );
    return '$_temp0';
  }

  @override
  String relativeYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Jahren',
      one: 'vor 1 Jahr',
    );
    return '$_temp0';
  }

  @override
  String get toolSelect => 'Auswahl';

  @override
  String get toolWall => 'Wand';

  @override
  String get toolWindow => 'Fenster';

  @override
  String get toolDoor => 'Tür';

  @override
  String get toolFloorZone => 'Bodenzone';

  @override
  String get toolWallZone => 'Wandzone';

  @override
  String get toolDistributor => 'Verteiler';

  @override
  String get toolPipe => 'Rohr';

  @override
  String get toolMeasure => 'Messen';

  @override
  String get tooltipOpen => 'Öffnen (Strg+O)';

  @override
  String get tooltipSave => 'Speichern (Strg+S)';

  @override
  String get tooltipSaveAs => 'Speichern unter (Strg+Umschalt+S)';

  @override
  String get tooltipDashboard => 'Dashboard';

  @override
  String get tooltipProjectSettings => 'Projekteinstellungen';

  @override
  String statusBarZoom(int percent) {
    return 'Zoom: $percent%';
  }

  @override
  String statusBarWarnings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Warnungen',
      one: '1 Warnung',
    );
    return '$_temp0';
  }

  @override
  String statusBarRooms(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Räume',
      one: '1 Raum',
    );
    return '$_temp0';
  }

  @override
  String get wallToolLabel => 'Wand:';

  @override
  String get tooltipOrthoSnap => 'Orthogonal — nur H/V';

  @override
  String get orthoLabel => 'Ortho';

  @override
  String get tooltipRectangleMode => 'Rechteckmodus';

  @override
  String get rectangleLabel => 'Rechteck';

  @override
  String get saving => 'Speichern…';

  @override
  String get menuFile => 'Datei';

  @override
  String get menuNew => 'Neu';

  @override
  String get menuOpen => 'Öffnen…';

  @override
  String get menuSave => 'Speichern';

  @override
  String get menuSaveAs => 'Speichern unter…';

  @override
  String get menuExportPdf => 'PDF exportieren…';

  @override
  String get menuExportCsv => 'CSV exportieren…';

  @override
  String get menuEdit => 'Bearbeiten';

  @override
  String get menuUndo => 'Rückgängig';

  @override
  String get menuRedo => 'Wiederholen';

  @override
  String get menuDelete => 'Löschen';

  @override
  String get menuSelectAll => 'Alles auswählen';

  @override
  String get menuView => 'Ansicht';

  @override
  String get menuZoomIn => 'Vergrößern';

  @override
  String get menuZoomOut => 'Verkleinern';

  @override
  String get menuZoomToFit => 'Einpassen';

  @override
  String get menuTogglePropertiesPanel => 'Eigenschaftenpanel ein-/ausblenden';

  @override
  String get menuToggleDashboard => 'Dashboard ein-/ausblenden';

  @override
  String get menuTools => 'Werkzeuge';

  @override
  String get menuDrawWall => 'Wand zeichnen';

  @override
  String get menuPlaceWindow => 'Fenster platzieren';

  @override
  String get menuPlaceDoor => 'Tür platzieren';

  @override
  String get menuDrawFloorZone => 'Bodenzone zeichnen';

  @override
  String get menuPlaceDistributor => 'Verteiler platzieren';

  @override
  String get menuRoutePipe => 'Rohr verlegen';

  @override
  String get menuHelp => 'Hilfe';

  @override
  String get menuAbout => 'Über HeatingPlanner';

  @override
  String get menuDocumentation => 'Dokumentation';

  @override
  String get menuSettings => 'Einstellungen';

  @override
  String get dialogSaveProjectAs => 'Projekt speichern unter';

  @override
  String get properties => 'Eigenschaften';

  @override
  String get close => 'Schließen';

  @override
  String get save => 'Speichern';

  @override
  String get saved => 'Gespeichert';

  @override
  String get savingToFile => 'Datei wird gespeichert…';

  @override
  String get exportOutOfDate =>
      'Dateiexport nicht aktuell — Strg+S zum Aktualisieren drücken';

  @override
  String get allChangesSaved => 'Alle Änderungen in Datei gespeichert';

  @override
  String get newRoomDetected => 'Neuer Raum erkannt';

  @override
  String get roomNameLabel => 'Raumname';

  @override
  String get distributorAlreadyPlaced => 'Verteiler bereits platziert';

  @override
  String get distributorAlreadyPlacedContent =>
      'Auf dieser Etage existiert bereits ein Verteiler.\nAn die neue Position verschieben oder durch einen neuen ersetzen?';

  @override
  String get move => 'Verschieben';

  @override
  String get replace => 'Ersetzen';

  @override
  String get deleteDistributorTitle => 'Verteiler löschen?';

  @override
  String get deleteDistributorContent =>
      'Dies entfernt den Verteiler aus dem Grundriss.';

  @override
  String get room => 'Raum';

  @override
  String get nameLabel => 'Name';

  @override
  String targetTemperatureValue(String temp) {
    return 'Solltemperatur: $temp °C';
  }

  @override
  String get airChangeRate => 'Luftwechselrate';

  @override
  String get custom => 'Benutzerdefiniert';

  @override
  String get rateLabel => 'Rate';

  @override
  String get windowNotFound => 'Fenster nicht gefunden';

  @override
  String get doorNotFound => 'Tür nicht gefunden';

  @override
  String get typeLabel => 'Typ';

  @override
  String get widthLabel => 'Breite';

  @override
  String get heightLabel => 'Höhe';

  @override
  String get sillHeight => 'Brüstungshöhe';

  @override
  String get uValueLabel => 'U-Wert';

  @override
  String get circuitZoneRoom => 'Zone / Raum';

  @override
  String get circuitLengthM => 'Länge (m)';

  @override
  String get circuitFlowKgH => 'Durchfluss (kg/h)';

  @override
  String get circuitValveKpa => 'Ventil (kPa)';

  @override
  String get circuitStatus => 'Status';

  @override
  String get circuitNotFound => 'Heizkreis nicht gefunden';

  @override
  String get heatingCircuit => 'Heizkreis';

  @override
  String get supplyPipeInsulation => 'Vorlauf-Rohrisolierung';

  @override
  String get insulationNone => 'Keine (im Estrich)';

  @override
  String get insulationConduit => 'Wellrohr';

  @override
  String get insulationLayer => 'Isolierschicht';

  @override
  String get pipeLengths => 'Rohrlängen';

  @override
  String get supplyRoute => 'Vorlauf';

  @override
  String get returnRoute => 'Rücklauf';

  @override
  String get zoneTube => 'Zonenrohr';

  @override
  String get totalTube => 'Gesamtrohr';

  @override
  String get hydraulics => 'Hydraulik';

  @override
  String get flowRate => 'Volumenstrom';

  @override
  String get flowVelocity => 'Fließgeschwindigkeit';

  @override
  String get pressureLossLabel => 'Druckverlust';

  @override
  String get heatOutput => 'Heizleistung';

  @override
  String get deleteCircuit => 'Heizkreis löschen';

  @override
  String get distributor => 'Verteiler';

  @override
  String positionLabel(int x, int y) {
    return 'Position: ($x mm, $y mm)';
  }

  @override
  String get supplyTemperature => 'Vorlauftemperatur';

  @override
  String get returnTemperature => 'Rücklauftemperatur';

  @override
  String get pump => 'Pumpe';

  @override
  String get minPumpPressure => 'Min. erforderlicher Pumpendruck';

  @override
  String get pumpCapacityOptional => 'Pumpenleistung (optional)';

  @override
  String get saveAsPreset => 'Als Vorlage speichern';

  @override
  String get presetName => 'Vorlagenname';

  @override
  String get savedAsPreset => 'Als Vorlage gespeichert';

  @override
  String get loadPreset => 'Vorlage laden';

  @override
  String get load => 'Laden';

  @override
  String get constructionName => 'Konstruktionsname';

  @override
  String get addLayer => 'Schicht hinzufügen';

  @override
  String get noMaterialsAvailable =>
      'Keine Materialien verfügbar — bitte App neu starten';

  @override
  String get layerStack => 'Schichtaufbau  (außen → innen)';

  @override
  String get surfaceResistances => 'Oberflächenwiderstände (m²K/W):';

  @override
  String get wallConstructionTitle => 'Wandkonstruktion';

  @override
  String get newConstructionDefault => 'Neue Konstruktion';

  @override
  String get uValueEmpty => 'U-Wert: —';

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
    return 'Temperaturprofil  ($indoor°C → $outdoor°C)';
  }

  @override
  String get clearGapTooltip =>
      'Lichter Abstand zwischen Ständern, Kante zu Kante — nicht Achsabstand. Achsabstand = Ständerbreite + lichter Abstand.';

  @override
  String get addStudTooltip => 'Holzständer hinzufügen (inhomogene Schicht)';

  @override
  String get removeStudTooltip => 'Holzständer-Definition entfernen';

  @override
  String get timberStudLabel => 'Holzständer:';

  @override
  String get studWidthLabel => 'Ständerbreite';

  @override
  String get clearGapLabel => 'lichter Abstand';

  @override
  String get studWidthHint => 'Breite';

  @override
  String get studGapHint => 'Abstand';

  @override
  String get failedLoadMaterials => 'Fehler beim Laden der Materialien.';

  @override
  String get noMaterialsInPicker => 'Keine Materialien verfügbar.';

  @override
  String get noMatchingMaterials => 'Keine passenden Materialien.';

  @override
  String presetUValueLine(String value) {
    return 'U = $value';
  }

  @override
  String get heatingZone => 'Heizzone';

  @override
  String tubeSpacingValue(int value) {
    return 'Rohrabstand: $value mm';
  }

  @override
  String heightValue(int value) {
    return 'Höhe: $value mm';
  }

  @override
  String borderDistanceValue(int value) {
    return 'Randabstand: $value mm';
  }

  @override
  String get layoutPattern => 'Verlegemuster';

  @override
  String get tubeType => 'Rohrtyp';

  @override
  String get zoneOutput => 'Zonenleistung';

  @override
  String get rValueLabel => 'R-Wert';

  @override
  String get searchMaterials => 'Materialien suchen…';

  @override
  String get rotateDistributor => 'Verteiler drehen';

  @override
  String get projectSettings => 'Projekteinstellungen';

  @override
  String get designOutdoorTempDesc =>
      'Wird für alle Heizlastberechnungen verwendet (EN 12831).';

  @override
  String get defaultIndoorTempDesc =>
      'Wird auf neue Räume bei deren Erstellung angewendet.';

  @override
  String get defaultRoomHeight => 'Standard-Raumhöhe';

  @override
  String get defaultRoomHeightDesc =>
      'Wird als Standardhöhe für Wandheizungszonen verwendet.';

  @override
  String get unheatedSpaceTemp => 'Temperatur unbeheizter Räume';

  @override
  String get unheatedSpaceTempDesc =>
      'Standardtemperatur für unbeheizte Keller, Dachböden und angrenzende unbeheizte Räume.';

  @override
  String get drawingGridSizeDesc =>
      'Rasterabstand für Wände, Zonen und andere Elemente auf der Zeichenfläche.';

  @override
  String get tabHeatBalance => 'Wärmebilanz';

  @override
  String get tabHydraulic => 'Hydraulik';

  @override
  String get tabWarnings => 'Warnungen';

  @override
  String warningsWithCount(int count) {
    return 'Warnungen ($count)';
  }

  @override
  String get filterAll => 'Alle';

  @override
  String get filterErrorsOnly => 'Nur Fehler';

  @override
  String get filterWarningsOnly => 'Nur Warnungen';

  @override
  String get filterInfoOnly => 'Nur Info';

  @override
  String get filterLabel => 'Filter';

  @override
  String get noIssuesFound => 'Keine Probleme gefunden';

  @override
  String get emptyHeatBalance =>
      'Zeichnen Sie Räume, um die Wärmebilanz zu sehen.';

  @override
  String get demand => 'Bedarf';

  @override
  String get output => 'Leistung';

  @override
  String get balance => 'Bilanz';

  @override
  String get emptyHydraulic =>
      'Fügen Sie einen Verteiler hinzu und verbinden Sie Heizzonen, um hydraulische Daten zu sehen.';

  @override
  String get pressureLossByCircuit => 'Druckverlust pro Heizkreis (kPa)';

  @override
  String get pipeLoss => 'Rohrverlust';

  @override
  String get valveThrottling => 'Ventildrosselung';

  @override
  String get flowRateDistribution => 'Durchflussverteilung';

  @override
  String get unsavedExportFile => 'Nicht gespeicherte Exportdatei';

  @override
  String unsavedExportContent(String name) {
    return '\"$name\" hat Änderungen, die nicht in die .hsp-Datei gespeichert wurden.\n\nIhre Projektdaten sind sicher in der App gespeichert — nur die portable Exportdatei ist nicht aktuell.';
  }

  @override
  String get quitAnyway => 'Trotzdem beenden';

  @override
  String get saveFileAndQuit => 'Datei speichern und beenden';

  @override
  String get roomNotFound => 'Raum nicht gefunden';

  @override
  String get floorArea => 'Bodenfläche';

  @override
  String get roomVolume => 'Raumvolumen';

  @override
  String get wallsCount => 'Wände';

  @override
  String get heatDemand => 'Wärmebedarf';

  @override
  String get transmissionQt => 'Transmission Qᵀ';

  @override
  String get assignConstructionsHint =>
      'Weisen Sie Wänden Konstruktionen zu, um Transmissionsverluste zu berechnen.';

  @override
  String get transmissionFloor => 'Transmission — Boden';

  @override
  String get transmissionCeiling => 'Transmission — Decke';

  @override
  String get ventilationQv => 'Lüftung Qᴠ';

  @override
  String get totalHeatDemand => 'Gesamtwärmebedarf';

  @override
  String get specificHeatDemand => 'Spezifischer Wärmebedarf';

  @override
  String get envelopeFloorCeiling => 'Gebäudehülle — Boden & Decke';

  @override
  String get floorLabel => 'Boden';

  @override
  String get ceilingLabel => 'Decke';

  @override
  String get whatsBelow => 'Was ist darunter?';

  @override
  String get whatsAbove => 'Was ist darüber?';

  @override
  String get floorConstruction => 'Bodenkonstruktion';

  @override
  String get roofCeilingConstruction => 'Dach-/Deckenkonstruktion';

  @override
  String get notAssigned => 'Nicht zugewiesen';

  @override
  String get assignAction => '+ Zuweisen';

  @override
  String get editAction => 'Bearbeiten';

  @override
  String get adjacentRoomTemp => 'Temp. angrenzender Raum';

  @override
  String get unheatedSpaceTempShort => 'Temp. unbeheizter Raum';

  @override
  String defaultHint(String value) {
    return '$value (Standard)';
  }

  @override
  String get resetToProjectDefault => 'Auf Projektstandard zurücksetzen';

  @override
  String get boundaryGround => 'Erdreich (Bodenplatte)';

  @override
  String get boundaryUnheatedBelow =>
      'Unbeheizter Raum (Keller / Garage / Kriechkeller)';

  @override
  String get boundaryAdjacentBelow =>
      'Beheizter Nachbarraum (Boden über anderem Raum)';

  @override
  String get boundaryExteriorRoof => 'Außen / Dach';

  @override
  String get boundaryUnheatedAbove =>
      'Unbeheizter Raum (Dachboden / Garage / Kriechkeller)';

  @override
  String get boundaryAdjacentAbove =>
      'Beheizter Nachbarraum (Decke unter anderem Raum)';

  @override
  String get acrStandardRoom => 'Standardraum';

  @override
  String get acrKitchen => 'Küche';

  @override
  String get acrBathroom => 'Badezimmer';

  @override
  String get acrUtilityRoom => 'Hauswirtschaftsraum';

  @override
  String get acrServerRoom => 'Serverraum';

  @override
  String circuitsWithCount(int count) {
    return 'Heizkreise ($count)';
  }

  @override
  String get circuitDeltaPKpa => 'Δp (kPa)';

  @override
  String get noCircuits => 'Keine Heizkreise';

  @override
  String get noCircuitsHint =>
      'Fügen Sie einen Verteiler hinzu und zeichnen Sie Heizzonen, um hier Heizkreisdaten zu sehen.';

  @override
  String get wallSegment => 'Wandsegment';

  @override
  String get lengthLabel => 'Länge';

  @override
  String get orientationLabel => 'Ausrichtung';

  @override
  String get constructionLabel => 'Konstruktion';

  @override
  String get addConstruction => 'Konstruktion hinzufügen';

  @override
  String get editConstruction => 'Konstruktion bearbeiten';

  @override
  String get surfaceMaterial => 'Oberflächenmaterial';

  @override
  String get flooringMaterial => 'Bodenbelag';

  @override
  String get customEllipsis => 'Benutzerdefiniert…';

  @override
  String get zoneArea => 'Zonenfläche';

  @override
  String get tubeLengthLabel => 'Rohrlänge';

  @override
  String get specificOutput => 'Spezifische Leistung';

  @override
  String get totalOutput => 'Gesamtleistung';

  @override
  String get errorLoadingTubeTypes => 'Fehler beim Laden der Rohrtypen';

  @override
  String get errorLoadingFlooringMaterials =>
      'Fehler beim Laden der Bodenbelagmaterialien';

  @override
  String get projectSummary => 'Projektübersicht';

  @override
  String get rooms => 'Räume';

  @override
  String get walls => 'Wände';

  @override
  String get totalArea => 'Gesamtfläche';

  @override
  String get selectElementHint =>
      'Wählen Sie ein Element auf der Zeichenfläche aus, um seine Eigenschaften zu sehen.';

  @override
  String get wallNotFound => 'Wand nicht gefunden';

  @override
  String get typeWallLabel => 'Typ';

  @override
  String get surfaceTemperature => 'Oberflächentemperatur';

  @override
  String get materialCategory_masonry => 'Mauerwerk';

  @override
  String get materialCategory_concreteScreed => 'Beton & Estrich';

  @override
  String get materialCategory_insulationBoards => 'Dämmplatten';

  @override
  String get materialCategory_looseFillBlowIn =>
      'Schüttdämmung / Einblasdämmung';

  @override
  String get materialCategory_wood => 'Holz';

  @override
  String get materialCategory_plasterMortar => 'Putz & Mörtel';

  @override
  String get materialCategory_boardMaterials => 'Plattenwerkstoffe';

  @override
  String get materialCategory_floorCovering => 'Bodenbelag';

  @override
  String get materialCategory_glass => 'Glas';

  @override
  String get materialSubcategory_historicBrick => 'Historischer Ziegel';

  @override
  String get materialSubcategory_modernThermalBrick =>
      'Moderner Wärmedämmziegel';

  @override
  String get materialSubcategory_calciumSilicate => 'Kalksandstein';

  @override
  String get materialSubcategory_aacAeratedConcrete => 'Porenbeton';

  @override
  String get materialSubcategory_normalConcrete => 'Normalbeton';

  @override
  String get materialSubcategory_lightweightConcrete => 'Leichtbeton';

  @override
  String get materialSubcategory_screed => 'Estrich';

  @override
  String get materialSubcategory_rigidFoamEps => 'Hartschaum, EPS';

  @override
  String get materialSubcategory_rigidFoamXps => 'Hartschaum, XPS';

  @override
  String get materialSubcategory_rigidFoamPurPir => 'Hartschaum, PUR/PIR';

  @override
  String get materialSubcategory_rigidFoamPhenolic => 'Hartschaum, Phenol';

  @override
  String get materialSubcategory_stoneWoolBoard => 'Steinwolle-Platte';

  @override
  String get materialSubcategory_glassWoolBoardRoll =>
      'Glaswolle-Platte/-Rolle';

  @override
  String get materialSubcategory_woodFibre => 'Holzfaserplatte';

  @override
  String get materialSubcategory_calciumSilicateBoard => 'Kalziumsilikatplatte';

  @override
  String get materialSubcategory_cellularGlass => 'Schaumglas';

  @override
  String get materialSubcategory_cork => 'Kork';

  @override
  String get materialSubcategory_vacuumInsulation => 'Vakuumdämmung';

  @override
  String get materialSubcategory_cellulose => 'Zellulose';

  @override
  String get materialSubcategory_mineralWoolBlowIn =>
      'Mineralwolle-Einblasdämmung';

  @override
  String get materialSubcategory_perlite => 'Perlit';

  @override
  String get materialSubcategory_vermiculite => 'Vermiculit';

  @override
  String get materialSubcategory_naturalFibre => 'Naturfaser';

  @override
  String get materialSubcategory_structuralTimber => 'Bauholz';

  @override
  String get materialSubcategory_engineeredWood => 'Holzwerkstoff';

  @override
  String get materialSubcategory_cementLime => 'Zement/Kalk';

  @override
  String get materialSubcategory_clay => 'Lehm';

  @override
  String get materialSubcategory_gypsum => 'Gips';

  @override
  String get materialSubcategory_insulationPlaster => 'Wärmedämmputz';

  @override
  String get materialSubcategory_gypsumBoard => 'Gipskartonplatte';

  @override
  String get materialSubcategory_tileNaturalStone => 'Fliesen / Naturstein';

  @override
  String get materialSubcategory_woodLaminateVinyl => 'Holz / Laminat / Vinyl';

  @override
  String get perfDashboard_tabHeatBalance => 'Wärmebilanz';

  @override
  String get perfDashboard_tabHydraulic => 'Hydraulik';

  @override
  String get perfDashboard_tabWarnings => 'Warnungen';

  @override
  String perfDashboard_warningsHeader(int count) {
    return 'Warnungen ($count)';
  }

  @override
  String get perfDashboard_filterErrorsOnly => 'Nur Fehler';

  @override
  String get perfDashboard_filterWarningsOnly => 'Nur Warnungen';

  @override
  String get perfDashboard_filterInfoOnly => 'Nur Hinweise';

  @override
  String get perfDashboard_noIssuesFound => 'Keine Probleme gefunden';

  @override
  String get perfDashboard_emptyHeatBalance =>
      'Räume zeichnen, um die Wärmebilanz zu sehen.';

  @override
  String get perfDashboard_legendDemand => 'Bedarf';

  @override
  String get perfDashboard_legendOutput => 'Leistung';

  @override
  String get perfDashboard_legendBalance => 'Bilanz';

  @override
  String get perfDashboard_legendPipeLoss => 'Rohrreibungsverlust';

  @override
  String get perfDashboard_legendValveThrottling => 'Ventildrosselung';

  @override
  String get severity_error => 'Fehler';

  @override
  String get severity_warning => 'Warnung';

  @override
  String get severity_info => 'Hinweis';

  @override
  String get zoneMissing_noCircuitConnected => 'Kein Heizkreis verbunden';

  @override
  String get zoneMissing_noDistributorPlaced => 'Kein Verteiler platziert';

  @override
  String get zoneMissing_noTubeTypeSelected => 'Kein Rohrtyp ausgewählt';

  @override
  String get zoneMissing_noFlooringMaterialSelected =>
      'Kein Bodenbelag ausgewählt';

  @override
  String get zoneMissing_noTubeTypesAvailable => 'Keine Rohrtypen verfügbar';

  @override
  String get roomMissing_noExteriorWallsDefined => 'Keine Außenwände definiert';

  @override
  String get circuit_fullHeatOutputToTransitRoom =>
      'Vollständige Wärmeabgabe an den Durchgangsraum';

  @override
  String get circuit_noHeatOutputToTransitRoom =>
      'Keine Wärmeabgabe an den Durchgangsraum';

  @override
  String get opening_updateWindow => 'Fenster aktualisieren';

  @override
  String get opening_updateDoor => 'Tür aktualisieren';

  @override
  String get undo_rotateDistributor => 'Verteiler drehen';

  @override
  String get undo_deleteWall => 'Wand löschen';

  @override
  String get undo_deleteRoom => 'Raum löschen';

  @override
  String get undo_deleteWindow => 'Fenster löschen';

  @override
  String get undo_deleteDoor => 'Tür löschen';

  @override
  String get undo_deleteCircuit => 'Heizkreis löschen';

  @override
  String get undo_deleteZone => 'Heizzone löschen';

  @override
  String get undo_deleteDistributor => 'Verteiler löschen';

  @override
  String canvas_defaultRoomName(int roomNumber) {
    return 'Raum $roomNumber';
  }
}
