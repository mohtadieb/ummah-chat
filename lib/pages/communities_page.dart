import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/my_search_bar.dart';
import '../components/my_community_tile.dart';
import '../services/database/database_provider.dart';
import 'community_posts_page.dart';

const double kChatsHeaderOuterHeight = 148.0;

class CommunitiesPage extends StatefulWidget {
  final bool embeddedMode;
  final ValueChanged<double>? onEmbeddedScrollOffsetChanged;
  final double embeddedListTopCompensation;
  final bool isActiveTab;
  final int tabActivationTick;

  const CommunitiesPage({
    super.key,
    this.embeddedMode = false,
    this.onEmbeddedScrollOffsetChanged,
    this.embeddedListTopCompensation = 0,
    this.isActiveTab = false,
    this.tabActivationTick = 0,
  });

  @override
  State<CommunitiesPage> createState() => _CommunitiesPageState();
}

class _CommunitiesPageState extends State<CommunitiesPage>
    with AutomaticKeepAliveClientMixin<CommunitiesPage> {
  late final DatabaseProvider _db;
  final ScrollController _listController = ScrollController();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Timer? _searchDebounce;
  static const _debounceDuration = Duration(milliseconds: 350);

  bool _isSearching = false;
  bool _hasCompletedSearch = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant CommunitiesPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final becameActive =
        widget.embeddedMode &&
            widget.isActiveTab &&
            (!oldWidget.isActiveTab ||
                oldWidget.tabActivationTick != widget.tabActivationTick);

    if (becameActive) {
      _syncToHeaderIfNeeded();
    }
  }

  void _syncToHeaderIfNeeded() {
    if (!widget.embeddedMode || !widget.isActiveTab) return;
    if (!_listController.hasClients) return;

    final minOffset = widget.embeddedListTopCompensation;
    final current = _listController.offset;
    final max = _listController.position.maxScrollExtent;
    final target = minOffset.clamp(0.0, max);

    if (current < target) {
      _listController.jumpTo(target);
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.embeddedMode || !widget.isActiveTab) return false;
    if (notification.depth != 0) return false;
    widget.onEmbeddedScrollOffsetChanged?.call(notification.metrics.pixels);
    return false;
  }

  @override
  void initState() {
    super.initState();
    _db = Provider.of<DatabaseProvider>(context, listen: false);
    _db.getAllCommunities();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _onCommunitySearchChanged(String value) {
    final trimmed = value.trim();

    _searchDebounce?.cancel();

    setState(() {
      _searchQuery = value;
      _isSearching = trimmed.isNotEmpty;
      _hasCompletedSearch = false;
    });

    _searchDebounce = Timer(_debounceDuration, () async {
      if (!mounted) return;

      final provider = Provider.of<DatabaseProvider>(context, listen: false);

      if (trimmed.isNotEmpty) {
        await provider.searchCommunities(trimmed);

        if (!mounted) return;
        setState(() {
          _isSearching = false;
          _hasCompletedSearch = true;
        });
      } else {
        provider.clearCommunitySearchResults();

        if (!mounted) return;
        setState(() {
          _isSearching = false;
          _hasCompletedSearch = false;
        });
      }
    });
  }

  void _clearSearch(DatabaseProvider provider) {
    _searchDebounce?.cancel();
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _isSearching = false;
      _hasCompletedSearch = false;
    });
    provider.clearCommunitySearchResults();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final listeningProvider = Provider.of<DatabaseProvider>(context);
    final joinedCommunities = listeningProvider.allCommunities
        .where((c) => c['is_joined'] == true)
        .toList();

    final hasSearchText = _searchQuery.trim().isNotEmpty;
    final searchResults = listeningProvider.communitySearchResults;
    final hasSearchResults = searchResults.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: widget.embeddedMode
              ? const EdgeInsets.fromLTRB(16, 8, 16, 6)
              : const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _buildTopSection(
            context,
            title: 'Your communities'.tr(),
            count: joinedCommunities.length,
          ),
        ),
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              joinedCommunities.isEmpty
                  ? _buildSimpleState(
                context,
                icon: Icons.groups_2_outlined,
                title: "You haven't joined any communities yet".tr(),
                subtitle:
                "Explore communities above or create your own to connect with others."
                    .tr(),
              )
                  : NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(overscroll: false),
                  child: ListView.builder(
                    controller: _listController,
                    key: PageStorageKey<String>(
                      widget.embeddedMode
                          ? 'communities_embedded_list'
                          : 'communities_normal_list',
                    ),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      top: widget.embeddedMode
                          ? widget.embeddedListTopCompensation
                          : 0,
                      bottom: widget.embeddedMode
                          ? MediaQuery.of(context).padding.bottom +
                          72 +
                          kChatsHeaderOuterHeight
                          : MediaQuery.of(context).padding.bottom + 96,
                    ),
                    itemCount: joinedCommunities.length,
                    itemBuilder: (context, index) {
                      final community = joinedCommunities[index];

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.embeddedMode ? 16 : 0,
                        ),
                        child: MyCommunityTile(
                          name: community['name'] ?? '',
                          description: community['description'],
                          country: community['country'],
                          avatarUrl: community['avatar_url'],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CommunityPostsPage(
                                  communityId: community['id'],
                                  communityName: community['name'] ?? '',
                                  communityDescription:
                                  community['description'],
                                  communityAvatarUrl:
                                  community['avatar_url'],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (hasSearchText)
                Positioned(
                  top: 0,
                  left: widget.embeddedMode ? 16 : 0,
                  right: widget.embeddedMode ? 16 : 0,
                  child: _buildSearchDropdown(
                    context,
                    isSearching: _isSearching,
                    hasSearchResults: hasSearchResults,
                    hasCompletedSearch: _hasCompletedSearch,
                    searchResults: searchResults,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopSection(
      BuildContext context, {
        required String title,
        required int count,
      }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHigh,
            colorScheme.surfaceContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
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
            controller: _searchController,
            hintText: 'Search communities'.tr(),
            onChanged: _onCommunitySearchChanged,
            onClear: () => _clearSearch(
              Provider.of<DatabaseProvider>(context, listen: false),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
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
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchDropdown(
      BuildContext context, {
        required bool isSearching,
        required bool hasSearchResults,
        required bool hasCompletedSearch,
        required List<dynamic> searchResults,
      }) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);

    final double availableOverlayHeight =
        mediaQuery.size.height - mediaQuery.viewInsets.bottom - 240;
    final double overlayMaxHeight =
    availableOverlayHeight > 180 ? availableOverlayHeight : 180;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: overlayMaxHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surfaceContainerHigh,
                colorScheme.surfaceContainer,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: isSearching
              ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
            ),
          )
              : hasSearchResults
              ? ListView.separated(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: searchResults.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: colorScheme.outlineVariant
                  .withValues(alpha: 0.5),
            ),
            itemBuilder: (context, index) {
              final community = searchResults[index];

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                leading: _buildSearchAvatar(
                  context,
                  community['name'] ?? '',
                  community['avatar_url'],
                ),
                title: Text(
                  community['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: (community['description'] ?? '')
                    .toString()
                    .isNotEmpty
                    ? Text(
                  community['description'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface
                        .withValues(alpha: 0.68),
                  ),
                )
                    : null,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurface
                      .withValues(alpha: 0.5),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityPostsPage(
                        communityId: community['id'],
                        communityName: community['name'] ?? '',
                        communityDescription:
                        community['description'],
                        communityAvatarUrl:
                        community['avatar_url'],
                      ),
                    ),
                  );
                },
              );
            },
          )
              : hasCompletedSearch
              ? Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: colorScheme.primary
                        .withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.search_off_rounded,
                    size: 28,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No communities found'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try a different search term.'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface
                        .withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildSimpleState(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
      }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: colorScheme.onSurface.withValues(alpha: 0.70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAvatar(
      BuildContext context,
      String name,
      String? avatarUrl,
      ) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = (avatarUrl ?? '').trim();

    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(url),
      );
    }

    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';

    return CircleAvatar(
      radius: 20,
      backgroundColor: colorScheme.primary.withValues(alpha: 0.10),
      child: Text(
        initial,
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}