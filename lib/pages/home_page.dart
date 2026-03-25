// lib/pages/home_page.dart
//
// ✅ Premium redesign
// ✅ Daily Ayah removed from HomePage
// ✅ For You remains frozen for session
// ✅ Local tile theme added so text posts have better contrast
// ✅ Top card scrolls away fluently from feed scroll
// ✅ Tab selector stays pinned
// ✅ Each tab keeps its own remembered list position
// ✅ Header collapse / pinned tabs are shared globally
// ✅ Feed no longer slips under the tabs
// ✅ Uses ExtendedNestedScrollView to avoid inner tab sync bleed

import 'package:easy_localization/easy_localization.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/my_post_tile.dart';
import '../helper/for_you_ranker.dart';
import '../helper/navigate_pages.dart';
import '../models/post.dart';
import '../services/database/database_provider.dart';
import 'create_post_page.dart';

const double kHomeHeaderCardHeight = 126.0;
const double kHomeHeaderOuterHeight = 148.0;
const double kHomeTabBarAreaHeight = 66.0;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  static const double _tabBarHeaderHeight = kHomeTabBarAreaHeight;

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

  void _onDbChanged() {
    final currentPosts =
    databaseProvider.posts.where((p) => p.communityId == null).toList();

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
        final newPosts =
        currentPosts.where((p) => newIds.contains(p.id)).toList();
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

  Widget _buildPostsSliver(
      List<Post> posts, {
        bool isForYou = false,
      }) {
    final loadingPost = context.watch<DatabaseProvider>().loadingPost;

    final list = [
      if (!isForYou && loadingPost != null) loadingPost,
      ...posts,
    ];

    if (_initialFeedLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _FeedLoadingState(),
      );
    }

    if (list.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyFeedState(
          title: 'Nothing here..'.tr(),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
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
          childCount: list.length,
        ),
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

  double _pinnedHeaderHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.padding.top + _tabBarHeaderHeight;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          top: false,
          child: ExtendedNestedScrollView(
            onlyOneScrollInBody: true,
            pinnedHeaderSliverHeightBuilder: () =>
                _pinnedHeaderHeight(context),
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverOverlapAbsorber(
                  handle:
                  ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: const _HeaderArea(),
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedTabBarDelegate(
                    minExtentValue: _tabBarHeaderHeight,
                    maxExtentValue: _tabBarHeaderHeight,
                    child: Container(
                      color: cs.surface,
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: MediaQuery.of(context).padding.top,
                        bottom: 12,
                      ),
                      child: Align(
                        alignment: Alignment.center,
                        child: _PremiumTabBar(
                          controller: _tabController,
                          tabs: [
                            "For You".tr(),
                            "Following".tr(),
                            "Communities".tr(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _HomeTabView(
                  storageKey: 'home_for_you',
                  visibleKey: const Key('home_for_you_tab'),
                  onRefresh: () async {
                    await databaseProvider.reloadPosts();
                    await _rebuildFrozenForYou();
                  },
                  sliver: _buildPostsSliver(
                    forYouPosts,
                    isForYou: true,
                  ),
                ),
                _HomeTabView(
                  storageKey: 'home_following',
                  visibleKey: const Key('home_following_tab'),
                  onRefresh: () async {
                    await databaseProvider.reloadPosts();
                  },
                  sliver: _buildPostsSliver(followingGlobalPosts),
                ),
                _HomeTabView(
                  storageKey: 'home_communities',
                  visibleKey: const Key('home_communities_tab'),
                  onRefresh: () async {
                    await databaseProvider.reloadPosts();
                  },
                  sliver: _buildPostsSliver(communityPosts),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTabView extends StatefulWidget {
  final String storageKey;
  final Key visibleKey;
  final Future<void> Function() onRefresh;
  final Widget sliver;

  const _HomeTabView({
    required this.storageKey,
    required this.visibleKey,
    required this.onRefresh,
    required this.sliver,
  });

  @override
  State<_HomeTabView> createState() => _HomeTabViewState();
}

class _HomeTabViewState extends State<_HomeTabView>
    with AutomaticKeepAliveClientMixin<_HomeTabView> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ExtendedVisibilityDetector(
      uniqueKey: widget.visibleKey,
      child: Builder(
        builder: (context) {
          return RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: CustomScrollView(
              key: PageStorageKey<String>(widget.storageKey),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverOverlapInjector(
                  handle:
                  ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                ),
                widget.sliver,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderArea extends StatelessWidget {
  const _HeaderArea();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: SizedBox(
        height: kHomeHeaderCardHeight,
        child: _PremiumHomeHeader(
          title: 'Ummah Chat',
          subtitle: 'home_feed_subtitle'.tr(),
        ),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
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
        crossAxisAlignment: CrossAxisAlignment.center,
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.72),
                    height: 1.18,
                  ),
                ),
              ],
            ),
          ),
        ],
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

    return SizedBox(
      height: kHomeTabBarAreaHeight - 12,
      child: Container(
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
      ),
    );
  }
}

class _PinnedTabBarDelegate extends SliverPersistentHeaderDelegate {
  final double minExtentValue;
  final double maxExtentValue;
  final Widget child;

  _PinnedTabBarDelegate({
    required this.minExtentValue,
    required this.maxExtentValue,
    required this.child,
  });

  @override
  double get minExtent => minExtentValue;

  @override
  double get maxExtent => maxExtentValue;

  @override
  Widget build(
      BuildContext context,
      double shrinkOffset,
      bool overlapsContent,
      ) {
    return ClipRect(
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedTabBarDelegate oldDelegate) {
    return oldDelegate.minExtentValue != minExtentValue ||
        oldDelegate.maxExtentValue != maxExtentValue ||
        oldDelegate.child != child;
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