import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/database/database_provider.dart';
import '../services/auth/auth_service.dart';
import '../components/my_input_alert_box.dart';
import '../models/dua.dart';
import '../helper/time_ago_text.dart';
import '../services/quran/quran_service.dart';

class DuaWallPage extends StatefulWidget {
  const DuaWallPage({super.key});

  @override
  State<DuaWallPage> createState() => _DuaWallPageState();
}

class _DuaWallPageState extends State<DuaWallPage> {
  late final DatabaseProvider databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);

  late final DatabaseProvider listeningProvider =
  Provider.of<DatabaseProvider>(context);

  bool _isLoading = true;
  final String _currentUserId = AuthService().getCurrentUserId();

  final QuranService _quran = QuranService();

  bool _ayahLoading = true;
  Map<String, dynamic>? _dailyAyah;

  bool _dismissedForToday = false;
  int? _dismissedUtcDayKey;
  String? _lastLang;

  int _utcDayKey(DateTime dtUtc) =>
      dtUtc.year * 10000 + dtUtc.month * 100 + dtUtc.day;

  String _ayahKeyFrom(Map<String, dynamic> a) {
    final surah = (a['surah'] as num?)?.toInt() ?? 0;
    final ayah = (a['ayah'] as num?)?.toInt() ?? 0;
    return '$surah:$ayah';
  }

  bool get _shouldShowAyahBanner {
    final todayKey = _utcDayKey(DateTime.now().toUtc());
    if (_dismissedForToday == true && _dismissedUtcDayKey == todayKey) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadDuaWall();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadDailyAyahForBanner();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final lang = context.locale.languageCode;
    if (_lastLang != lang) {
      _lastLang = lang;
      if (_shouldShowAyahBanner) {
        _loadDailyAyahForBanner(force: true);
      }
    }
  }

  Future<void> _loadDuaWall() async {
    setState(() => _isLoading = true);
    try {
      await databaseProvider.loadDuaWall();
    } catch (e) {
      debugPrint('Error loading Dua Wall: $e');
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadDailyAyahForBanner({bool force = false}) async {
    if (!force && !_shouldShowAyahBanner) return;

    if (mounted) setState(() => _ayahLoading = true);

    try {
      final lang = context.locale.languageCode;
      final ayah = await _quran.fetchDailyAyah(langCode: lang);

      if (!mounted) return;
      setState(() => _dailyAyah = ayah);
    } catch (e) {
      debugPrint('❌ Dua Wall daily ayah error: $e');
      if (!mounted) return;
      setState(() => _dailyAyah = null);
    } finally {
      if (!mounted) return;
      setState(() => _ayahLoading = false);
    }
  }

  void _dismissAyahBannerForToday() {
    final todayKey = _utcDayKey(DateTime.now().toUtc());
    setState(() {
      _dismissedForToday = true;
      _dismissedUtcDayKey = todayKey;
    });
  }

  void _shareAyah(Map<String, dynamic> a) {
    final key = _ayahKeyFrom(a);
    final arabic = (a['arabic'] ?? '').toString().trim();
    final translation =
    (a['translation'] ?? a['translation_en'] ?? '').toString().trim();

    final text = [
      '📖 ${'daily_ayah_title'.tr()}',
      '($key)',
      '',
      if (arabic.isNotEmpty) arabic,
      if (translation.isNotEmpty) '',
      if (translation.isNotEmpty) translation,
      '',
      '— Ummah Chat',
    ].join('\n');

    Share.share(text);
  }

  void _openCreateDuaDialog() {
    final TextEditingController duaController = TextEditingController();
    final messenger = ScaffoldMessenger.maybeOf(context);

    bool isAnonymous = false;
    bool isPrivate = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (innerContext, setInnerState) {
              return MyInputAlertBox(
                textController: duaController,
                hintText: "Write your dua here...".tr(),
                onPressedText: "Post".tr(),
                onPressed: () async {
                  final text = duaController.text.trim();

                  if (text.replaceAll(RegExp(r'\s+'), '').length < 5) {
                    messenger?.showSnackBar(
                      SnackBar(
                        content: Text(
                          "Your dua should be at least 5 characters.".tr(),
                        ),
                      ),
                    );
                    return;
                  }

                  try {
                    await databaseProvider.createDua(
                      text: text,
                      isAnonymous: isAnonymous,
                      isPrivate: isPrivate,
                    );

                    duaController.clear();
                    messenger?.showSnackBar(
                      SnackBar(
                        content: Text("Your dua has been shared.".tr()),
                      ),
                    );

                    await _loadDuaWall();
                  } catch (e) {
                    debugPrint('Error creating dua: $e');
                    messenger?.showSnackBar(
                      SnackBar(
                        content: Text(
                          "Could not share dua. Please try again.".tr(),
                        ),
                      ),
                    );
                  }
                },
                extraWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      "Visibility".tr(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: Text("Show my name".tr()),
                          selected: !isAnonymous && !isPrivate,
                          onSelected: (_) {
                            setInnerState(() {
                              isAnonymous = false;
                              isPrivate = false;
                            });
                          },
                        ),
                        FilterChip(
                          label: Text("Anonymous".tr()),
                          selected: isAnonymous,
                          onSelected: (value) {
                            setInnerState(() {
                              isAnonymous = value;
                              if (value) isPrivate = false;
                            });
                          },
                        ),
                        FilterChip(
                          label: Text("Private (only me)".tr()),
                          selected: isPrivate,
                          onSelected: (value) {
                            setInnerState(() {
                              isPrivate = value;
                              if (value) isAnonymous = false;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'visibility_help'.tr(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _toggleAmeen(Dua dua) async {
    try {
      await databaseProvider.toggleAmeenForDua(dua.id);
    } catch (e) {
      debugPrint('Error toggling Ameen: $e');
    }
  }

  Future<void> _confirmDeleteDua(Dua dua) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete dua?'.tr()),
          content: Text(
            'Are you sure you want to delete this dua? This cannot be undone.'
                .tr(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text('Delete'.tr()),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await databaseProvider.deleteDua(dua.id);
      messenger?.showSnackBar(
        SnackBar(content: Text('Dua deleted.'.tr())),
      );
    } catch (e) {
      debugPrint('Error deleting dua: $e');
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Could not delete dua. Please try again.'.tr()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    final List<Dua> allDuas = listeningProvider.duaWall;

    final visibleDuas = allDuas.where((d) {
      if (!d.isPrivate) return true;
      return d.userId == _currentUserId;
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDuaDialog,
        icon: const Icon(Icons.auto_awesome),
        label: Text("Write a dua".tr()),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.surface,
              cs.surface,
              cs.surfaceContainerLowest,
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadDuaWall();
              await _loadDailyAyahForBanner(force: true);
            },
            child: _isLoading && visibleDuas.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                _PremiumDuaHeader(
                  title: 'Dua Wall'.tr(),
                  subtitle: 'Share your duas and say Ameen for others.'.tr(),
                ),
                if (_shouldShowAyahBanner)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Dismissible(
                      key: ValueKey(
                        'dua_wall_daily_ayah_${_dismissedUtcDayKey ?? "none"}',
                      ),
                      direction: DismissDirection.horizontal,
                      onDismissed: (_) => _dismissAyahBannerForToday(),
                      background: _dismissBg(context, alignLeft: true),
                      secondaryBackground:
                      _dismissBg(context, alignLeft: false),
                      child: _DailyAyahBanner(
                        loading: _ayahLoading,
                        dailyAyah: _dailyAyah,
                        onRetry: _loadDailyAyahForBanner,
                        keyFrom: _ayahKeyFrom,
                        isSaved: (_dailyAyah == null)
                            ? false
                            : listeningProvider.isAyahBookmarkedByCurrentUser(
                          _ayahKeyFrom(_dailyAyah!),
                        ),
                        onToggleSave: () async {
                          if (_dailyAyah == null) return;
                          final key = _ayahKeyFrom(_dailyAyah!);
                          await listeningProvider.toggleBookmark(
                            itemType: 'ayah',
                            itemId: key,
                          );
                        },
                        onShare: () {
                          if (_dailyAyah == null) return;
                          _shareAyah(_dailyAyah!);
                        },
                      ),
                    ),
                  ),
                if (visibleDuas.isEmpty)
                  _PremiumEmptyState(
                    icon: Icons.menu_book_rounded,
                    title: "No duas yet".tr(),
                    subtitle: "Be the first to write a dua and let others say Ameen 💚".tr(),
                  )
                else
                  ...visibleDuas.map((dua) {
                    final isMine = dua.userId == _currentUserId;
                    final isAmeened = dua.userHasAmeened;

                    final String displayName =
                    dua.isAnonymous && !isMine
                        ? 'Anonymous'.tr()
                        : dua.userName;

                    final avatarInitial = displayName.isNotEmpty
                        ? displayName.trim()[0].toUpperCase()
                        : '?';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _PremiumDuaCard(
                        dua: dua,
                        currentUserId: _currentUserId,
                        displayName: displayName,
                        avatarInitial: avatarInitial,
                        isAmeened: isAmeened,
                        onToggleAmeen: () => _toggleAmeen(dua),
                        onDelete: isMine ? () => _confirmDeleteDua(dua) : null,
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dismissBg(BuildContext context, {required bool alignLeft}) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Icon(
        Icons.close_rounded,
        color: cs.primary.withValues(alpha: 0.75),
      ),
    );
  }
}

class _PremiumDuaHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PremiumDuaHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withValues(alpha: 0.14),
              cs.secondary.withValues(alpha: 0.55),
              cs.surfaceContainerHigh,
            ],
          ),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.14),
              ),
              child: Icon(
                Icons.favorite_outline_rounded,
                color: cs.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.72),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PremiumEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 30,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumDuaCard extends StatelessWidget {
  final Dua dua;
  final String currentUserId;
  final String displayName;
  final String avatarInitial;
  final bool isAmeened;
  final VoidCallback onToggleAmeen;
  final VoidCallback? onDelete;

  const _PremiumDuaCard({
    required this.dua,
    required this.currentUserId,
    required this.displayName,
    required this.avatarInitial,
    required this.isAmeened,
    required this.onToggleAmeen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMine = dua.userId == currentUserId;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerHigh,
            cs.surfaceContainer,
          ],
        ),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: dua.isAnonymous && !isMine
                      ? cs.primary.withValues(alpha: 0.10)
                      : cs.primary.withValues(alpha: 0.15),
                  child: dua.isAnonymous && !isMine
                      ? Icon(
                    Icons.nightlight_round,
                    color: cs.primary,
                    size: 20,
                  )
                      : Text(
                    avatarInitial,
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (dua.isPrivate) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.orange.withValues(alpha: 0.10),
                              ),
                              child: Text(
                                "Private".tr(),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      TimeAgoText(
                        createdAt: dua.createdAt,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.58),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red.withValues(alpha: 0.85),
                    onPressed: onDelete,
                    tooltip: 'Delete dua'.tr(),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              dua.text,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.55,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    dua.ameenCount == 0
                        ? 'No Ameens yet'.tr()
                        : 'ameen_count'.plural(
                      dua.ameenCount,
                      namedArgs: {
                        'count': dua.ameenCount.toString(),
                      },
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.66),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    elevation: isAmeened ? 3 : 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    backgroundColor:
                    isAmeened ? cs.primary : cs.primary.withValues(alpha: 0.10),
                    foregroundColor: isAmeened ? cs.onPrimary : cs.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: isAmeened
                          ? BorderSide.none
                          : BorderSide(
                        color: cs.primary.withValues(alpha: 0.28),
                        width: 1.2,
                      ),
                    ),
                  ),
                  icon: const Text(
                    '🤲',
                    style: TextStyle(fontSize: 18),
                  ),
                  label: Text(
                    "Ameen".tr(),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: onToggleAmeen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyAyahBanner extends StatelessWidget {
  final bool loading;
  final Map<String, dynamic>? dailyAyah;
  final VoidCallback onRetry;
  final String Function(Map<String, dynamic>) keyFrom;
  final bool isSaved;
  final VoidCallback onToggleSave;
  final VoidCallback onShare;

  const _DailyAyahBanner({
    super.key,
    required this.loading,
    required this.dailyAyah,
    required this.onRetry,
    required this.keyFrom,
    required this.isSaved,
    required this.onToggleSave,
    required this.onShare,
  });

  String _compact(String s) {
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (loading) {
      return _PremiumAyahShell(
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'daily_ayah_loading'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.swipe_rounded,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ),
      );
    }

    if (dailyAyah == null) {
      return _PremiumAyahShell(
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_outlined,
                color: cs.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'daily_ayah_load_failed_compact'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text('retry'.tr()),
            ),
          ],
        ),
      );
    }

    final key = keyFrom(dailyAyah!);
    final arabic = _compact((dailyAyah!['arabic'] ?? '').toString());
    final translation = _compact(
      (dailyAyah!['translation'] ?? dailyAyah!['translation_en'] ?? '')
          .toString(),
    );
    final preview = translation.isNotEmpty ? translation : arabic;

    return _PremiumAyahShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: cs.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'daily_ayah_title'.tr(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _AyahActionButton(
                tooltip: isSaved ? 'saved'.tr() : 'save'.tr(),
                icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                onTap: onToggleSave,
              ),
              const SizedBox(width: 8),
              _AyahActionButton(
                tooltip: 'share'.tr(),
                icon: Icons.share_outlined,
                onTap: onShare,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (arabic.isNotEmpty)
            Text(
              arabic,
              textAlign: TextAlign.start,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          if (arabic.isNotEmpty && preview.isNotEmpty) const SizedBox(height: 10),
          if (preview.isNotEmpty)
            Text(
              preview,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: cs.onSurface.withValues(alpha: 0.78),
              ),
            ),
        ],
      ),
    );
  }
}

class _PremiumAyahShell extends StatelessWidget {
  final Widget child;

  const _PremiumAyahShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerHigh,
            cs.surfaceContainer,
          ],
        ),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AyahActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _AyahActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              color: cs.primary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}