import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';

const double kDefaultMenuMusicVolume = 0.25;
const double _kSfxVolume = 0.8;

/// Music + sound-effect + vibration playback, all driven by user settings
/// (persisted on-device). Two dedicated players are used on purpose: one
/// looping player for the menu music (which needs to keep playing across
/// screen rebuilds), and one short-lived player for one-shot effects
/// (click/correct/error), so a rapid tap never gets cut off by the music
/// or vice versa.
class AudioService extends ChangeNotifier {
  static const _kMusicEnabled = 'audio_menu_music_enabled';
  static const _kMusicVolume = 'audio_menu_music_volume';

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  bool menuMusicEnabled = true;
  double menuMusicVolume = kDefaultMenuMusicVolume;

  // True once the loop has been started and not explicitly stopped since --
  // lets ensureMenuMusicPlaying() be called freely from every menu screen
  // without audibly restarting the track every time you just navigate
  // between menu screens (Home <-> Settings, say).
  bool _musicActive = false;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      menuMusicEnabled = prefs.getBool(_kMusicEnabled) ?? true;
      menuMusicVolume = prefs.getDouble(_kMusicVolume) ?? kDefaultMenuMusicVolume;
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      debugPrint('AudioService.load failed, using defaults: $e');
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kMusicEnabled, menuMusicEnabled);
      await prefs.setDouble(_kMusicVolume, menuMusicVolume);
    } catch (e) {
      debugPrint('AudioService.persist failed: $e');
    }
  }

  /// Call when a menu-context screen becomes visible (its own initState
  /// for screens that are always freshly built, or RouteAware.didPopNext
  /// for screens the user can navigate back to -- see route_observer.dart).
  /// Safe to call repeatedly: a no-op whenever the loop is already going,
  /// which is what keeps navigating between menu screens seamless.
  Future<void> ensureMenuMusicPlaying() async {
    if (!menuMusicEnabled || _musicActive) return;
    _musicActive = true;
    try {
      await _bgmPlayer.setVolume(menuMusicVolume);
      await _bgmPlayer.play(AssetSource('audio/mainmenu.m4a'));
    } catch (e) {
      debugPrint('ensureMenuMusicPlaying failed: $e');
    }
  }

  /// Call from every lesson/test/review/flashcard screen's initState --
  /// silences the loop during actual practice. The next menu screen that
  /// calls ensureMenuMusicPlaying() will start the track over from the
  /// beginning (play(), unlike resume(), always starts at position 0).
  Future<void> stopMenuMusic() async {
    _musicActive = false;
    try {
      await _bgmPlayer.stop();
    } catch (e) {
      debugPrint('stopMenuMusic failed: $e');
    }
  }

  Future<void> setMenuMusicEnabled(bool enabled) async {
    menuMusicEnabled = enabled;
    if (enabled) {
      _musicActive = false; // force a fresh start even if flagged active
      await ensureMenuMusicPlaying();
    } else {
      await stopMenuMusic();
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setMenuMusicVolume(double value) async {
    menuMusicVolume = value.clamp(0.0, 1.0).toDouble();
    try {
      await _bgmPlayer.setVolume(menuMusicVolume);
    } catch (e) {
      debugPrint('setMenuMusicVolume failed: $e');
    }
    await _persist();
    notifyListeners();
  }

  /// A tap anywhere in a menu/settings screen.
  Future<void> playMenuClick() => _playSfx('audio/setting_sound.mp3');

  /// A tap anywhere in a lesson/test/review screen that isn't a wrong
  /// answer (includes correct answers, Next/Skip, flashcard flips, and
  /// self-rating buttons).
  Future<void> playLessonClick() => _playSfx('audio/correct_click.mp3');

  /// A wrong answer: sound + a short vibration.
  Future<void> playError() async {
    HapticFeedback.vibrate();
    await _playSfx('audio/error.mp3');
  }

  Future<void> _playSfx(String assetPath) async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setVolume(_kSfxVolume);
      await _sfxPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('playSfx($assetPath) failed: $e');
    }
  }

  @override
  void dispose() {
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
    super.dispose();
  }
}
