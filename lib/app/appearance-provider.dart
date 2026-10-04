import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/design/tokens/app-colors.dart';

class AppearanceProvider extends ChangeNotifier {
  static const _preferenceKey = 'app_palette';

  NashaatPaletteId _paletteId = NashaatPaletteId.majlisNight;

  AppearanceProvider() {
    _loadSavedPalette();
  }

  NashaatPaletteId get paletteId => _paletteId;
  NashaatPalette get palette => NashaatPalette.forId(_paletteId);

  Future<void> _loadSavedPalette() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_preferenceKey);
    final savedId = NashaatPalette.idFromStorage(saved);
    if (savedId == _paletteId) return;

    _paletteId = savedId;
    notifyListeners();
  }

  Future<void> setPalette(NashaatPaletteId paletteId) async {
    if (_paletteId == paletteId) return;

    _paletteId = paletteId;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _preferenceKey,
      NashaatPalette.forId(paletteId).storageKey,
    );
  }
}
