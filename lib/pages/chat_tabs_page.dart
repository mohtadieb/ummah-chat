import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/my_search_bar.dart';
import '../services/database/database_provider.dart';
import 'communities_page.dart' as communities_page;
import 'create_community_page.dart';
import 'create_group_page.dart';
import 'friends_page.dart' as friends_page;
import 'groups_page.dart' as groups_page;
import 'search_page.dart';

const double kChatsHeaderCardHeight = 126.0;
const double kChatsPinnedTabsHeight = 62.0;
const double kChatsPinnedSearchHeight = 118.0;
const double kChatsPinnedSearchCardHeight = 112.0;

class ChatTabsPage extends StatefulWidget {
  const ChatTabsPage({super.key});

  @override
  State<ChatTabsPage> createState() => _ChatTabsPageState();
}

class _ChatTabsPageState extends State<ChatTabsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentTabIndex = 0;

  final TextEditingController _friendsSearchController =
  TextEditingController();
  final TextEditingController _groupsSearchController = TextEditingController();
  final TextEditingController _communitiesSearchController =
  TextEditingController();

  String _friendsQuery = '';
  String _groupsQuery = '';
  String _communitiesQuery = '';

  int _friendsCount = 0;
  int _groupsCount = 0;
  int _communitiesCount = 0;

  Timer? _communitiesSearchDebounce;
  static const _communitiesDebounceDuration = Duration(milliseconds: 350);

  bool _isSearchingCommunities = false;
  bool _hasCompletedCommunitiesSearch = false;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<DatabaseProvider>(context, listen: false).getAllCommunities();
    });
  }

  void _handleTabChanged() {
    if (!mounted) return;
    if (_currentTabIndex == _tabController.index) return;

    setState(() {
      _currentTabIndex = _tabController.index;
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();

    _friendsSearchController.dispose();
    _groupsSearchController.dispose();
    _communitiesSearchController.dispose();
    _communitiesSearchDebounce?.cancel();

    super.dispose();
  }

  String _currentFabLabel() {
    if (_currentTabIndex == 0) return "Find people".tr();
    if (_currentTabIndex == 1) return "New group".tr();
    return "Add community".tr();
  }

  IconData _currentFabIcon() {
    if (_currentTabIndex == 0) return Icons.person_search;
    if (_currentTabIndex == 1) return Icons.group_add;
    return Icons.group_add;
  }

  Future<void> _onFabPressed() async {
    if (_currentTabIndex == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchPage()),
      );
      return;
    }

    if (_currentTabIndex == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateGroupPage()),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateCommunityPage()),
    );

    if (!mounted) return;
    Provider.of<DatabaseProvider>(context, listen: false).getAllCommunities();
  }

  void _onCommunitiesSearchChanged(String value) {
    final trimmed = value.trim();

    _communitiesSearchDebounce?.cancel();

    setState(() {
      _communitiesQuery = value;
      _isSearchingCommunities = trimmed.isNotEmpty;
      _hasCompletedCommunitiesSearch = false;
    });

    _communitiesSearchDebounce =
        Timer(_communitiesDebounceDuration, () async {
          if (!mounted) return;

          final provider = Provider.of<DatabaseProvider>(context, listen: false);

          if (trimmed.isNotEmpty) {
            await provider.searchCommunities(trimmed);

            if (!mounted) return;
            setState(() {
              _isSearchingCommunities = false;
              _hasCompletedCommunitiesSearch = true;
            });
          } else {
            provider.clearCommunitySearchResults();

            if (!mounted) return;
            setState(() {
              _isSearchingCommunities = false;
              _hasCompletedCommunitiesSearch = false;
            });
          }
        });
  }

  void _clearCommunitiesSearch() {
    _communitiesSearchDebounce?.cancel();

    final provider = Provider.of<DatabaseProvider>(context, listen: false);

    setState(() {
      _communitiesSearchController.clear();
      _communitiesQuery = '';
      _isSearchingCommunities = false;
      _hasCompletedCommunitiesSearch = false;
    });

    provider.clearCommunitySearchResults();
  }

  Widget _buildSearchCardForIndex(int index) {
    switch (index) {
      case 0:
        return _PinnedSearchCardShell(
          child: _PinnedSearchCard(
            controller: _friendsSearchController,
            hintText: 'Search chats'.tr(),
            title: 'Your chats'.tr(),
            count: _friendsCount,
            onChanged: (value) {
              setState(() => _friendsQuery = value);
            },
            onClear: () {
              setState(() {
                _friendsSearchController.clear();
                _friendsQuery = '';
              });
            },
          ),
        );
      case 1:
        return _PinnedSearchCardShell(
          child: _PinnedSearchCard(
            controller: _groupsSearchController,
            hintText: 'Search groups'.tr(),
            title: 'Your groups'.tr(),
            count: _groupsCount,
            onChanged: (value) {
              setState(() => _groupsQuery = value);
            },
            onClear: () {
              setState(() {
                _groupsSearchController.clear();
                _groupsQuery = '';
              });
            },
          ),
        );
      default:
        return _PinnedSearchCardShell(
          child: _PinnedSearchCard(
            controller: _communitiesSearchController,
            hintText: 'Search communities'.tr(),
            title: 'Your communities'.tr(),
            count: _communitiesCount,
            onChanged: _onCommunitiesSearchChanged,
            onClear: _clearCommunitiesSearch,
          ),
        );
    }
  }

  Widget _buildAnimatedPinnedSearchArea() {
    return AnimatedBuilder(
      animation: _tabController.animation!,
      builder: (context, _) {
        final value = _tabController.animation!.value.clamp(0.0, 2.0);
        final leftIndex = value.floor().clamp(0, 2);
        final rightIndex = value.ceil().clamp(0, 2);
        final t = value - leftIndex;

        final leftOffset = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-1, 0),
        ).transform(t);

        final rightOffset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).transform(t);

        return SizedBox(
          height: kChatsPinnedSearchHeight,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                SlideTransition(
                  position: AlwaysStoppedAnimation<Offset>(leftOffset),
                  child: _buildSearchCardForIndex(leftIndex),
                ),
                if (rightIndex != leftIndex)
                  SlideTransition(
                    position: AlwaysStoppedAnimation<Offset>(rightOffset),
                    child: _buildSearchCardForIndex(rightIndex),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onFabPressed,
        icon: Icon(_currentFabIcon()),
        label: Text(_currentFabLabel()),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 6,
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
          child: NestedScrollView(
            physics: const ClampingScrollPhysics(),
            floatHeaderSlivers: false,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                const SliverToBoxAdapter(
                  child: _ChatsHeaderArea(),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedSimpleDelegate(
                    extent: kChatsPinnedTabsHeight,
                    child: Container(
                      color: cs.surface,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _PremiumTabBar(
                        controller: _tabController,
                        tabs: [
                          "Friends".tr(),
                          "Groups".tr(),
                          "Communities".tr(),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverOverlapAbsorber(
                  handle:
                  NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverPersistentHeader(
                    pinned: true,
                    delegate: _PinnedSimpleDelegate(
                      extent: kChatsPinnedSearchHeight,
                      child: Container(
                        color: cs.surface,
                        child: _buildAnimatedPinnedSearchArea(),
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: ClipRect(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ChatsKeepAlive(
                    child: friends_page.FriendsPage(
                      includeMahrams: true,
                      embeddedMode: true,
                      embeddedSearchQuery: _friendsQuery,
                      onEmbeddedCountChanged: (count) {
                        if (_friendsCount == count) return;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() => _friendsCount = count);
                        });
                      },
                    ),
                  ),
                  _ChatsKeepAlive(
                    child: groups_page.GroupsPage(
                      embeddedMode: true,
                      embeddedSearchQuery: _groupsQuery,
                      onEmbeddedCountChanged: (count) {
                        if (_groupsCount == count) return;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() => _groupsCount = count);
                        });
                      },
                    ),
                  ),
                  _ChatsKeepAlive(
                    child: communities_page.CommunitiesPage(
                      embeddedMode: true,
                      embeddedSearchQuery: _communitiesQuery,
                      embeddedCommunitiesSearching: _isSearchingCommunities,
                      embeddedCommunitiesHasCompletedSearch:
                      _hasCompletedCommunitiesSearch,
                      onEmbeddedCountChanged: (count) {
                        if (_communitiesCount == count) return;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() => _communitiesCount = count);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinnedSearchCardShell extends StatelessWidget {
  final Widget child;

  const _PinnedSearchCardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: SizedBox(
          height: kChatsPinnedSearchCardHeight,
          child: child,
        ),
      ),
    );
  }
}

class _PinnedSearchCard extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String title;
  final int count;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _PinnedSearchCard({
    required this.controller,
    required this.hintText,
    required this.title,
    required this.count,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerHigh,
            cs.surfaceContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          MySearchBar(
            controller: controller,
            hintText: hintText,
            onChanged: onChanged,
            onClear: onClear,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatsKeepAlive extends StatefulWidget {
  final Widget child;

  const _ChatsKeepAlive({required this.child});

  @override
  State<_ChatsKeepAlive> createState() => _ChatsKeepAliveState();
}

class _ChatsKeepAliveState extends State<_ChatsKeepAlive>
    with AutomaticKeepAliveClientMixin<_ChatsKeepAlive> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _ChatsHeaderArea extends StatelessWidget {
  const _ChatsHeaderArea();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: SizedBox(
        height: kChatsHeaderCardHeight,
        child: _PremiumChatsHeader(
          title: "Chats".tr(),
          subtitle:
          "Stay connected with friends, groups, and communities.".tr(),
        ),
      ),
    );
  }
}

class _PremiumChatsHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PremiumChatsHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
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
              Icons.forum_rounded,
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
      height: 50,
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
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          labelColor: cs.onPrimary,
          unselectedLabelColor: cs.onSurface.withValues(alpha: 0.72),
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
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

class _PinnedSimpleDelegate extends SliverPersistentHeaderDelegate {
  final double extent;
  final Widget child;

  _PinnedSimpleDelegate({
    required this.extent,
    required this.child,
  });

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
      BuildContext context,
      double shrinkOffset,
      bool overlapsContent,
      ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _PinnedSimpleDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}