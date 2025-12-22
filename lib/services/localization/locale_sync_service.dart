import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocaleSyncService {
  static final _sb = Supabase.instance.client;

  /// Push the currently selected app language (en/nl/ar) into profiles.locale
  static Future<void> syncLocaleToSupabase(BuildContext context) async {
    final user = _sb.auth.currentUser;
    if (user == null) return;

    // because you use `useOnlyLangCode: true`, this will be "en"/"nl"/"ar"
    final lang = context.locale.languageCode;

    try {
      await _sb.from('profiles').update({'locale': lang}).eq('id', user.id);
      debugPrint('🌍 Synced locale="$lang" to profiles for ${user.id}');
    } catch (e) {
      debugPrint('❌ Failed to sync locale: $e');
    }
  }
}
