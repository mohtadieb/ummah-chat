import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/database/database_provider.dart';
import 'communities_page.dart' as communities_page;
import 'create_community_page.dart';
import 'create_group_page.dart';
import 'friends_page.dart' as friends_page;
import 'groups_page.dart' as groups_page;
import 'search_page.dart';

const double kChatsHeaderCardHeight = 126.0;
const double kChatsHeaderOuterHeight = 148.0;
const double kChatsPinnedAreaHeight = 62.0;

class ChatTabsPage extends StatefulWidget {
  const ChatTabsPage({super.key});

  @override
  State<ChatTabsPage> createState() => _ChatTabsPageState();
}

class _ChatTabsPageState extends State<ChatTabsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  final List<double> _tabOffsets = [0, 0, 0];

  double get _currentHeaderCollapse {
    return _tabOffsets[_currentTabIndex].clamp(0.0, kChatsHeaderOuterHeight);
  }

  double get _currentHeaderVisibleHeight {
    final h = kChatsHeaderOuterHeight - _currentHeaderCollapse;
    return h.clamp(0.0, kChatsHeaderOuterHeight);
  }

  double _tabListCompensation(int index) {
    return _tabOffsets[index].clamp(0.0, kChatsHeaderOuterHeight);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (!mounted) return;
    if (_currentTabIndex == _tabController.index) return;

    setState(() {
      _currentTabIndex = _tabController.index;
    });
  }

  void _handleTabScrollOffsetChanged(int tabIndex, double offset) {
    if (!mounted) return;
    final normalized = offset < 0 ? 0.0 : offset;
    if ((_tabOffsets[tabIndex] - normalized).abs() < 0.5) return;

    setState(() {
      _tabOffsets[tabIndex] = normalized;
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visibleHeight = _currentHeaderVisibleHeight;

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
          child: Column(
            children: [
              SizedBox(
                height: visibleHeight,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: kChatsHeaderOuterHeight,
                    maxHeight: kChatsHeaderOuterHeight,
                    child: Transform.translate(
                      offset: Offset(0, -_currentHeaderCollapse),
                      child: const _ChatsHeaderArea(),
                    ),
                  ),
                ),
              ),
              Container(
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
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ChatsKeepAlive(
                      child: friends_page.FriendsPage(
                        includeMahrams: true,
                        embeddedMode: true,
                        embeddedListTopCompensation: _tabListCompensation(0),
                        onEmbeddedScrollOffsetChanged: (offset) {
                          _handleTabScrollOffsetChanged(0, offset);
                        },
                      ),
                    ),
                    _ChatsKeepAlive(
                      child: groups_page.GroupsPage(
                        embeddedMode: true,
                        embeddedListTopCompensation: _tabListCompensation(1),
                        onEmbeddedScrollOffsetChanged: (offset) {
                          _handleTabScrollOffsetChanged(1, offset);
                        },
                      ),
                    ),
                    _ChatsKeepAlive(
                      child: communities_page.CommunitiesPage(
                        embeddedMode: true,
                        embeddedListTopCompensation: _tabListCompensation(2),
                        onEmbeddedScrollOffsetChanged: (offset) {
                          _handleTabScrollOffsetChanged(2, offset);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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