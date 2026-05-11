// Maps the canonical English category / subcategory values stored in
// `material_entries.category` and `material_entries.subcategory` to
// their locale-appropriate display strings via [AppLocalizations].
//
// The DB columns stay canonical English so import/export, search, and
// the `_categoryOrder` constant in grouped_materials_provider keep
// working unchanged — translation happens only at render time.
//
// Custom categories created by the user fall outside the catalog and
// are returned unchanged, matching the "Unknown/custom categories are
// appended" semantics already documented in [_categoryOrder].

import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// Returns the locale-resolved display string for [canonical], the
/// canonical English category value stored in
/// `material_entries.category`. Falls back to [canonical] for any
/// user-created or unrecognised value.
String localizeMaterialCategory(BuildContext context, String canonical) {
  final l10n = AppLocalizations.of(context)!;
  switch (canonical) {
    case 'Masonry':
      return l10n.materialCategory_masonry;
    case 'Concrete & Screed':
      return l10n.materialCategory_concreteScreed;
    case 'Insulation boards':
      return l10n.materialCategory_insulationBoards;
    case 'Loose fill / Blow-in':
      return l10n.materialCategory_looseFillBlowIn;
    case 'Wood':
      return l10n.materialCategory_wood;
    case 'Plaster & Mortar':
      return l10n.materialCategory_plasterMortar;
    case 'Board materials':
      return l10n.materialCategory_boardMaterials;
    case 'Floor covering':
      return l10n.materialCategory_floorCovering;
    case 'Glass':
      return l10n.materialCategory_glass;
    default:
      return canonical;
  }
}

/// Returns the locale-resolved display string for [canonical], the
/// canonical English subcategory value stored in
/// `material_entries.subcategory`. Falls back to [canonical] for any
/// user-created or unrecognised value.
String localizeMaterialSubcategory(
  BuildContext context,
  String canonical,
) {
  final l10n = AppLocalizations.of(context)!;
  switch (canonical) {
    // Masonry
    case 'Historic brick':
      return l10n.materialSubcategory_historicBrick;
    case 'Modern thermal brick':
      return l10n.materialSubcategory_modernThermalBrick;
    case 'Calcium silicate':
      return l10n.materialSubcategory_calciumSilicate;
    case 'AAC / Aerated concrete':
      return l10n.materialSubcategory_aacAeratedConcrete;
    // Concrete & Screed
    case 'Normal concrete':
      return l10n.materialSubcategory_normalConcrete;
    case 'Lightweight concrete':
      return l10n.materialSubcategory_lightweightConcrete;
    case 'Screed':
      return l10n.materialSubcategory_screed;
    // Insulation boards
    case 'Rigid foam, EPS':
      return l10n.materialSubcategory_rigidFoamEps;
    case 'Rigid foam, XPS':
      return l10n.materialSubcategory_rigidFoamXps;
    case 'Rigid foam, PUR/PIR':
      return l10n.materialSubcategory_rigidFoamPurPir;
    case 'Rigid foam, phenolic':
      return l10n.materialSubcategory_rigidFoamPhenolic;
    case 'Stone wool board':
      return l10n.materialSubcategory_stoneWoolBoard;
    case 'Glass wool board/roll':
      return l10n.materialSubcategory_glassWoolBoardRoll;
    case 'Wood fibre':
      return l10n.materialSubcategory_woodFibre;
    case 'Calcium silicate board':
      return l10n.materialSubcategory_calciumSilicateBoard;
    case 'Cellular glass':
      return l10n.materialSubcategory_cellularGlass;
    case 'Cork':
      return l10n.materialSubcategory_cork;
    case 'Vacuum insulation':
      return l10n.materialSubcategory_vacuumInsulation;
    // Loose fill / Blow-in
    case 'Cellulose':
      return l10n.materialSubcategory_cellulose;
    case 'Mineral wool blow-in':
      return l10n.materialSubcategory_mineralWoolBlowIn;
    case 'Perlite':
      return l10n.materialSubcategory_perlite;
    case 'Vermiculite':
      return l10n.materialSubcategory_vermiculite;
    case 'Natural fibre':
      return l10n.materialSubcategory_naturalFibre;
    // Wood
    case 'Structural timber':
      return l10n.materialSubcategory_structuralTimber;
    case 'Engineered wood':
      return l10n.materialSubcategory_engineeredWood;
    // Plaster & Mortar
    case 'Cement/Lime':
      return l10n.materialSubcategory_cementLime;
    case 'Clay':
      return l10n.materialSubcategory_clay;
    case 'Gypsum':
      return l10n.materialSubcategory_gypsum;
    case 'Insulation plaster':
      return l10n.materialSubcategory_insulationPlaster;
    // Board materials
    case 'Gypsum board':
      return l10n.materialSubcategory_gypsumBoard;
    // Floor covering
    case 'Tile / Natural stone':
      return l10n.materialSubcategory_tileNaturalStone;
    case 'Wood / Laminate / Vinyl':
      return l10n.materialSubcategory_woodLaminateVinyl;
    default:
      return canonical;
  }
}
