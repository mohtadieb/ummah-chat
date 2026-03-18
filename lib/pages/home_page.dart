// lib/pages/home_page.dart
//
// ✅ Premium redesign
// ✅ Daily Ayah removed from HomePage
// ✅ For You remains frozen for session
// ✅ Local tile theme added so text posts have better contrast

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../helper/for_you_ranker.dart';
import '../models/post.dart';
import '../services/database/database_provider.dart';
import '../components/my_post_tile.dart';
import '../helper/navigate_pages.dart';
import 'create_post_page.dart';

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

  late final DatabaseProvider databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);

  final TextEditingController _messageController = TextEditingController();
  late final TabController _tabController;

  String? _lastLang;

  List<Post> _frozenForYou = [];
  bool _forYouFrozenReady = false;
  bool _initialFeedLoading = true;

  Set<String> _lastAllPostIds = {};

  void _onDbChanged() {
    final currentPosts = databaseProvider.posts
        .where((p) => p.communityId == null)
        .toList();

    final currentIds = currentPosts.map((p) => p.id).whereType<String>().toSet();

    if (_lastAllPostIds.isEmpty) {
      _lastAllPostIds = currentIds;
      return;
    }

    final newIds = currentIds.difference(_lastAllPostIds);
    _lastAllPostIds = currentIds;

    if (!mounted) return;

    setState(() {
      _frozenForYou.removeWhere((p) => !currentIds.contains(p.id));

      if (newIds.isNotEmpty) {
        final newPosts = currentPosts.where((p) => newIds.contains(p.id)).toList();
        newPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
    databaseProvider.addListener(_onDbChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await databaseProvider.reloadPosts();
        await databaseProvider.getAllCommunities();
        await _rebuildFrozenForYou();

        _lastAllPostIds = databaseProvider.posts
            .map((p) => p.id)
            .whereType<String>()
            .toSet();
      } finally {
        if (!mounted) return;
        setState(() {
          _initialFeedLoading = false;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lastLang = context.locale.languageCode;
  }

  Future<void> _rebuildFrozenForYou() async {
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

  ThemeData _postTileTheme(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return theme.copyWith(
      colorScheme: cs.copyWith(
        primary: cs.onSurface,
        secondary: cs.surfaceContainerHigh,
        tertiary: cs.surfaceContainer,
        surface: cs.surfaceContainerHigh,
        inversePrimary: cs.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final db = context.watch<DatabaseProvider>();

    final forYouPosts = _forYouFrozenReady ? _frozenForYou : const <Post>[];

    final List<Post> followingGlobalPosts =
    db.followingPosts.where((p) => p.communityId == null).toList();

    final joinedCommunityIds = db.allCommunities
        .where((c) => c['is_joined'] == true)
        .map<String>((c) => c['id'] as String)
        .toSet();

    final List<Post> communityPosts = db.posts
        .where((p) =>
    p.communityId != null && joinedCommunityIds.contains(p.communityId))
        .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        elevation: 6,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreatePostPage(),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Post'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
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
          child: Column(
            children: [
              _PremiumHomeHeader(
                title: 'Ummah Chat',
                subtitle: 'home_feed_subtitle'.tr(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _PremiumTabBar(
                  controller: _tabController,
                  tabs: [
                    "For You".tr(),
                    "Following".tr(),
                    "Communities".tr(),
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
        ),
      ),
    );
  }

  Widget _buildPostList(List<Post> posts, {bool isForYou = false}) {
    final loadingPost = context.watch<DatabaseProvider>().loadingPost;

    final list = [
      if (!isForYou && loadingPost != null) loadingPost,
      ...posts,
    ];

    return RefreshIndicator(
      onRefresh: () async {
        await databaseProvider.reloadPosts();
        if (isForYou) {
          await _rebuildFrozenForYou();
        }
      },
      child: _initialFeedLoading
          ? LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const _FeedLoadingState(),
            ),
          );
        },
      )
          : list.isEmpty
          ? LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: _EmptyFeedState(
                title: 'Nothing here..'.tr(),
              ),
            ),
          );
        },
      )
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final post = list[index];

          if (post.id == 'loading') {
            return _buildLoadingPostTile();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Theme(
              data: _postTileTheme(context),
              child: MyPostTile(
                key: ValueKey(post.id),
                post: post,
                onUserTap: () => goUserPage(context, post.userId),
                onPostTap: () => goPostPage(context, post),
                scaffoldContext: context,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingPostTile() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "Posting your content…".tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumHomeHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PremiumHomeHeader({
    required this.title,
    required this.subtitle,
  });

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning'.tr();
    if (hour < 18) return 'Good afternoon'.tr();
    return 'Good evening'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
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
                Icons.auto_awesome_rounded,
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
                    _greeting(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
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

class _PremiumTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;

  const _PremiumTabBar({
    required this.controller,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        labelColor: cs.onPrimary,
        unselectedLabelColor: cs.onSurface.withValues(alpha: 0.72),
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        splashBorderRadius: BorderRadius.circular(14),
        tabs: tabs
            .map(
              (tab) => Tab(
            height: 42,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(tab),
            ),
          ),
        )
            .toList(),
      ),
    );
  }
}

class _FeedLoadingState extends StatelessWidget {
  const _FeedLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading posts...'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  final String title;

  const _EmptyFeedState({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_outlined,
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
              'Pull down to refresh.'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}