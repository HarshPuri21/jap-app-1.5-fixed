import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

/// What kind of background is currently active. 'default' is the app's
/// built-in dark gradient; 'color' is a flat accent color; 'photo' is a
/// user-picked image (like a WhatsApp chat wallpaper), dimmed by
/// [overlayOpacity] so text stays readable on top of it.
enum BackgroundType { appDefault, color, photo }

const List<Color> kBackgroundColorPresets = [
  Color(0xFF0F172A), // slate (default accent)
  Color(0xFF14532D), // deep green
  Color(0xFF4C1D95), // deep violet
  Color(0xFF7C2D12), // deep rust
  Color(0xFF164E63), // deep teal
  Color(0xFF1E1B4B), // indigo night
];

class SettingsService extends ChangeNotifier {
  static const _kBgType = 'bg_type';
  static const _kBgColorIndex = 'bg_color_index';
  static const _kBgPhotoPath = 'bg_photo_path';
  static const _kOverlayOpacity = 'bg_overlay_opacity';
  static const _kCorrectTotal = 'stats_correct_total';
  static const _kAnsweredTotal = 'stats_answered_total';

  BackgroundType backgroundType = BackgroundType.appDefault;
  int backgroundColorIndex = 0;
  Color get backgroundColor => kBackgroundColorPresets[
      backgroundColorIndex.clamp(0, kBackgroundColorPresets.length - 1).toInt()];
  String? backgroundPhotoPath;
  double overlayOpacity = 0.55;

  int statsCorrectTotal = 0;
  int statsAnsweredTotal = 0;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final typeIndex = prefs.getInt(_kBgType) ?? 0;
      backgroundType = BackgroundType.values[typeIndex.clamp(
        0,
        BackgroundType.values.length - 1,
      ).toInt()];
      backgroundColorIndex = prefs.getInt(_kBgColorIndex) ?? 0;
      backgroundPhotoPath = prefs.getString(_kBgPhotoPath);
      overlayOpacity = prefs.getDouble(_kOverlayOpacity) ?? 0.55;
      statsCorrectTotal = prefs.getInt(_kCorrectTotal) ?? 0;
      statsAnsweredTotal = prefs.getInt(_kAnsweredTotal) ?? 0;

      // If a previously-picked photo was somehow removed from disk, fall
      // back to the default rather than showing a broken image.
      if (backgroundType == BackgroundType.photo &&
          (backgroundPhotoPath == null ||
              !File(backgroundPhotoPath!).existsSync())) {
        backgroundType = BackgroundType.appDefault;
      }
    } catch (e) {
      // Corrupted/unreadable prefs shouldn't block the app from starting --
      // worst case you see default settings instead of your saved ones.
      debugPrint('SettingsService.load failed, using defaults: $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kBgType, backgroundType.index);
      await prefs.setInt(_kBgColorIndex, backgroundColorIndex);
      if (backgroundPhotoPath != null) {
        await prefs.setString(_kBgPhotoPath, backgroundPhotoPath!);
      }
      await prefs.setDouble(_kOverlayOpacity, overlayOpacity);
    } catch (e) {
      debugPrint('SettingsService.save failed (kept in memory only): $e');
    }
  }

  Future<void> setBackgroundColorIndex(int index) async {
    backgroundType = BackgroundType.color;
    backgroundColorIndex = index;
    await _save();
    notifyListeners();
  }

  Future<void> setBackgroundDefault() async {
    backgroundType = BackgroundType.appDefault;
    await _save();
    notifyListeners();
  }

  /// Opens the system photo picker, copies the chosen image into the app's
  /// own documents directory (so it keeps working even if the original is
  /// deleted from the gallery), and sets it as the background.
  Future<bool> pickBackgroundPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return false;

      final docsDir = await getApplicationDocumentsDirectory();
      final ext = picked.path.split('.').last;
      final destPath = '${docsDir.path}/background_wallpaper.$ext';
      await File(picked.path).copy(destPath);

      backgroundType = BackgroundType.photo;
      backgroundPhotoPath = destPath;
      await _save();
      notifyListeners();
      return true;
    } catch (e) {
      // Permission denied, disk full, picker cancelled oddly, etc. -- the
      // background just stays whatever it was before, no crash.
      debugPrint('pickBackgroundPhoto failed: $e');
      return false;
    }
  }

  Future<void> setOverlayOpacity(double value) async {
    overlayOpacity = value.clamp(0.0, 0.9).toDouble();
    await _save();
    notifyListeners();
  }

  Future<void> recordAnswer({required bool correct}) async {
    statsAnsweredTotal += 1;
    if (correct) statsCorrectTotal += 1;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kCorrectTotal, statsCorrectTotal);
      await prefs.setInt(_kAnsweredTotal, statsAnsweredTotal);
    } catch (e) {
      debugPrint('recordAnswer save failed (kept in memory only): $e');
    }
  }
}
