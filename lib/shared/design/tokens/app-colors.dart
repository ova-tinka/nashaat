import 'package:flutter/material.dart';

/// The four visual identities used by Nashaat.
///
/// This is also a [ThemeExtension], so shared components can resolve the
/// active palette from [Theme.of] without importing a global singleton.
enum NashaatPaletteId { majlisNight, pearlDay, adaamNight, nakheelDay }

@immutable
class NashaatPalette extends ThemeExtension<NashaatPalette> {
  final NashaatPaletteId id;
  final String label;
  final Brightness brightness;

  final Color background;
  final Color card;
  final Color raised;
  final Color well;
  final Color border;
  final Color cardEdge;

  final Color textPrimary;
  final Color textSecondary;
  final Color textBody;
  final Color textMuted;

  final Color accent;
  final Color accentInk;
  final Color accentText;
  final Color reward;
  final Color rewardInk;
  final Color rewardText;
  final Color calm;
  final Color calmInk;
  final Color calmText;
  final Color locked;
  final Color lockedText;
  final Color danger;
  final Color dangerInk;
  final Color dangerText;

  final Color saduRed;
  final Color saduYellow;
  final Color saduLight;
  final Color saduDark;
  final Color saduBrown;
  final Color selection;
  final Color scrim;

  const NashaatPalette({
    required this.id,
    required this.label,
    required this.brightness,
    required this.background,
    required this.card,
    required this.raised,
    required this.well,
    required this.border,
    required this.cardEdge,
    required this.textPrimary,
    required this.textSecondary,
    required this.textBody,
    required this.textMuted,
    required this.accent,
    required this.accentInk,
    required this.accentText,
    required this.reward,
    required this.rewardInk,
    required this.rewardText,
    required this.calm,
    required this.calmInk,
    required this.calmText,
    required this.locked,
    required this.lockedText,
    required this.danger,
    required this.dangerInk,
    required this.dangerText,
    required this.saduRed,
    required this.saduYellow,
    required this.saduLight,
    required this.saduDark,
    required this.saduBrown,
    required this.selection,
    required this.scrim,
  });

  static const majlisNight = NashaatPalette(
    id: NashaatPaletteId.majlisNight,
    label: 'Majlis Night',
    brightness: Brightness.dark,
    background: Color(0xFF15110E),
    card: Color(0xFF211B16),
    raised: Color(0xFF2C241D),
    well: Color(0xFF1B1511),
    border: Color(0xFF3A3027),
    cardEdge: Color(0xFF2E241C),
    textPrimary: Color(0xFFF5EDE0),
    textSecondary: Color(0xFFD6CBBB),
    textBody: Color(0xFFBDB1A1),
    textMuted: Color(0xFFA7998A),
    accent: Color(0xFF2BC4B0),
    accentInk: Color(0xFF07201C),
    accentText: Color(0xFF2BC4B0),
    reward: Color(0xFFF0A93A),
    rewardInk: Color(0xFF2A1A04),
    rewardText: Color(0xFFF0A93A),
    calm: Color(0xFFD8B98A),
    calmInk: Color(0xFF241A0E),
    calmText: Color(0xFFD8B98A),
    locked: Color(0xFF7A8BA8),
    lockedText: Color(0xFF95A5C2),
    danger: Color(0xFFB34828),
    dangerInk: Colors.white,
    dangerText: Color(0xFFEE8560),
    saduRed: Color(0xFFB8342C),
    saduYellow: Color(0xFFF0A93A),
    saduLight: Color(0xFFF5EDE0),
    saduDark: Color(0xFF1A1210),
    saduBrown: Color(0xFF8C6A4A),
    selection: Color(0x24D8B98A),
    scrim: Color(0x94000000),
  );

  static const pearlDay = NashaatPalette(
    id: NashaatPaletteId.pearlDay,
    label: 'Pearl Day',
    brightness: Brightness.light,
    background: Color(0xFFF6EFE3),
    card: Color(0xFFFFFCF6),
    raised: Color(0xFFEADFCD),
    well: Color(0xFFEFE6D6),
    border: Color(0xFFD9CCB7),
    cardEdge: Color(0xFFE3D6C2),
    textPrimary: Color(0xFF1D1611),
    textSecondary: Color(0xFF3F342A),
    textBody: Color(0xFF4A3E33),
    textMuted: Color(0xFF6E6052),
    accent: Color(0xFF0B7A6D),
    accentInk: Colors.white,
    accentText: Color(0xFF08695E),
    reward: Color(0xFFC9861F),
    rewardInk: Color(0xFF241503),
    rewardText: Color(0xFF8A5000),
    calm: Color(0xFFC9A46C),
    calmInk: Color(0xFF241A0E),
    calmText: Color(0xFF7A5A2A),
    locked: Color(0xFF4F5F7A),
    lockedText: Color(0xFF4F5F7A),
    danger: Color(0xFFB5452A),
    dangerInk: Colors.white,
    dangerText: Color(0xFFA63D22),
    saduRed: Color(0xFFA8322A),
    saduYellow: Color(0xFFC9861F),
    saduLight: Color(0xFFFFFDF8),
    saduDark: Color(0xFF2A1E16),
    saduBrown: Color(0xFFB89770),
    selection: Color(0x1F7A5A2A),
    scrim: Color(0x6B281C12),
  );

  static const adaamNight = NashaatPalette(
    id: NashaatPaletteId.adaamNight,
    label: 'Adaam Night',
    brightness: Brightness.dark,
    background: Color(0xFF1B0D12),
    card: Color(0xFF2A141C),
    raised: Color(0xFF3A1D28),
    well: Color(0xFF22101A),
    border: Color(0xFF4C2836),
    cardEdge: Colors.transparent,
    textPrimary: Color(0xFFF7EDE6),
    textSecondary: Color(0xFFE6D3CB),
    textBody: Color(0xFFD2BCB3),
    textMuted: Color(0xFFB89F97),
    accent: Color(0xFF3CCBB8),
    accentInk: Color(0xFF06231E),
    accentText: Color(0xFF4FD3C1),
    reward: Color(0xFFF2B24A),
    rewardInk: Color(0xFF2A1A04),
    rewardText: Color(0xFFF5BC5C),
    calm: Color(0xFFE0C49A),
    calmInk: Color(0xFF2A1A10),
    calmText: Color(0xFFE3C9A0),
    locked: Color(0xFF8594B2),
    lockedText: Color(0xFFA9B6D0),
    danger: Color(0xFFB34828),
    dangerInk: Colors.white,
    dangerText: Color(0xFFF48A62),
    saduRed: Color(0xFFC8402F),
    saduYellow: Color(0xFFF2B24A),
    saduLight: Color(0xFFF7EDE6),
    saduDark: Color(0xFF12070A),
    saduBrown: Color(0xFF9A6F58),
    selection: Color(0x24E0C49A),
    scrim: Color(0x99000000),
  );

  static const nakheelDay = NashaatPalette(
    id: NashaatPaletteId.nakheelDay,
    label: 'Nakheel Day',
    brightness: Brightness.light,
    background: Color(0xFFEFE3CC),
    card: Color(0xFFFAF3E6),
    raised: Color(0xFFE3D3B6),
    well: Color(0xFFE9DCC3),
    border: Color(0xFFCDBB98),
    cardEdge: Color(0xFFDCCBAA),
    textPrimary: Color(0xFF221A10),
    textSecondary: Color(0xFF42362A),
    textBody: Color(0xFF4D4032),
    textMuted: Color(0xFF5E4F3D),
    accent: Color(0xFF2C6E52),
    accentInk: Colors.white,
    accentText: Color(0xFF25624A),
    reward: Color(0xFFB97A1C),
    rewardInk: Color(0xFF241503),
    rewardText: Color(0xFF7A4A06),
    calm: Color(0xFFC7A46E),
    calmInk: Color(0xFF241A0E),
    calmText: Color(0xFF6B5028),
    locked: Color(0xFF435674),
    lockedText: Color(0xFF435674),
    danger: Color(0xFFA8412A),
    dangerInk: Colors.white,
    dangerText: Color(0xFF983A22),
    saduRed: Color(0xFFA8412A),
    saduYellow: Color(0xFFB97A1C),
    saduLight: Color(0xFFFBF5EA),
    saduDark: Color(0xFF221A10),
    saduBrown: Color(0xFF9E7E55),
    selection: Color(0x1F6B5028),
    scrim: Color(0x6B281C12),
  );

  static const values = <NashaatPalette>[
    majlisNight,
    pearlDay,
    adaamNight,
    nakheelDay,
  ];

  static NashaatPalette forId(NashaatPaletteId id) => switch (id) {
    NashaatPaletteId.majlisNight => majlisNight,
    NashaatPaletteId.pearlDay => pearlDay,
    NashaatPaletteId.adaamNight => adaamNight,
    NashaatPaletteId.nakheelDay => nakheelDay,
  };

  static NashaatPaletteId idFromStorage(String? value) => switch (value) {
    'pearlDay' => NashaatPaletteId.pearlDay,
    'adaamNight' => NashaatPaletteId.adaamNight,
    'nakheelDay' => NashaatPaletteId.nakheelDay,
    _ => NashaatPaletteId.majlisNight,
  };

  String get storageKey => switch (id) {
    NashaatPaletteId.majlisNight => 'majlisNight',
    NashaatPaletteId.pearlDay => 'pearlDay',
    NashaatPaletteId.adaamNight => 'adaamNight',
    NashaatPaletteId.nakheelDay => 'nakheelDay',
  };

  @override
  NashaatPalette copyWith({
    Color? background,
    Color? card,
    Color? raised,
    Color? well,
    Color? border,
    Color? cardEdge,
    Color? textPrimary,
    Color? textSecondary,
    Color? textBody,
    Color? textMuted,
    Color? accent,
    Color? accentInk,
    Color? accentText,
    Color? reward,
    Color? rewardInk,
    Color? rewardText,
    Color? calm,
    Color? calmInk,
    Color? calmText,
    Color? locked,
    Color? lockedText,
    Color? danger,
    Color? dangerInk,
    Color? dangerText,
    Color? saduRed,
    Color? saduYellow,
    Color? saduLight,
    Color? saduDark,
    Color? saduBrown,
    Color? selection,
    Color? scrim,
  }) {
    return NashaatPalette(
      id: id,
      label: label,
      brightness: brightness,
      background: background ?? this.background,
      card: card ?? this.card,
      raised: raised ?? this.raised,
      well: well ?? this.well,
      border: border ?? this.border,
      cardEdge: cardEdge ?? this.cardEdge,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textBody: textBody ?? this.textBody,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      accentText: accentText ?? this.accentText,
      reward: reward ?? this.reward,
      rewardInk: rewardInk ?? this.rewardInk,
      rewardText: rewardText ?? this.rewardText,
      calm: calm ?? this.calm,
      calmInk: calmInk ?? this.calmInk,
      calmText: calmText ?? this.calmText,
      locked: locked ?? this.locked,
      lockedText: lockedText ?? this.lockedText,
      danger: danger ?? this.danger,
      dangerInk: dangerInk ?? this.dangerInk,
      dangerText: dangerText ?? this.dangerText,
      saduRed: saduRed ?? this.saduRed,
      saduYellow: saduYellow ?? this.saduYellow,
      saduLight: saduLight ?? this.saduLight,
      saduDark: saduDark ?? this.saduDark,
      saduBrown: saduBrown ?? this.saduBrown,
      selection: selection ?? this.selection,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  NashaatPalette lerp(covariant NashaatPalette? other, double t) {
    if (other == null) return this;
    return copyWith(
      background: Color.lerp(background, other.background, t),
      card: Color.lerp(card, other.card, t),
      raised: Color.lerp(raised, other.raised, t),
      well: Color.lerp(well, other.well, t),
      border: Color.lerp(border, other.border, t),
      cardEdge: Color.lerp(cardEdge, other.cardEdge, t),
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t),
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t),
      textBody: Color.lerp(textBody, other.textBody, t),
      textMuted: Color.lerp(textMuted, other.textMuted, t),
      accent: Color.lerp(accent, other.accent, t),
      accentInk: Color.lerp(accentInk, other.accentInk, t),
      accentText: Color.lerp(accentText, other.accentText, t),
      reward: Color.lerp(reward, other.reward, t),
      rewardInk: Color.lerp(rewardInk, other.rewardInk, t),
      rewardText: Color.lerp(rewardText, other.rewardText, t),
      calm: Color.lerp(calm, other.calm, t),
      calmInk: Color.lerp(calmInk, other.calmInk, t),
      calmText: Color.lerp(calmText, other.calmText, t),
      locked: Color.lerp(locked, other.locked, t),
      lockedText: Color.lerp(lockedText, other.lockedText, t),
      danger: Color.lerp(danger, other.danger, t),
      dangerInk: Color.lerp(dangerInk, other.dangerInk, t),
      dangerText: Color.lerp(dangerText, other.dangerText, t),
      saduRed: Color.lerp(saduRed, other.saduRed, t),
      saduYellow: Color.lerp(saduYellow, other.saduYellow, t),
      saduLight: Color.lerp(saduLight, other.saduLight, t),
      saduDark: Color.lerp(saduDark, other.saduDark, t),
      saduBrown: Color.lerp(saduBrown, other.saduBrown, t),
      selection: Color.lerp(selection, other.selection, t),
      scrim: Color.lerp(scrim, other.scrim, t),
    );
  }
}

/// Transitional aliases for screens that have not moved to the palette API.
/// New shared components must resolve [NashaatPalette] from the active theme.
class AppColors {
  static const Color ink = Color(0xFFF5EDE0);
  static const Color inkSoft = Color(0xFFD6CBBB);
  static const Color inkMuted = Color(0xFFA7998A);

  static const Color paper = Color(0xFF15110E);
  static const Color paperAlt = Color(0xFF211B16);
  static const Color paperBorder = Color(0xFF3A3027);

  static const Color acid = Color(0xFF2BC4B0);
  static const Color acidPressed = Color(0xFF2BC4B0);
  static const Color acidMuted = Color(0xFF2C241D);

  static const Color signal = Color(0xFFF0A93A);
  static const Color signalPressed = Color(0xFFF0A93A);
  static const Color signalMuted = Color(0xFF211B16);

  static const Color error = Color(0xFFB34828);
  static const Color errorMuted = Color(0x34B34828);
  static const Color success = Color(0xFF2BC4B0);
}

extension NashaatPaletteContext on BuildContext {
  NashaatPalette get nashaatPalette =>
      Theme.of(this).extension<NashaatPalette>() ?? NashaatPalette.majlisNight;
}
