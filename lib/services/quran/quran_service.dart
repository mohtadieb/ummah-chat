// lib/services/quran/quran_service.dart
//
// Quran API helper (NOT Supabase)
// - Fetches a deterministic "daily ayah" based on UTC day-of-year
// - Fetches specific ayah by "surah:ayah" key
//
// Uses: https://api.alquran.cloud
// Arabic text edition: quran-uthmani   ✅
// Translation edition: depends on app language (langCode)
//
// ✅ Supported:
// - en -> en.sahih
// - nl -> nl.siregar
// - ar -> no translation (we return empty translation string)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class QuranService {
  static const _base = 'https://api.alquran.cloud/v1';

  // ✅ Arabic text
  static const String _arabicEdition = 'quran-uthmani';

  // ✅ Translations
  static const String _englishEdition = 'en.sahih';
  static const String _dutchEdition = 'nl.siregar';

  /// Pick translation edition based on language code.
  /// - Defaults to English for unknown languages.
  /// - If Arabic UI ('ar'), we return no translation (empty string).
  String? _translationEditionForLang(String? langCode) {
    final code = (langCode ?? 'en').toLowerCase();

    // handle cases like "en-US", "nl-NL"
    final base = code.split('-').first;

    switch (base) {
      case 'nl':
        return _dutchEdition;
      case 'ar':
        return null; // no translation
      case 'en':
      default:
        return _englishEdition;
    }
  }

  /// Deterministic daily ayah (1..6236) based on UTC day-of-year
  int _dailyGlobalAyahNumberUtc() {
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, 1, 1);
    final dayOfYear = now.difference(start).inDays + 1; // 1..366
    final n = (dayOfYear % 6236);
    return n == 0 ? 6236 : n;
  }

  Map<String, dynamic>? _findEdition(List data, String identifier) {
    for (final item in data) {
      if (item is! Map) continue;
      final ed = item['edition'];
      if (ed is! Map) continue;

      final id = ed['identifier']?.toString();
      if (id == null) continue;

      if (id == identifier) return Map<String, dynamic>.from(item as Map);
    }
    return null;
  }

  Never _throwMissingEditions(List data, String contextLabel) {
    // Helpful debug: print identifiers we actually got back
    try {
      final ids = data
          .whereType<Map>()
          .map((x) => (x['edition'] as Map?)?['identifier']?.toString())
          .whereType<String>()
          .toList();
      debugPrint('❌ QuranService missing editions ($contextLabel). Got: $ids');
    } catch (_) {}
    throw Exception('QuranService missing editions in response');
  }

  /// Fetch daily ayah (Arabic + translation) + metadata
  ///
  /// langCode examples:
  /// - "en", "en-US"
  /// - "nl", "nl-NL"
  /// - "ar"
  Future<Map<String, dynamic>> fetchDailyAyah({String? langCode}) async {
    final globalAyahNo = _dailyGlobalAyahNumberUtc();
    final trEdition = _translationEditionForLang(langCode);

    // Per docs: /ayah/{reference}/editions/{edition},{edition}
    // If trEdition == null (Arabic UI), only request Arabic edition.
    final editions = trEdition == null
        ? _arabicEdition
        : '$_arabicEdition,$trEdition';

    final url = Uri.parse('$_base/ayah/$globalAyahNo/editions/$editions');

    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('QuranService daily ayah failed: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final data = decoded['data'];

    if (data is! List || data.isEmpty) {
      throw Exception('QuranService daily ayah invalid response');
    }

    final ar = _findEdition(data, _arabicEdition);
    if (ar == null) _throwMissingEditions(data, 'fetchDailyAyah(arabic)');

    final tr = trEdition == null ? null : _findEdition(data, trEdition);

    // If we requested a translation but didn't get it -> error with debug info.
    if (trEdition != null && tr == null) {
      _throwMissingEditions(data, 'fetchDailyAyah(translation=$trEdition)');
    }

    final surahNo = (ar['surah']?['number'] as num?)?.toInt() ?? 1;
    final ayahNoInSurah = (ar['numberInSurah'] as num?)?.toInt() ?? 1;

    return {
      'surah': surahNo,
      'ayah': ayahNoInSurah,
      'surah_name_ar': (ar['surah']?['name'] ?? '').toString(),
      // Keep this key for UI compatibility; if no translation edition, leave it blank.
      'surah_name_en': (tr?['surah']?['englishName'] ?? '').toString(),
      'arabic': (ar['text'] ?? '').toString(),
      'translation': (tr?['text'] ?? '').toString(), // ✅ UI expects this
    };
  }

  /// Fetch by key "surah:ayah" e.g. "2:255"
  ///
  /// langCode examples:
  /// - "en", "nl", "ar"
  Future<Map<String, dynamic>> fetchAyahByKey(
      String ayahKey, {
        String? langCode,
      }) async {
    final parts = ayahKey.split(':');
    if (parts.length != 2) throw Exception('Invalid ayahKey: $ayahKey');

    final surah = int.tryParse(parts[0]) ?? 1;
    final ayah = int.tryParse(parts[1]) ?? 1;

    final trEdition = _translationEditionForLang(langCode);

    final editions = trEdition == null
        ? _arabicEdition
        : '$_arabicEdition,$trEdition';

    final url = Uri.parse('$_base/ayah/$surah:$ayah/editions/$editions');

    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('QuranService fetchAyahByKey failed: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final data = decoded['data'];

    if (data is! List || data.isEmpty) {
      throw Exception('QuranService fetchAyahByKey invalid response');
    }

    final ar = _findEdition(data, _arabicEdition);
    if (ar == null) _throwMissingEditions(data, 'fetchAyahByKey(arabic:$ayahKey)');

    final tr = trEdition == null ? null : _findEdition(data, trEdition);

    if (trEdition != null && tr == null) {
      _throwMissingEditions(data, 'fetchAyahByKey(translation=$trEdition:$ayahKey)');
    }

    return {
      'surah': surah,
      'ayah': ayah,
      'surah_name_ar': (ar['surah']?['name'] ?? '').toString(),
      'surah_name_en': (tr?['surah']?['englishName'] ?? '').toString(),
      'arabic': (ar['text'] ?? '').toString(),
      'translation': (tr?['text'] ?? '').toString(), // ✅ UI expects this
    };
  }
}
