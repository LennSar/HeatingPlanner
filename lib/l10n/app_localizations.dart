import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// Application name shown in title bar and project list
  ///
  /// In en, this message translates to:
  /// **'HeatingPlanner'**
  String get appTitle;

  /// Label for the language selector in settings
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// Display name for the English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Display name for the German language option
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// Label for the grid spacing selector in settings
  ///
  /// In en, this message translates to:
  /// **'Drawing Grid Size'**
  String get settingsDrawingGridSize;

  /// Button and dialog title for creating a new project
  ///
  /// In en, this message translates to:
  /// **'New Project'**
  String get newProject;

  /// Error message when the project list fails to load
  ///
  /// In en, this message translates to:
  /// **'Error loading projects: {error}'**
  String errorLoadingProjects(String error);

  /// Heading shown when the project list is empty
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get noProjectsYet;

  /// Subtitle shown below the empty-state heading
  ///
  /// In en, this message translates to:
  /// **'Create your first heating plan to get started.'**
  String get createFirstProject;

  /// Label for the project name text field
  ///
  /// In en, this message translates to:
  /// **'Project name *'**
  String get projectNameLabel;

  /// Hint text inside the project name field
  ///
  /// In en, this message translates to:
  /// **'e.g. Villa Schmidt'**
  String get projectNameHint;

  /// Validation error when the name field is empty
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameIsRequired;

  /// Label for the outdoor design temperature slider
  ///
  /// In en, this message translates to:
  /// **'Design outdoor temperature'**
  String get designOutdoorTemperature;

  /// Label for the default indoor temperature slider
  ///
  /// In en, this message translates to:
  /// **'Default indoor temperature'**
  String get defaultIndoorTemperature;

  /// Generic cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Button label for creating a new project
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Context menu action to duplicate a project
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicateAction;

  /// Generic delete button or menu item label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Title of the project deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete project?'**
  String get deleteProjectTitle;

  /// Body text of the project deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String deleteProjectContent(String name);

  /// Default name assigned to the first floor of a new project
  ///
  /// In en, this message translates to:
  /// **'Ground Floor'**
  String get defaultFloorName;

  /// Name pattern for duplicated projects
  ///
  /// In en, this message translates to:
  /// **'{name} (copy)'**
  String projectCopyName(String name);

  /// Relative timestamp for less than one minute ago
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get relativeJustNow;

  /// Relative timestamp in minutes
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String relativeMinutesAgo(int count);

  /// Relative timestamp in hours
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String relativeHoursAgo(int count);

  /// Relative timestamp in days
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String relativeDaysAgo(int count);

  /// Relative timestamp in weeks
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week ago} other{{count} weeks ago}}'**
  String relativeWeeksAgo(int count);

  /// Relative timestamp in months
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month ago} other{{count} months ago}}'**
  String relativeMonthsAgo(int count);

  /// Relative timestamp in years
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year ago} other{{count} years ago}}'**
  String relativeYearsAgo(int count);

  /// Toolbar tooltip for the selection tool
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get toolSelect;

  /// Toolbar tooltip for the wall drawing tool
  ///
  /// In en, this message translates to:
  /// **'Wall'**
  String get toolWall;

  /// Toolbar tooltip for the window placement tool
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get toolWindow;

  /// Toolbar tooltip for the door placement tool
  ///
  /// In en, this message translates to:
  /// **'Door'**
  String get toolDoor;

  /// Toolbar tooltip for the floor heating zone tool
  ///
  /// In en, this message translates to:
  /// **'Floor Zone'**
  String get toolFloorZone;

  /// Toolbar tooltip for the wall heating zone tool
  ///
  /// In en, this message translates to:
  /// **'Wall Zone'**
  String get toolWallZone;

  /// Toolbar tooltip for the distributor placement tool
  ///
  /// In en, this message translates to:
  /// **'Distributor'**
  String get toolDistributor;

  /// Toolbar tooltip for the pipe routing tool
  ///
  /// In en, this message translates to:
  /// **'Pipe'**
  String get toolPipe;

  /// Toolbar tooltip for the measurement tool
  ///
  /// In en, this message translates to:
  /// **'Measure'**
  String get toolMeasure;

  /// Tooltip for the Open file toolbar button
  ///
  /// In en, this message translates to:
  /// **'Open (Ctrl+O)'**
  String get tooltipOpen;

  /// Tooltip for the Save toolbar button
  ///
  /// In en, this message translates to:
  /// **'Save (Ctrl+S)'**
  String get tooltipSave;

  /// Tooltip for the Save As toolbar button
  ///
  /// In en, this message translates to:
  /// **'Save As (Ctrl+Shift+S)'**
  String get tooltipSaveAs;

  /// Tooltip for the dashboard toggle button
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get tooltipDashboard;

  /// Tooltip for the project settings button
  ///
  /// In en, this message translates to:
  /// **'Project Settings'**
  String get tooltipProjectSettings;

  /// Zoom level display in the editor status bar
  ///
  /// In en, this message translates to:
  /// **'Zoom: {percent}%'**
  String statusBarZoom(int percent);

  /// Warning count in the editor status bar
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 warning} other{{count} warnings}}'**
  String statusBarWarnings(int count);

  /// Room count in the editor status bar
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 room} other{{count} rooms}}'**
  String statusBarRooms(int count);

  /// Label shown in the tablet wall-tool options bar
  ///
  /// In en, this message translates to:
  /// **'Wall:'**
  String get wallToolLabel;

  /// Tooltip for the ortho-snap toggle
  ///
  /// In en, this message translates to:
  /// **'Ortho snap — H/V only'**
  String get tooltipOrthoSnap;

  /// Short label on the ortho-snap toggle button
  ///
  /// In en, this message translates to:
  /// **'Ortho'**
  String get orthoLabel;

  /// Tooltip for the rectangle mode toggle
  ///
  /// In en, this message translates to:
  /// **'Rectangle mode'**
  String get tooltipRectangleMode;

  /// Short label on the rectangle mode toggle button
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get rectangleLabel;

  /// Status text shown in window title during auto-export
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// Top-level File menu label
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get menuFile;

  /// File > New menu item
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get menuNew;

  /// File > Open menu item
  ///
  /// In en, this message translates to:
  /// **'Open…'**
  String get menuOpen;

  /// File > Save menu item
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get menuSave;

  /// File > Save As menu item
  ///
  /// In en, this message translates to:
  /// **'Save As…'**
  String get menuSaveAs;

  /// File > Export PDF menu item
  ///
  /// In en, this message translates to:
  /// **'Export PDF…'**
  String get menuExportPdf;

  /// File > Export CSV menu item
  ///
  /// In en, this message translates to:
  /// **'Export CSV…'**
  String get menuExportCsv;

  /// File > Close Project menu item — returns to the Project List screen
  ///
  /// In en, this message translates to:
  /// **'Close Project'**
  String get closeProject;

  /// Top-level Edit menu label
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEdit;

  /// Edit > Undo menu item
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get menuUndo;

  /// Edit > Redo menu item
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get menuRedo;

  /// Edit > Delete menu item
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get menuDelete;

  /// Edit > Select All menu item
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get menuSelectAll;

  /// Top-level View menu label
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get menuView;

  /// View > Zoom In menu item
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get menuZoomIn;

  /// View > Zoom Out menu item
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get menuZoomOut;

  /// View > Zoom to Fit menu item
  ///
  /// In en, this message translates to:
  /// **'Zoom to Fit'**
  String get menuZoomToFit;

  /// View > Toggle Properties Panel menu item
  ///
  /// In en, this message translates to:
  /// **'Toggle Properties Panel'**
  String get menuTogglePropertiesPanel;

  /// View > Toggle Dashboard menu item
  ///
  /// In en, this message translates to:
  /// **'Toggle Dashboard'**
  String get menuToggleDashboard;

  /// Top-level Tools menu label
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get menuTools;

  /// Tools > Draw Wall menu item
  ///
  /// In en, this message translates to:
  /// **'Draw Wall'**
  String get menuDrawWall;

  /// Tools > Place Window menu item
  ///
  /// In en, this message translates to:
  /// **'Place Window'**
  String get menuPlaceWindow;

  /// Tools > Place Door menu item
  ///
  /// In en, this message translates to:
  /// **'Place Door'**
  String get menuPlaceDoor;

  /// Tools > Draw Floor Zone menu item
  ///
  /// In en, this message translates to:
  /// **'Draw Floor Zone'**
  String get menuDrawFloorZone;

  /// Tools > Place Distributor menu item
  ///
  /// In en, this message translates to:
  /// **'Place Distributor'**
  String get menuPlaceDistributor;

  /// Tools > Route Pipe menu item
  ///
  /// In en, this message translates to:
  /// **'Route Pipe'**
  String get menuRoutePipe;

  /// Top-level Help menu label
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get menuHelp;

  /// Help > About menu item
  ///
  /// In en, this message translates to:
  /// **'About HeatingPlanner'**
  String get menuAbout;

  /// Help > Documentation menu item
  ///
  /// In en, this message translates to:
  /// **'Documentation'**
  String get menuDocumentation;

  /// Title of the system save-file dialog
  ///
  /// In en, this message translates to:
  /// **'Save Project As'**
  String get dialogSaveProjectAs;

  /// Panel heading for properties inspector
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get properties;

  /// Generic close button label
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Generic save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Save state indicator label
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// Tooltip during auto-export save
  ///
  /// In en, this message translates to:
  /// **'Saving to file…'**
  String get savingToFile;

  /// Tooltip when file export needs updating
  ///
  /// In en, this message translates to:
  /// **'File export out of date — press Ctrl+S to update'**
  String get exportOutOfDate;

  /// Tooltip when file export is current
  ///
  /// In en, this message translates to:
  /// **'All changes saved to file'**
  String get allChangesSaved;

  /// Dialog title when walls form a closed room
  ///
  /// In en, this message translates to:
  /// **'New Room Detected'**
  String get newRoomDetected;

  /// Label for room name field in new room dialog
  ///
  /// In en, this message translates to:
  /// **'Room name'**
  String get roomNameLabel;

  /// Dialog title for duplicate distributor
  ///
  /// In en, this message translates to:
  /// **'Distributor already placed'**
  String get distributorAlreadyPlaced;

  /// Dialog body for duplicate distributor
  ///
  /// In en, this message translates to:
  /// **'A distributor already exists on this floor.\nMove it to the new position, or replace it with a fresh one?'**
  String get distributorAlreadyPlacedContent;

  /// Button to move element to new position
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// Button to replace element
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// Confirmation dialog title for distributor deletion
  ///
  /// In en, this message translates to:
  /// **'Delete distributor?'**
  String get deleteDistributorTitle;

  /// Confirmation dialog body for distributor deletion
  ///
  /// In en, this message translates to:
  /// **'This will remove the distributor from the floor plan.'**
  String get deleteDistributorContent;

  /// Section heading in room properties
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get room;

  /// Label for name text field
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// Room target temperature with value
  ///
  /// In en, this message translates to:
  /// **'Target Temperature: {temp} °C'**
  String targetTemperatureValue(String temp);

  /// Label for air change rate dropdown
  ///
  /// In en, this message translates to:
  /// **'Air Change Rate'**
  String get airChangeRate;

  /// Option label for custom input
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// Label for custom air change rate field
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rateLabel;

  /// Error when selected window no longer exists
  ///
  /// In en, this message translates to:
  /// **'Window not found'**
  String get windowNotFound;

  /// Error when selected door no longer exists
  ///
  /// In en, this message translates to:
  /// **'Door not found'**
  String get doorNotFound;

  /// Label for element type selector
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// Label for width dimension field
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get widthLabel;

  /// Label for height dimension field
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get heightLabel;

  /// Label for sill height field
  ///
  /// In en, this message translates to:
  /// **'Sill Height'**
  String get sillHeight;

  /// Label for thermal transmittance field
  ///
  /// In en, this message translates to:
  /// **'U-Value'**
  String get uValueLabel;

  /// Column header in circuit overview
  ///
  /// In en, this message translates to:
  /// **'Zone / Room'**
  String get circuitZoneRoom;

  /// Column header for pipe length
  ///
  /// In en, this message translates to:
  /// **'Length (m)'**
  String get circuitLengthM;

  /// Column header for flow rate
  ///
  /// In en, this message translates to:
  /// **'Flow (kg/h)'**
  String get circuitFlowKgH;

  /// Column header for valve pressure
  ///
  /// In en, this message translates to:
  /// **'Valve (kPa)'**
  String get circuitValveKpa;

  /// Column header for circuit status
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get circuitStatus;

  /// Error when selected circuit no longer exists
  ///
  /// In en, this message translates to:
  /// **'Circuit not found'**
  String get circuitNotFound;

  /// Section heading in circuit properties
  ///
  /// In en, this message translates to:
  /// **'Heating Circuit'**
  String get heatingCircuit;

  /// Section label for insulation selection
  ///
  /// In en, this message translates to:
  /// **'Supply pipe insulation'**
  String get supplyPipeInsulation;

  /// Radio option for no insulation
  ///
  /// In en, this message translates to:
  /// **'None (in screed)'**
  String get insulationNone;

  /// Radio option for conduit insulation
  ///
  /// In en, this message translates to:
  /// **'Corrugated conduit'**
  String get insulationConduit;

  /// Radio option for insulation layer
  ///
  /// In en, this message translates to:
  /// **'Insulation layer'**
  String get insulationLayer;

  /// Section label for pipe length info
  ///
  /// In en, this message translates to:
  /// **'Pipe lengths'**
  String get pipeLengths;

  /// Label for supply pipe length
  ///
  /// In en, this message translates to:
  /// **'Supply route'**
  String get supplyRoute;

  /// Label for return pipe length
  ///
  /// In en, this message translates to:
  /// **'Return route'**
  String get returnRoute;

  /// Label for zone tube length
  ///
  /// In en, this message translates to:
  /// **'Zone tube'**
  String get zoneTube;

  /// Label for total tube length
  ///
  /// In en, this message translates to:
  /// **'Total tube'**
  String get totalTube;

  /// Section label for hydraulic results
  ///
  /// In en, this message translates to:
  /// **'Hydraulics'**
  String get hydraulics;

  /// Label for flow rate value
  ///
  /// In en, this message translates to:
  /// **'Flow rate'**
  String get flowRate;

  /// Label for flow velocity value
  ///
  /// In en, this message translates to:
  /// **'Flow velocity'**
  String get flowVelocity;

  /// Label for pressure loss value
  ///
  /// In en, this message translates to:
  /// **'Pressure loss'**
  String get pressureLossLabel;

  /// Label for heat output value
  ///
  /// In en, this message translates to:
  /// **'Heat output'**
  String get heatOutput;

  /// Button to delete a heating circuit
  ///
  /// In en, this message translates to:
  /// **'Delete circuit'**
  String get deleteCircuit;

  /// Section heading in distributor properties
  ///
  /// In en, this message translates to:
  /// **'Distributor'**
  String get distributor;

  /// Distributor position coordinates
  ///
  /// In en, this message translates to:
  /// **'Position: ({x} mm, {y} mm)'**
  String positionLabel(int x, int y);

  /// Label for supply temperature slider
  ///
  /// In en, this message translates to:
  /// **'Supply Temperature'**
  String get supplyTemperature;

  /// Label for return temperature slider
  ///
  /// In en, this message translates to:
  /// **'Return Temperature'**
  String get returnTemperature;

  /// Section heading for pump properties
  ///
  /// In en, this message translates to:
  /// **'Pump'**
  String get pump;

  /// Label for minimum pump pressure
  ///
  /// In en, this message translates to:
  /// **'Min. required pump pressure'**
  String get minPumpPressure;

  /// Label for optional pump capacity
  ///
  /// In en, this message translates to:
  /// **'Pump Capacity (optional)'**
  String get pumpCapacityOptional;

  /// Dialog title / button for saving construction preset
  ///
  /// In en, this message translates to:
  /// **'Save as preset'**
  String get saveAsPreset;

  /// Label for preset name field
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get presetName;

  /// Snackbar confirmation for preset save
  ///
  /// In en, this message translates to:
  /// **'Saved as preset'**
  String get savedAsPreset;

  /// Dialog title for loading construction preset
  ///
  /// In en, this message translates to:
  /// **'Load preset'**
  String get loadPreset;

  /// Generic load button label
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get load;

  /// Label for wall construction name field
  ///
  /// In en, this message translates to:
  /// **'Construction name'**
  String get constructionName;

  /// Button to add a material layer
  ///
  /// In en, this message translates to:
  /// **'Add Layer'**
  String get addLayer;

  /// Snackbar shown when Add Layer is pressed but the material catalogue is empty
  ///
  /// In en, this message translates to:
  /// **'No materials available — try restarting the app'**
  String get noMaterialsAvailable;

  /// Section heading for material layer list
  ///
  /// In en, this message translates to:
  /// **'Layer Stack  (outside → inside)'**
  String get layerStack;

  /// Label for surface resistance inputs
  ///
  /// In en, this message translates to:
  /// **'Surface resistances (m²K/W):'**
  String get surfaceResistances;

  /// Header title of the wall construction editor dialog
  ///
  /// In en, this message translates to:
  /// **'Wall Construction'**
  String get wallConstructionTitle;

  /// Default name pre-filled when creating a new wall construction
  ///
  /// In en, this message translates to:
  /// **'New Construction'**
  String get newConstructionDefault;

  /// Placeholder shown for U-value when the layer stack does not yield a finite result
  ///
  /// In en, this message translates to:
  /// **'U-Value: —'**
  String get uValueEmpty;

  /// Placeholder shown for total thermal resistance when no finite result is available
  ///
  /// In en, this message translates to:
  /// **'R: —'**
  String get rValueEmpty;

  /// Formatted U-value display (symbol + numeric value + unit). The symbol U and unit W/(m²K) stay in English in all locales.
  ///
  /// In en, this message translates to:
  /// **'U  {value} W/(m²K)'**
  String uValueDisplay(String value);

  /// Formatted thermal resistance display (symbol + numeric value + unit). The symbol R and unit m²K/W stay in English in all locales.
  ///
  /// In en, this message translates to:
  /// **'R  {value} m²K/W'**
  String rValueDisplay(String value);

  /// Header above the temperature gradient bar, showing indoor and outdoor design temperatures
  ///
  /// In en, this message translates to:
  /// **'Temperature Profile  ({indoor}°C → {outdoor}°C)'**
  String temperatureProfileWithRange(String indoor, String outdoor);

  /// Tooltip explaining how the clear-gap dimension differs from centre-to-centre stud spacing
  ///
  /// In en, this message translates to:
  /// **'Clear distance between studs, edge to edge — not centre-to-centre. Centre-to-centre spacing = stud width + clear gap.'**
  String get clearGapTooltip;

  /// Tooltip on the add-stud icon button in a layer row
  ///
  /// In en, this message translates to:
  /// **'Add timber stud (inhomogeneous layer)'**
  String get addStudTooltip;

  /// Tooltip on the remove-stud icon button in a layer row
  ///
  /// In en, this message translates to:
  /// **'Remove stud definition'**
  String get removeStudTooltip;

  /// Inline label introducing the timber-stud sub-row of an inhomogeneous layer
  ///
  /// In en, this message translates to:
  /// **'Timber stud:'**
  String get timberStudLabel;

  /// Caption next to the stud width input field
  ///
  /// In en, this message translates to:
  /// **'stud width'**
  String get studWidthLabel;

  /// Caption next to the clear-gap input field
  ///
  /// In en, this message translates to:
  /// **'clear gap'**
  String get clearGapLabel;

  /// Placeholder text shown inside the empty stud width field
  ///
  /// In en, this message translates to:
  /// **'width'**
  String get studWidthHint;

  /// Placeholder text shown inside the empty clear-gap field
  ///
  /// In en, this message translates to:
  /// **'gap'**
  String get studGapHint;

  /// Error shown in the material picker when the catalogue cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'Failed to load materials.'**
  String get failedLoadMaterials;

  /// Empty state in the material picker when the catalogue is empty
  ///
  /// In en, this message translates to:
  /// **'No materials available.'**
  String get noMaterialsInPicker;

  /// Empty state in the material picker when the search query has no matches
  ///
  /// In en, this message translates to:
  /// **'No matching materials.'**
  String get noMatchingMaterials;

  /// Subtitle line under each construction preset, showing the preset's U-value (the placeholder already includes the unit, or an em dash when not finite). The symbol U stays in English in all locales.
  ///
  /// In en, this message translates to:
  /// **'U = {value}'**
  String presetUValueLine(String value);

  /// Section heading in zone properties
  ///
  /// In en, this message translates to:
  /// **'Heating Zone'**
  String get heatingZone;

  /// Zone tube spacing with value
  ///
  /// In en, this message translates to:
  /// **'Tube Spacing: {value} mm'**
  String tubeSpacingValue(int value);

  /// Wall zone height with value
  ///
  /// In en, this message translates to:
  /// **'Height: {value} mm'**
  String heightValue(int value);

  /// Floor zone border distance with value
  ///
  /// In en, this message translates to:
  /// **'Border Distance: {value} mm'**
  String borderDistanceValue(int value);

  /// Section label for tube layout pattern
  ///
  /// In en, this message translates to:
  /// **'Layout Pattern'**
  String get layoutPattern;

  /// Section label for tube type selection
  ///
  /// In en, this message translates to:
  /// **'Tube Type'**
  String get tubeType;

  /// Section heading for zone heat output
  ///
  /// In en, this message translates to:
  /// **'Zone Output'**
  String get zoneOutput;

  /// Label for custom floor covering R-value
  ///
  /// In en, this message translates to:
  /// **'R value'**
  String get rValueLabel;

  /// Hint text in material search field
  ///
  /// In en, this message translates to:
  /// **'Search materials…'**
  String get searchMaterials;

  /// Undo label for distributor rotation
  ///
  /// In en, this message translates to:
  /// **'Rotate distributor'**
  String get rotateDistributor;

  /// Title of project settings dialog
  ///
  /// In en, this message translates to:
  /// **'Project Settings'**
  String get projectSettings;

  /// Description for outdoor temperature setting
  ///
  /// In en, this message translates to:
  /// **'Used in all heat-demand calculations (EN 12831).'**
  String get designOutdoorTempDesc;

  /// Description for indoor temperature setting
  ///
  /// In en, this message translates to:
  /// **'Applied to new rooms when they are created.'**
  String get defaultIndoorTempDesc;

  /// Label for default room height setting
  ///
  /// In en, this message translates to:
  /// **'Default Room Height'**
  String get defaultRoomHeight;

  /// Description for room height setting
  ///
  /// In en, this message translates to:
  /// **'Used as the default height for wall heating zones.'**
  String get defaultRoomHeightDesc;

  /// Label for unheated space temperature
  ///
  /// In en, this message translates to:
  /// **'Unheated Space Temperature'**
  String get unheatedSpaceTemp;

  /// Description for unheated space temperature
  ///
  /// In en, this message translates to:
  /// **'Default temperature used for unheated basements, attics, and adjacent unheated spaces.'**
  String get unheatedSpaceTempDesc;

  /// Description for drawing grid size setting
  ///
  /// In en, this message translates to:
  /// **'Snap interval for walls, zones, and other elements on the canvas.'**
  String get drawingGridSizeDesc;

  /// Slider range hint under the outdoor design temperature input
  ///
  /// In en, this message translates to:
  /// **'−50 to +10 °C'**
  String get designOutdoorTempRange;

  /// Slider range hint under the default indoor temperature input
  ///
  /// In en, this message translates to:
  /// **'15 to 30 °C'**
  String get defaultIndoorTempRange;

  /// Slider range hint under the default room height input
  ///
  /// In en, this message translates to:
  /// **'2000 to 6000 mm'**
  String get defaultRoomHeightRange;

  /// Slider range hint under the unheated space temperature input
  ///
  /// In en, this message translates to:
  /// **'0 to 25 °C'**
  String get unheatedSpaceTempRange;

  /// Dashboard tab for heat balance
  ///
  /// In en, this message translates to:
  /// **'Heat Balance'**
  String get tabHeatBalance;

  /// Dashboard tab for hydraulic view
  ///
  /// In en, this message translates to:
  /// **'Hydraulic'**
  String get tabHydraulic;

  /// Dashboard tab for warnings
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get tabWarnings;

  /// Warning tab label with count
  ///
  /// In en, this message translates to:
  /// **'Warnings ({count})'**
  String warningsWithCount(int count);

  /// Filter option to show all items
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// Filter for errors only
  ///
  /// In en, this message translates to:
  /// **'Errors only'**
  String get filterErrorsOnly;

  /// Filter for warnings only
  ///
  /// In en, this message translates to:
  /// **'Warnings only'**
  String get filterWarningsOnly;

  /// Filter for info only
  ///
  /// In en, this message translates to:
  /// **'Info only'**
  String get filterInfoOnly;

  /// Generic filter label
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filterLabel;

  /// Empty state for warnings tab
  ///
  /// In en, this message translates to:
  /// **'No issues found'**
  String get noIssuesFound;

  /// Empty state for heat balance tab
  ///
  /// In en, this message translates to:
  /// **'Draw rooms to see the heat balance.'**
  String get emptyHeatBalance;

  /// Label for heat demand in summary
  ///
  /// In en, this message translates to:
  /// **'Demand'**
  String get demand;

  /// Label for heat output in summary
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get output;

  /// Label for heat balance in summary
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// Empty state for hydraulic tab
  ///
  /// In en, this message translates to:
  /// **'Add a distributor and connect heating zones to see hydraulic data.'**
  String get emptyHydraulic;

  /// Chart title for pressure loss
  ///
  /// In en, this message translates to:
  /// **'Pressure Loss by Circuit (kPa)'**
  String get pressureLossByCircuit;

  /// Legend label for pipe loss
  ///
  /// In en, this message translates to:
  /// **'Pipe loss'**
  String get pipeLoss;

  /// Legend label for valve throttling
  ///
  /// In en, this message translates to:
  /// **'Valve throttling'**
  String get valveThrottling;

  /// Chart title for flow distribution
  ///
  /// In en, this message translates to:
  /// **'Flow Rate Distribution'**
  String get flowRateDistribution;

  /// Title of unsaved changes dialog
  ///
  /// In en, this message translates to:
  /// **'Unsaved export file'**
  String get unsavedExportFile;

  /// Body of unsaved changes dialog
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" has changes that have not been saved to the .hsp file.\n\nYour project data is safely stored in the app — only the portable export file is out of date.'**
  String unsavedExportContent(String name);

  /// Button to close without saving
  ///
  /// In en, this message translates to:
  /// **'Quit Anyway'**
  String get quitAnyway;

  /// Button to save and close
  ///
  /// In en, this message translates to:
  /// **'Save File and Quit'**
  String get saveFileAndQuit;

  /// Button to close the project without saving the .hsp export
  ///
  /// In en, this message translates to:
  /// **'Close Without Saving'**
  String get closeWithoutSaving;

  /// Button to save the .hsp export and then close the project
  ///
  /// In en, this message translates to:
  /// **'Save File and Close'**
  String get saveFileAndClose;

  /// Error when selected room no longer exists
  ///
  /// In en, this message translates to:
  /// **'Room not found'**
  String get roomNotFound;

  /// Read-only row label for room floor area
  ///
  /// In en, this message translates to:
  /// **'Floor Area'**
  String get floorArea;

  /// Read-only row label for room volume
  ///
  /// In en, this message translates to:
  /// **'Room Volume'**
  String get roomVolume;

  /// Read-only row label for wall count
  ///
  /// In en, this message translates to:
  /// **'Walls'**
  String get wallsCount;

  /// Section heading for heat demand
  ///
  /// In en, this message translates to:
  /// **'Heat Demand'**
  String get heatDemand;

  /// Label for transmission heat loss
  ///
  /// In en, this message translates to:
  /// **'Transmission Qᵀ'**
  String get transmissionQt;

  /// Hint when no constructions are assigned
  ///
  /// In en, this message translates to:
  /// **'Assign constructions to walls for transmission loss.'**
  String get assignConstructionsHint;

  /// Label for floor transmission loss
  ///
  /// In en, this message translates to:
  /// **'Transmission — floor'**
  String get transmissionFloor;

  /// Label for ceiling transmission loss
  ///
  /// In en, this message translates to:
  /// **'Transmission — ceiling'**
  String get transmissionCeiling;

  /// Label for ventilation heat loss
  ///
  /// In en, this message translates to:
  /// **'Ventilation Qᴠ'**
  String get ventilationQv;

  /// Label for total heat demand
  ///
  /// In en, this message translates to:
  /// **'Total Heat Demand'**
  String get totalHeatDemand;

  /// Label for specific heat demand per m²
  ///
  /// In en, this message translates to:
  /// **'Specific Heat Demand'**
  String get specificHeatDemand;

  /// Expansion tile heading for envelope section
  ///
  /// In en, this message translates to:
  /// **'Envelope — Floor & Ceiling'**
  String get envelopeFloorCeiling;

  /// Subsection heading for floor boundary
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get floorLabel;

  /// Subsection heading for ceiling boundary
  ///
  /// In en, this message translates to:
  /// **'Ceiling'**
  String get ceilingLabel;

  /// Label for floor boundary dropdown
  ///
  /// In en, this message translates to:
  /// **'What\'s below?'**
  String get whatsBelow;

  /// Label for ceiling boundary dropdown
  ///
  /// In en, this message translates to:
  /// **'What\'s above?'**
  String get whatsAbove;

  /// Dialog title for floor construction editor
  ///
  /// In en, this message translates to:
  /// **'Floor construction'**
  String get floorConstruction;

  /// Dialog title for ceiling construction editor
  ///
  /// In en, this message translates to:
  /// **'Roof / ceiling construction'**
  String get roofCeilingConstruction;

  /// Label when no construction is assigned
  ///
  /// In en, this message translates to:
  /// **'Not assigned'**
  String get notAssigned;

  /// Button label to assign a construction
  ///
  /// In en, this message translates to:
  /// **'+ Assign'**
  String get assignAction;

  /// Generic edit button label
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editAction;

  /// Label for adjacent room temperature field
  ///
  /// In en, this message translates to:
  /// **'Adjacent room temp.'**
  String get adjacentRoomTemp;

  /// Short label for unheated space temp field
  ///
  /// In en, this message translates to:
  /// **'Unheated space temp.'**
  String get unheatedSpaceTempShort;

  /// Hint text showing default value
  ///
  /// In en, this message translates to:
  /// **'{value} (default)'**
  String defaultHint(String value);

  /// Tooltip for reset-to-default button
  ///
  /// In en, this message translates to:
  /// **'Reset to project default'**
  String get resetToProjectDefault;

  /// Floor boundary option: ground
  ///
  /// In en, this message translates to:
  /// **'Ground (slab on grade)'**
  String get boundaryGround;

  /// Floor boundary option: unheated space below
  ///
  /// In en, this message translates to:
  /// **'Unheated space (basement / garage / crawlspace)'**
  String get boundaryUnheatedBelow;

  /// Floor boundary option: heated room below
  ///
  /// In en, this message translates to:
  /// **'Adjacent heated room (floor above another room)'**
  String get boundaryAdjacentBelow;

  /// Ceiling boundary option: exterior
  ///
  /// In en, this message translates to:
  /// **'Exterior / Roof'**
  String get boundaryExteriorRoof;

  /// Ceiling boundary option: unheated space above
  ///
  /// In en, this message translates to:
  /// **'Unheated space (attic / garage / crawlspace)'**
  String get boundaryUnheatedAbove;

  /// Ceiling boundary option: heated room above
  ///
  /// In en, this message translates to:
  /// **'Adjacent heated room (ceiling below another room)'**
  String get boundaryAdjacentAbove;

  /// Air change rate preset label
  ///
  /// In en, this message translates to:
  /// **'Standard room'**
  String get acrStandardRoom;

  /// Air change rate preset label
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get acrKitchen;

  /// Air change rate preset label
  ///
  /// In en, this message translates to:
  /// **'Bathroom'**
  String get acrBathroom;

  /// Air change rate preset label
  ///
  /// In en, this message translates to:
  /// **'Utility room'**
  String get acrUtilityRoom;

  /// Air change rate preset label
  ///
  /// In en, this message translates to:
  /// **'Server room'**
  String get acrServerRoom;

  /// Header for circuit overview panel
  ///
  /// In en, this message translates to:
  /// **'Circuits ({count})'**
  String circuitsWithCount(int count);

  /// Column header for pressure difference
  ///
  /// In en, this message translates to:
  /// **'Δp (kPa)'**
  String get circuitDeltaPKpa;

  /// Empty state heading for circuit panel
  ///
  /// In en, this message translates to:
  /// **'No circuits'**
  String get noCircuits;

  /// Empty state description for circuit panel
  ///
  /// In en, this message translates to:
  /// **'Add a distributor and draw heating zones to see circuit data here.'**
  String get noCircuitsHint;

  /// Section heading in wall properties
  ///
  /// In en, this message translates to:
  /// **'Wall Segment'**
  String get wallSegment;

  /// Label for length dimension
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get lengthLabel;

  /// Label for wall orientation
  ///
  /// In en, this message translates to:
  /// **'Orientation'**
  String get orientationLabel;

  /// Label for wall construction
  ///
  /// In en, this message translates to:
  /// **'Construction'**
  String get constructionLabel;

  /// Button to add wall construction
  ///
  /// In en, this message translates to:
  /// **'Add Construction'**
  String get addConstruction;

  /// Button to edit wall construction
  ///
  /// In en, this message translates to:
  /// **'Edit Construction'**
  String get editConstruction;

  /// Label for wall zone surface material
  ///
  /// In en, this message translates to:
  /// **'Surface Material'**
  String get surfaceMaterial;

  /// Label for floor zone material
  ///
  /// In en, this message translates to:
  /// **'Flooring Material'**
  String get flooringMaterial;

  /// Dropdown option for custom value
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get customEllipsis;

  /// Read-only label for zone area
  ///
  /// In en, this message translates to:
  /// **'Zone Area'**
  String get zoneArea;

  /// Read-only label for tube length
  ///
  /// In en, this message translates to:
  /// **'Tube Length'**
  String get tubeLengthLabel;

  /// Read-only label for specific heat output
  ///
  /// In en, this message translates to:
  /// **'Specific Output'**
  String get specificOutput;

  /// Read-only label for total heat output
  ///
  /// In en, this message translates to:
  /// **'Total Output'**
  String get totalOutput;

  /// Error when tube types fail to load
  ///
  /// In en, this message translates to:
  /// **'Error loading tube types'**
  String get errorLoadingTubeTypes;

  /// Error when flooring materials fail to load
  ///
  /// In en, this message translates to:
  /// **'Error loading flooring materials'**
  String get errorLoadingFlooringMaterials;

  /// Heading in properties panel when nothing is selected
  ///
  /// In en, this message translates to:
  /// **'Project Summary'**
  String get projectSummary;

  /// Label for room count
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get rooms;

  /// Label for wall count
  ///
  /// In en, this message translates to:
  /// **'Walls'**
  String get walls;

  /// Label for total floor area
  ///
  /// In en, this message translates to:
  /// **'Total Area'**
  String get totalArea;

  /// Hint text when no element is selected
  ///
  /// In en, this message translates to:
  /// **'Select an element on the canvas to see its properties.'**
  String get selectElementHint;

  /// Error when selected wall no longer exists
  ///
  /// In en, this message translates to:
  /// **'Wall not found'**
  String get wallNotFound;

  /// Label for wall type
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeWallLabel;

  /// Read-only label for zone surface temperature
  ///
  /// In en, this message translates to:
  /// **'Surface Temperature'**
  String get surfaceTemperature;

  /// Material picker category header — masonry materials
  ///
  /// In en, this message translates to:
  /// **'Masonry'**
  String get materialCategory_masonry;

  /// Material picker category header — concrete and screed
  ///
  /// In en, this message translates to:
  /// **'Concrete & Screed'**
  String get materialCategory_concreteScreed;

  /// Material picker category header — insulation boards
  ///
  /// In en, this message translates to:
  /// **'Insulation boards'**
  String get materialCategory_insulationBoards;

  /// Material picker category header — loose-fill / blow-in insulation
  ///
  /// In en, this message translates to:
  /// **'Loose fill / Blow-in'**
  String get materialCategory_looseFillBlowIn;

  /// Material picker category header — wood
  ///
  /// In en, this message translates to:
  /// **'Wood'**
  String get materialCategory_wood;

  /// Material picker category header — plaster and mortar
  ///
  /// In en, this message translates to:
  /// **'Plaster & Mortar'**
  String get materialCategory_plasterMortar;

  /// Material picker category header — board materials (gypsum board, etc.)
  ///
  /// In en, this message translates to:
  /// **'Board materials'**
  String get materialCategory_boardMaterials;

  /// Material picker category header — floor coverings
  ///
  /// In en, this message translates to:
  /// **'Floor covering'**
  String get materialCategory_floorCovering;

  /// Material picker category header — glass
  ///
  /// In en, this message translates to:
  /// **'Glass'**
  String get materialCategory_glass;

  /// Material picker subcategory — historic brick (AMz / DIN 4108 era)
  ///
  /// In en, this message translates to:
  /// **'Historic brick'**
  String get materialSubcategory_historicBrick;

  /// Material picker subcategory — modern thermal brick (Poroton, Unipor, …)
  ///
  /// In en, this message translates to:
  /// **'Modern thermal brick'**
  String get materialSubcategory_modernThermalBrick;

  /// Material picker subcategory — calcium silicate (Kalksandstein) masonry
  ///
  /// In en, this message translates to:
  /// **'Calcium silicate'**
  String get materialSubcategory_calciumSilicate;

  /// Material picker subcategory — autoclaved aerated concrete (Porenbeton)
  ///
  /// In en, this message translates to:
  /// **'AAC / Aerated concrete'**
  String get materialSubcategory_aacAeratedConcrete;

  /// Material picker subcategory — normal concrete
  ///
  /// In en, this message translates to:
  /// **'Normal concrete'**
  String get materialSubcategory_normalConcrete;

  /// Material picker subcategory — lightweight concrete
  ///
  /// In en, this message translates to:
  /// **'Lightweight concrete'**
  String get materialSubcategory_lightweightConcrete;

  /// Material picker subcategory — screed
  ///
  /// In en, this message translates to:
  /// **'Screed'**
  String get materialSubcategory_screed;

  /// Material picker subcategory — EPS rigid foam
  ///
  /// In en, this message translates to:
  /// **'Rigid foam, EPS'**
  String get materialSubcategory_rigidFoamEps;

  /// Material picker subcategory — XPS rigid foam
  ///
  /// In en, this message translates to:
  /// **'Rigid foam, XPS'**
  String get materialSubcategory_rigidFoamXps;

  /// Material picker subcategory — PUR/PIR rigid foam
  ///
  /// In en, this message translates to:
  /// **'Rigid foam, PUR/PIR'**
  String get materialSubcategory_rigidFoamPurPir;

  /// Material picker subcategory — phenolic rigid foam
  ///
  /// In en, this message translates to:
  /// **'Rigid foam, phenolic'**
  String get materialSubcategory_rigidFoamPhenolic;

  /// Material picker subcategory — stone wool insulation board
  ///
  /// In en, this message translates to:
  /// **'Stone wool board'**
  String get materialSubcategory_stoneWoolBoard;

  /// Material picker subcategory — glass wool board or roll
  ///
  /// In en, this message translates to:
  /// **'Glass wool board/roll'**
  String get materialSubcategory_glassWoolBoardRoll;

  /// Material picker subcategory — wood-fibre insulation
  ///
  /// In en, this message translates to:
  /// **'Wood fibre'**
  String get materialSubcategory_woodFibre;

  /// Material picker subcategory — calcium silicate insulation board
  ///
  /// In en, this message translates to:
  /// **'Calcium silicate board'**
  String get materialSubcategory_calciumSilicateBoard;

  /// Material picker subcategory — cellular glass (Foamglas)
  ///
  /// In en, this message translates to:
  /// **'Cellular glass'**
  String get materialSubcategory_cellularGlass;

  /// Material picker subcategory — cork insulation
  ///
  /// In en, this message translates to:
  /// **'Cork'**
  String get materialSubcategory_cork;

  /// Material picker subcategory — vacuum insulation panels (VIP)
  ///
  /// In en, this message translates to:
  /// **'Vacuum insulation'**
  String get materialSubcategory_vacuumInsulation;

  /// Material picker subcategory — cellulose loose-fill / blow-in
  ///
  /// In en, this message translates to:
  /// **'Cellulose'**
  String get materialSubcategory_cellulose;

  /// Material picker subcategory — mineral wool blow-in
  ///
  /// In en, this message translates to:
  /// **'Mineral wool blow-in'**
  String get materialSubcategory_mineralWoolBlowIn;

  /// Material picker subcategory — perlite loose-fill
  ///
  /// In en, this message translates to:
  /// **'Perlite'**
  String get materialSubcategory_perlite;

  /// Material picker subcategory — vermiculite loose-fill
  ///
  /// In en, this message translates to:
  /// **'Vermiculite'**
  String get materialSubcategory_vermiculite;

  /// Material picker subcategory — natural-fibre loose-fill (hemp, sheep's wool, straw)
  ///
  /// In en, this message translates to:
  /// **'Natural fibre'**
  String get materialSubcategory_naturalFibre;

  /// Material picker subcategory — structural timber (Bauholz)
  ///
  /// In en, this message translates to:
  /// **'Structural timber'**
  String get materialSubcategory_structuralTimber;

  /// Material picker subcategory — engineered wood (plywood, OSB, MDF, CLT)
  ///
  /// In en, this message translates to:
  /// **'Engineered wood'**
  String get materialSubcategory_engineeredWood;

  /// Material picker subcategory — cement and lime plasters/mortars
  ///
  /// In en, this message translates to:
  /// **'Cement/Lime'**
  String get materialSubcategory_cementLime;

  /// Material picker subcategory — clay plaster
  ///
  /// In en, this message translates to:
  /// **'Clay'**
  String get materialSubcategory_clay;

  /// Material picker subcategory — gypsum plaster
  ///
  /// In en, this message translates to:
  /// **'Gypsum'**
  String get materialSubcategory_gypsum;

  /// Material picker subcategory — insulating render / thermal-insulation plaster
  ///
  /// In en, this message translates to:
  /// **'Insulation plaster'**
  String get materialSubcategory_insulationPlaster;

  /// Material picker subcategory — gypsum plasterboard
  ///
  /// In en, this message translates to:
  /// **'Gypsum board'**
  String get materialSubcategory_gypsumBoard;

  /// Material picker subcategory — tile and natural stone floor coverings
  ///
  /// In en, this message translates to:
  /// **'Tile / Natural stone'**
  String get materialSubcategory_tileNaturalStone;

  /// Material picker subcategory — wood, laminate, and vinyl floor coverings
  ///
  /// In en, this message translates to:
  /// **'Wood / Laminate / Vinyl'**
  String get materialSubcategory_woodLaminateVinyl;

  /// Performance dashboard tab — heat-balance view
  ///
  /// In en, this message translates to:
  /// **'Heat Balance'**
  String get perfDashboard_tabHeatBalance;

  /// Performance dashboard tab — hydraulic view
  ///
  /// In en, this message translates to:
  /// **'Hydraulic'**
  String get perfDashboard_tabHydraulic;

  /// Performance dashboard tab — warnings/validation view
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get perfDashboard_tabWarnings;

  /// Header on the Warnings tab showing the number of issues
  ///
  /// In en, this message translates to:
  /// **'Warnings ({count})'**
  String perfDashboard_warningsHeader(int count);

  /// Severity filter — show only errors
  ///
  /// In en, this message translates to:
  /// **'Errors only'**
  String get perfDashboard_filterErrorsOnly;

  /// Severity filter — show only warnings
  ///
  /// In en, this message translates to:
  /// **'Warnings only'**
  String get perfDashboard_filterWarningsOnly;

  /// Severity filter — show only info-level entries
  ///
  /// In en, this message translates to:
  /// **'Info only'**
  String get perfDashboard_filterInfoOnly;

  /// Empty state on the Warnings tab when validation found nothing
  ///
  /// In en, this message translates to:
  /// **'No issues found'**
  String get perfDashboard_noIssuesFound;

  /// Empty state on the Heat Balance tab before any rooms exist
  ///
  /// In en, this message translates to:
  /// **'Draw rooms to see the heat balance.'**
  String get perfDashboard_emptyHeatBalance;

  /// Heat-balance legend — total heating demand (W)
  ///
  /// In en, this message translates to:
  /// **'Demand'**
  String get perfDashboard_legendDemand;

  /// Heat-balance legend — total heating output (W)
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get perfDashboard_legendOutput;

  /// Heat-balance legend — output minus demand (W)
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get perfDashboard_legendBalance;

  /// Hydraulic legend — pressure loss in the pipe run
  ///
  /// In en, this message translates to:
  /// **'Pipe loss'**
  String get perfDashboard_legendPipeLoss;

  /// Hydraulic legend — pressure drop across the balancing valve
  ///
  /// In en, this message translates to:
  /// **'Valve throttling'**
  String get perfDashboard_legendValveThrottling;

  /// Severity badge label — error
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get severity_error;

  /// Severity badge label — warning
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get severity_warning;

  /// Severity badge label — info
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get severity_info;

  /// Zone prerequisite missing — no heating circuit linked to this zone
  ///
  /// In en, this message translates to:
  /// **'No circuit connected'**
  String get zoneMissing_noCircuitConnected;

  /// Zone prerequisite missing — no distributor placed on this floor
  ///
  /// In en, this message translates to:
  /// **'No distributor placed'**
  String get zoneMissing_noDistributorPlaced;

  /// Zone prerequisite missing — no tube type chosen
  ///
  /// In en, this message translates to:
  /// **'No tube type selected'**
  String get zoneMissing_noTubeTypeSelected;

  /// Zone prerequisite missing — no flooring material chosen
  ///
  /// In en, this message translates to:
  /// **'No flooring material selected'**
  String get zoneMissing_noFlooringMaterialSelected;

  /// Tube-type dropdown empty-state label
  ///
  /// In en, this message translates to:
  /// **'No tube types available'**
  String get zoneMissing_noTubeTypesAvailable;

  /// Room prerequisite missing — no exterior walls available for heat-demand calculation
  ///
  /// In en, this message translates to:
  /// **'No exterior walls defined'**
  String get roomMissing_noExteriorWallsDefined;

  /// Supply-pipe insulation option subtitle — uninsulated pipe emits 100% to the transit room
  ///
  /// In en, this message translates to:
  /// **'Full heat output to transit room'**
  String get circuit_fullHeatOutputToTransitRoom;

  /// Supply-pipe insulation option subtitle — pipe routed inside insulation layer emits 0% to the transit room
  ///
  /// In en, this message translates to:
  /// **'No heat output to transit room'**
  String get circuit_noHeatOutputToTransitRoom;

  /// Undo/redo label — committing edits to a window
  ///
  /// In en, this message translates to:
  /// **'Update window'**
  String get opening_updateWindow;

  /// Undo/redo label — committing edits to a door
  ///
  /// In en, this message translates to:
  /// **'Update door'**
  String get opening_updateDoor;

  /// Undo/redo label — rotating the distributor in place
  ///
  /// In en, this message translates to:
  /// **'Rotate distributor'**
  String get undo_rotateDistributor;

  /// Undo/redo label — deleting a wall segment
  ///
  /// In en, this message translates to:
  /// **'Delete wall'**
  String get undo_deleteWall;

  /// Undo/redo label — deleting a room and its boundary walls
  ///
  /// In en, this message translates to:
  /// **'Delete room'**
  String get undo_deleteRoom;

  /// Undo/redo label — deleting a window opening
  ///
  /// In en, this message translates to:
  /// **'Delete window'**
  String get undo_deleteWindow;

  /// Undo/redo label — deleting a door opening
  ///
  /// In en, this message translates to:
  /// **'Delete door'**
  String get undo_deleteDoor;

  /// Undo/redo label — deleting a heating circuit
  ///
  /// In en, this message translates to:
  /// **'Delete circuit'**
  String get undo_deleteCircuit;

  /// Undo/redo label — deleting a heating zone
  ///
  /// In en, this message translates to:
  /// **'Delete zone'**
  String get undo_deleteZone;

  /// Undo/redo label — deleting the distributor
  ///
  /// In en, this message translates to:
  /// **'Delete distributor'**
  String get undo_deleteDistributor;

  /// Undo/redo label — creating a floor heating zone (polygon, rectangle, or fill-room)
  ///
  /// In en, this message translates to:
  /// **'Create zone'**
  String get undo_createZone;

  /// Undo/redo label — creating a wall heating zone
  ///
  /// In en, this message translates to:
  /// **'Create wall zone'**
  String get undo_createWallZone;

  /// Default name for a newly detected room before the user renames it
  ///
  /// In en, this message translates to:
  /// **'Room {roomNumber}'**
  String canvas_defaultRoomName(int roomNumber);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
