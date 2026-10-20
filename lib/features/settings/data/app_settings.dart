import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi aplikasi yang disimpan LOKAL di perangkat.
///
/// Padanan `UserSettings` di web (`src/lib/settings.ts`) yang menyimpan ke
/// `localStorage`. Tiga nilai di sini LANGSUNG dipakai saat memanggil
/// `POST /api/chat` (lihat `chat_repository.dart`):
/// - [aiDetailLevel] -> `aiDetailLevel` (brief|medium|detailed),
/// - [aiLanguage]    -> `aiLanguage` (id|en),
/// - [autoSaveHistory] -> `saveHistory`.
///
/// [editorFontSize] juga nyata dipakai di mobile (editor chat + semua blok
/// kode), sedangkan [themeMode] dan [accentColor] hanya DISIMPAN karena mobile
/// memakai tema gelap tetap (lihat `AppColors`) — sama seperti mode gelap yang
/// dipaksa web lewat `SettingsContext` (migrasi versi pengaturan).
///
/// Catatan: server tetap memprioritaskan `user.aiPreference` hasil kuis
/// (lihat `src/app/api/chat/route.ts:110-113`), jadi nilai di sini adalah
/// pilihan user yang belum ikut kuis.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = 'dark',
    this.accentColor = 'crimson',
    this.editorFontSize = 14,
    this.aiDetailLevel = 'medium',
    this.aiLanguage = 'id',
    this.autoSaveHistory = true,
    this.emailCriticalErrors = false,
    this.emailFeatureUpdates = false,
    this.emailWeeklyDigest = true,
  });

  /// `dark` | `light` | `system` (nilai web disimpan apa adanya).
  final String themeMode;

  /// `crimson` | `orange` | `violet` | `cyan` (meniru pilihan aksen web).
  final String accentColor;

  /// Ukuran font editor kode (web: kecil 12 / sedang 14 / besar 16).
  final double editorFontSize;

  /// Tingkat detail jawaban AI: `brief` | `medium` | `detailed`.
  final String aiDetailLevel;

  /// Bahasa jawaban AI: `id` | `en`.
  final String aiLanguage;

  /// Simpan percakapan otomatis ke riwayat.
  final bool autoSaveHistory;

  /// Notifikasi email "Error penting" (default web: mati).
  final bool emailCriticalErrors;

  /// Notifikasi email "Update fitur baru" (default web: mati).
  final bool emailFeatureUpdates;

  /// Notifikasi email "Materi rekomendasi mingguan" (default web: hidup).
  final bool emailWeeklyDigest;

  /// Nilai awal bila belum pernah diubah (sama dengan `DEFAULT_SETTINGS` web).
  static const AppSettings fallback = AppSettings();

  AppSettings copyWith({
    String? themeMode,
    String? accentColor,
    double? editorFontSize,
    String? aiDetailLevel,
    String? aiLanguage,
    bool? autoSaveHistory,
    bool? emailCriticalErrors,
    bool? emailFeatureUpdates,
    bool? emailWeeklyDigest,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    accentColor: accentColor ?? this.accentColor,
    editorFontSize: editorFontSize ?? this.editorFontSize,
    aiDetailLevel: aiDetailLevel ?? this.aiDetailLevel,
    aiLanguage: aiLanguage ?? this.aiLanguage,
    autoSaveHistory: autoSaveHistory ?? this.autoSaveHistory,
    emailCriticalErrors: emailCriticalErrors ?? this.emailCriticalErrors,
    emailFeatureUpdates: emailFeatureUpdates ?? this.emailFeatureUpdates,
    emailWeeklyDigest: emailWeeklyDigest ?? this.emailWeeklyDigest,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.accentColor == accentColor &&
      other.editorFontSize == editorFontSize &&
      other.aiDetailLevel == aiDetailLevel &&
      other.aiLanguage == aiLanguage &&
      other.autoSaveHistory == autoSaveHistory &&
      other.emailCriticalErrors == emailCriticalErrors &&
      other.emailFeatureUpdates == emailFeatureUpdates &&
      other.emailWeeklyDigest == emailWeeklyDigest;

  @override
  int get hashCode => Object.hash(
    themeMode,
    accentColor,
    editorFontSize,
    aiDetailLevel,
    aiLanguage,
    autoSaveHistory,
    emailCriticalErrors,
    emailFeatureUpdates,
    emailWeeklyDigest,
  );
}

/// Pengelola preferensi lokal.
///
/// Pemulihan nilai dilakukan di belakang layar (`shared_preferences` adalah
/// plugin native): bila plugin tidak tersedia (mis. `flutter test`), nilai
/// kembali ke [AppSettings.fallback] tanpa melempar error.
class AppSettingsController extends Notifier<AppSettings> {
  static const String themeModeKey = 'codementor.settings.themeMode';
  static const String accentColorKey = 'codementor.settings.accentColor';
  static const String editorFontSizeKey = 'codementor.settings.editorFontSize';
  static const String aiDetailLevelKey = 'codementor.settings.aiDetailLevel';
  static const String aiLanguageKey = 'codementor.settings.aiLanguage';
  static const String autoSaveHistoryKey =
      'codementor.settings.autoSaveHistory';
  static const String emailCriticalErrorsKey =
      'codementor.settings.emailCriticalErrors';
  static const String emailFeatureUpdatesKey =
      'codementor.settings.emailFeatureUpdates';
  static const String emailWeeklyDigestKey =
      'codementor.settings.emailWeeklyDigest';

  /// Semua kunci yang dipakai — dipakai `resetAll()`.
  static const List<String> allKeys = [
    themeModeKey,
    accentColorKey,
    editorFontSizeKey,
    aiDetailLevelKey,
    aiLanguageKey,
    autoSaveHistoryKey,
    emailCriticalErrorsKey,
    emailFeatureUpdatesKey,
    emailWeeklyDigestKey,
  ];

  @override
  AppSettings build() {
    var disposed = false;
    ref.onDispose(() => disposed = true);
    unawaited(_restore(() => disposed));
    return AppSettings.fallback;
  }

  Future<void> _restore(bool Function() isDisposed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isDisposed()) return;
      state = state.copyWith(
        themeMode: prefs.getString(themeModeKey),
        accentColor: prefs.getString(accentColorKey),
        editorFontSize: prefs.getDouble(editorFontSizeKey),
        aiDetailLevel: prefs.getString(aiDetailLevelKey),
        aiLanguage: prefs.getString(aiLanguageKey),
        autoSaveHistory: prefs.getBool(autoSaveHistoryKey),
        emailCriticalErrors: prefs.getBool(emailCriticalErrorsKey),
        emailFeatureUpdates: prefs.getBool(emailFeatureUpdatesKey),
        emailWeeklyDigest: prefs.getBool(emailWeeklyDigestKey),
      );
    } catch (_) {
      // Tanpa dukungan penyimpanan: pakai nilai default (tidak fatal).
    }
  }

  Future<void> setAiDetailLevel(String value) => _persist(
    state.copyWith(aiDetailLevel: value),
    (prefs) => prefs.setString(aiDetailLevelKey, value),
  );

  Future<void> setAiLanguage(String value) => _persist(
    state.copyWith(aiLanguage: value),
    (prefs) => prefs.setString(aiLanguageKey, value),
  );

  Future<void> setAutoSaveHistory(bool value) => _persist(
    state.copyWith(autoSaveHistory: value),
    (prefs) => prefs.setBool(autoSaveHistoryKey, value),
  );

  Future<void> setEmailCriticalErrors(bool value) => _persist(
    state.copyWith(emailCriticalErrors: value),
    (prefs) => prefs.setBool(emailCriticalErrorsKey, value),
  );

  Future<void> setEmailFeatureUpdates(bool value) => _persist(
    state.copyWith(emailFeatureUpdates: value),
    (prefs) => prefs.setBool(emailFeatureUpdatesKey, value),
  );

  Future<void> setEmailWeeklyDigest(bool value) => _persist(
    state.copyWith(emailWeeklyDigest: value),
    (prefs) => prefs.setBool(emailWeeklyDigestKey, value),
  );

  Future<void> setEditorFontSize(double value) => _persist(
    state.copyWith(editorFontSize: value),
    (prefs) => prefs.setDouble(editorFontSizeKey, value),
  );

  Future<void> setThemeMode(String value) => _persist(
    state.copyWith(themeMode: value),
    (prefs) => prefs.setString(themeModeKey, value),
  );

  Future<void> setAccentColor(String value) => _persist(
    state.copyWith(accentColor: value),
    (prefs) => prefs.setString(accentColorKey, value),
  );

  /// Mengembalikan SEMUA preferensi ke nilai awal (padanan `resetAll()` web:
  /// web menghapus kunci `localStorage`, di sini kunci `shared_preferences`).
  Future<void> resetAll() async {
    state = AppSettings.fallback;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in allKeys) {
        await prefs.remove(key);
      }
    } catch (_) {
      // Diabaikan: state sudah kembali ke default.
    }
  }

  /// Ubah state lalu simpan (penyimpanan gagal = tidak fatal).
  Future<void> _persist(
    AppSettings next,
    Future<void> Function(SharedPreferences prefs) write,
  ) async {
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await write(prefs);
    } catch (_) {
      // Diabaikan: preferensi tetap berlaku untuk sesi berjalan.
    }
  }
}

/// Preferensi lokal aplikasi (tema, AI, editor).
final appSettingsProvider = NotifierProvider<AppSettingsController, AppSettings>(
  AppSettingsController.new,
);
