// lib/pages/home_page.dart
//
// ✅ Daily Ayah sits at the top of HomePage
// ✅ Swipe away (Dismissible)
// ✅ When swiped away, it stays hidden UNTIL the next UTC day (new daily ayah)
// ✅ Banner includes Bookmark + Share buttons
// ✅ No navigation to DailyAyahPage anymore (it’s self-contained)

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../helper/for_you_ranker.dart';
import '../models/post.dart';
import '../services/database/database_provider.dart';
import '../components/my_post_tile.dart';
import '../helper/navigate_pages.dart';
import 'create_post_page.dart';

// ✅ Quran API service (NOT Supabase)
import '../services/quran/quran_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  @override
  void setState(VoidCallback fn) {
    if (!mounted) return;
    super.setState(fn);
  }

  /// ✅ Use listen:false so HomePage does NOT rebuild on every notifyListeners()
  late final DatabaseProvider databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);

  final TextEditingController _messageController = TextEditingController();
  late final TabController _tabController;

  // ✅ Daily ayah banner state
  final QuranService _quran = QuranService();

  bool _ayahLoading = true;
  Map<String, dynamic>? _dailyAyah;

  // ✅ hide logic: once dismissed, keep hidden until next UTC day
  bool _dismissedForToday = false;
  int? _dismissedUtcDayKey; // e.g. 20251219

  // ✅ reload banner translation when user changes app language
  String? _lastLang;

  // ✅ Freeze For You ranking for the session (no reshuffling while scrolling)
  List<Post> _frozenForYou = [];
  bool _forYouFrozenReady = false;

  // ✅ NEW: keep last known provider post ids so we can prune frozen list
  Set<String> _lastAllPostIds = {};

  int _utcDayKey(DateTime dtUtc) =>
      dtUtc.year * 10000 + dtUtc.month * 100 + dtUtc.day;

  String _ayahKeyFrom(Map<String, dynamic> a) {
    final surah = (a['surah'] as num?)?.toInt() ?? 0;
    final ayah = (a['ayah'] as num?)?.toInt() ?? 0;
    return '$surah:$ayah';
  }

  void _onDbChanged() {
    final currentPosts = databaseProvider.posts.where((p) => p.communityId == null).toList();
    final currentIds = currentPosts.map((p) => p.id).whereType<String>().toSet();

    // first time baseline
    if (_lastAllPostIds.isEmpty) {
      _lastAllPostIds = currentIds;
      return;
    }

    // find newly added post ids
    final newIds = currentIds.difference(_lastAllPostIds);

    // update baseline
    _lastAllPostIds = currentIds;

    if (!mounted) return;

    setState(() {
      // ✅ 1) prune deleted
      _frozenForYou.removeWhere((p) => !currentIds.contains(p.id));

      // ✅ 2) add new posts to top (no reshuffle)
      if (newIds.isNotEmpty) {
        final newPosts = currentPosts.where((p) => newIds.contains(p.id)).toList();

        // sort newest first (if createdAt exists)
        newPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // avoid duplicates then prepend
        final existing = _frozenForYou.map((p) => p.id).toSet();
        _frozenForYou = [
          ...newPosts.where((p) => !existing.contains(p.id)),
          ..._frozenForYou,
        ];

        _forYouFrozenReady = true;
      }
    });
  }


  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    // ✅ NEW: listen to provider changes so frozen list can prune deletes
    databaseProvider.addListener(_onDbChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await databaseProvider.reloadPosts(); // ✅ loads posts + bookmarks etc
      await databaseProvider.getAllCommunities();

      // ✅ Load daily ayah for banner (best-effort)
      await _loadDailyAyahForBanner();

      // ✅ Build frozen For You ONCE after initial load
      await _rebuildFrozenForYou();

      // baseline ids
      _lastAllPostIds = databaseProvider.posts
          .map((p) => p.id)
          .whereType<String>()
          .toSet();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final lang = context.locale.languageCode;

    // ✅ Only refetch if language changed
    if (_lastLang != lang) {
      _lastLang = lang;

      // If banner is currently allowed to show, reload translation
      if (_shouldShowAyahBanner) {
        _loadDailyAyahForBanner(force: true);
      }
    }
  }

  bool get _shouldShowAyahBanner {
    final todayKey = _utcDayKey(DateTime.now().toUtc());

    // If dismissed before, only re-show when the day changes
    if (_dismissedForToday == true && _dismissedUtcDayKey == todayKey) {
      return false;
    }

    // day changed → allow it again
    return true;
  }

  Future<void> _loadDailyAyahForBanner({bool force = false}) async {
    // If user dismissed and it’s still the same UTC day, don’t re-fetch/show
    if (!force && !_shouldShowAyahBanner) return;

    if (mounted) setState(() => _ayahLoading = true);

    try {
      // ✅ IMPORTANT: pass langCode so translation matches app language
      final lang = context.locale.languageCode;
      final ayah = await _quran.fetchDailyAyah(langCode: lang);

      if (!mounted) return;
      setState(() => _dailyAyah = ayah);
    } catch (e) {
      debugPrint('❌ Home banner daily ayah error: $e');
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

  /// ✅ Rebuild frozen For You list (only after load / manual refresh)
  Future<void> _rebuildFrozenForYou() async {
    // Use provider data snapshot at this moment
    final candidates =
    databaseProvider.posts.where((p) => p.communityId == null).toList();

    final ranked = ForYouRanker.rank(
      candidates: candidates,
      currentUserId: databaseProvider.currentUserId,
      followingIds: databaseProvider.followingUserIds,
      friendIds: databaseProvider.friendUserIds,
      likesByPostId: databaseProvider.likesByPostId,
    );

    if (!mounted) return;
    setState(() {
      _frozenForYou = ranked;
      _forYouFrozenReady = true;
    });
  }

  @override
  void dispose() {
    databaseProvider.removeListener(_onDbChanged);
    _messageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // ✅ Only listen to the provider where needed (for these lists)
    final db = context.watch<DatabaseProvider>();

    // ✅ For You stays frozen while scrolling
    final forYouPosts = _forYouFrozenReady ? _frozenForYou : const <Post>[];

    // 🔁 following posts without community (these can still update live)
    final List<Post> followingGlobalPosts =
    db.followingPosts.where((p) => p.communityId == null).toList();

    // joined community IDs
    final joinedCommunityIds = db.allCommunities
        .where((c) => c['is_joined'] == true)
        .map<String>((c) => c['id'] as String)
        .toSet();

    // 🔁 posts from communities the user joined
    final List<Post> communityPosts = db.posts
        .where((p) =>
    p.communityId != null && joinedCommunityIds.contains(p.communityId))
        .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreatePostPage(),
            ),
          );
        },
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ✅ Daily Ayah banner (self-contained)
          if (_shouldShowAyahBanner)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Dismissible(
                key: ValueKey(
                    'daily_ayah_banner_${_dismissedUtcDayKey ?? "none"}'),
                direction: DismissDirection.horizontal,
                onDismissed: (_) => _dismissAyahBannerForToday(),
                background: _dismissBg(context, alignLeft: true),
                secondaryBackground: _dismissBg(context, alignLeft: false),
                child: _DailyAyahBanner(
                  loading: _ayahLoading,
                  dailyAyah: _dailyAyah,
                  onRetry: _loadDailyAyahForBanner,
                  keyFrom: _ayahKeyFrom,
                  isSaved: (_dailyAyah == null)
                      ? false
                      : db.isAyahBookmarkedByCurrentUser(
                    _ayahKeyFrom(_dailyAyah!),
                  ),
                  onToggleSave: () async {
                    if (_dailyAyah == null) return;
                    final key = _ayahKeyFrom(_dailyAyah!);
                    await db.toggleBookmark(itemType: 'ayah', itemId: key);
                  },
                  onShare: () {
                    if (_dailyAyah == null) return;
                    _shareAyah(_dailyAyah!);
                  },
                ),
              ),
            ),

          // Tabs
          Container(
            color: colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              labelColor: colorScheme.inversePrimary,
              unselectedLabelColor: colorScheme.primary,
              indicatorColor: colorScheme.secondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: [
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text("For You".tr()),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text("Following".tr()),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text("Communities".tr()),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostList(forYouPosts, isForYou: true),
                _buildPostList(followingGlobalPosts),
                _buildPostList(communityPosts),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dismissBg(BuildContext context, {required bool alignLeft}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Icon(
        Icons.close_rounded,
        color: theme.colorScheme.primary.withValues(alpha: 0.65),
      ),
    );
  }

  Widget _buildPostList(List<Post> posts, {bool isForYou = false}) {
    // ✅ Only non-ForYou tabs can show the "loading post" injected row
    final loadingPost = context.watch<DatabaseProvider>().loadingPost;

    final list = [
      if (!isForYou && loadingPost != null) loadingPost,
      ...posts,
    ];

    return RefreshIndicator(
      onRefresh: () async {
        await databaseProvider.reloadPosts();

        // ✅ Only re-rank For You on manual refresh
        if (isForYou) {
          await _rebuildFrozenForYou();
        }
      },
      child: list.isEmpty
          ? LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Center(
                child: Text("Nothing here..".tr()),
              ),
            ),
          );
        },
      )
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final post = list[index];

          if (post.id == 'loading') {
            return _buildLoadingPostTile();
          }

          return MyPostTile(
            key: ValueKey(post.id),
            post: post,
            onUserTap: () => goUserPage(context, post.userId),
            onPostTap: () => goPostPage(context, post),
            scaffoldContext: context,
          );
        },
      ),
    );
  }

  Widget _buildLoadingPostTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "Posting your content…".tr(),
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          )
        ],
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
    final x = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return x;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Loading view
    if (loading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'daily_ayah_loading'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.swipe,
                size: 18, color: cs.onSurface.withValues(alpha: 0.35)),
          ],
        ),
      );
    }

    // Error view
    if (dailyAyah == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(Icons.menu_book_outlined, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'daily_ayah_load_failed_compact'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
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

    // Success view
    final key = keyFrom(dailyAyah!);
    final arabic = _compact((dailyAyah!['arabic'] ?? '').toString());
    final translation = _compact(
      (dailyAyah!['translation'] ?? dailyAyah!['translation_en'] ?? '')
          .toString(),
    );
    final preview = translation.isNotEmpty ? translation : arabic;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${'daily_ayah_title'.tr()} ($key)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              // ✅ compact actions
              IconButton(
                tooltip: isSaved ? 'saved'.tr() : 'save'.tr(),
                onPressed: onToggleSave,
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: cs.primary,
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              IconButton(
                tooltip: 'share'.tr(),
                onPressed: onShare,
                icon: Icon(
                  Icons.share_outlined,
                  color: cs.primary,
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            preview,
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.2,
              color: cs.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}


