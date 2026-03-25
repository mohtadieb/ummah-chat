import 'package:easy_localization/easy_localization.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/my_community_tile.dart';
import '../services/database/database_provider.dart';
import 'community_posts_page.dart';

class CommunitiesPage extends StatefulWidget {
  final bool embeddedMode;
  final String embeddedSearchQuery;
  final bool embeddedCommunitiesSearching;
  final bool embeddedCommunitiesHasCompletedSearch;
  final ValueChanged<int>? onEmbeddedCountChanged;

  const CommunitiesPage({
    super.key,
    this.embeddedMode = false,
    this.embeddedSearchQuery = '',
    this.embeddedCommunitiesSearching = false,
    this.embeddedCommunitiesHasCompletedSearch = false,
    this.onEmbeddedCountChanged,
  });

  @override
  State<CommunitiesPage> createState() => _CommunitiesPageState();
}

class _CommunitiesPageState extends State<CommunitiesPage>
    with AutomaticKeepAliveClientMixin<CommunitiesPage> {
  late final DatabaseProvider _db;
  final ScrollController _standaloneScrollController = ScrollController();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _lastReportedCount;

  String get _effectiveQuery =>
      widget.embeddedMode ? widget.embeddedSearchQuery : _searchQuery;

  bool get _effectiveSearching =>
      widget.embeddedMode ? widget.embeddedCommunitiesSearching : false;

  bool get _effectiveHasCompletedSearch =>
      widget.embeddedMode ? widget.embeddedCommunitiesHasCompletedSearch : false;

  void _reportCount(int count) {
    if (!widget.embeddedMode) return;
    if (_lastReportedCount == count) return;
    _lastReportedCount = count;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onEmbeddedCountChanged?.call(count);
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _db = Provider.of<DatabaseProvider>(context, listen: false);
    _db.getAllCommunities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _standaloneScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final listeningProvider = Provider.of<DatabaseProvider>(context);
    final joinedCommunities = listeningProvider.allCommunities
        .where((c) => c['is_joined'] == true)
        .toList();

    _reportCount(joinedCommunities.length);

    final hasSearchText = _effectiveQuery.trim().isNotEmpty;
    final searchResults = listeningProvider.communitySearchResults;
    final hasSearchResults = searchResults.isNotEmpty;

    if (!widget.embeddedMode) {
      return Column(
        children: [
          Expanded(
            child: hasSearchText
                ? _buildSearchBody(
              context,
              isSearching: _effectiveSearching,
              hasSearchResults: hasSearchResults,
              hasCompletedSearch: _effectiveHasCompletedSearch,
              searchResults: searchResults,
              horizontalPadding: 16,
            )
                : joinedCommunities.isEmpty
                ? _buildSimpleState(
              context,
              icon: Icons.groups_2_outlined,
              title: "You haven't joined any communities yet".tr(),
              subtitle:
              "Explore communities above or create your own to connect with others."
                  .tr(),
            )
                : ListView.builder(
              controller: _standaloneScrollController,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.only(
                top: 2,
                bottom: MediaQuery.of(context).padding.bottom + 96,
              ),
              itemCount: joinedCommunities.length,
              itemBuilder: (context, index) {
                final community = joinedCommunities[index];
                return _buildCommunityTile(
                  context,
                  community,
                  horizontalPadding: 16,
                );
              },
            ),
          ),
        ],
      );
    }

    if (hasSearchText) {
      return Builder(
        builder: (innerContext) {
          return ExtendedVisibilityDetector(
            uniqueKey: const Key('communities_embedded_search_visible'),
            child: CustomScrollView(
              key: const PageStorageKey<String>('communities_embedded_search'),
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              slivers: [
                SliverOverlapInjector(
                  handle: ExtendedNestedScrollView
                      .sliverOverlapAbsorberHandleFor(innerContext),
                ),
                SliverToBoxAdapter(
                  child: _buildSearchBody(
                    context,
                    isSearching: _effectiveSearching,
                    hasSearchResults: hasSearchResults,
                    hasCompletedSearch: _effectiveHasCompletedSearch,
                    searchResults: searchResults,
                    horizontalPadding: 16,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    if (joinedCommunities.isEmpty) {
      return _buildEmbeddedScrollableEmptyState(
        context,
        icon: Icons.groups_2_outlined,
        title: "You haven't joined any communities yet".tr(),
        subtitle:
        "Explore communities above or create your own to connect with others."
            .tr(),
        storageKey: const PageStorageKey<String>(
          'communities_embedded_empty',
        ),
      );
    }

    return Builder(
      builder: (innerContext) {
        return ExtendedVisibilityDetector(
          uniqueKey: const Key('communities_embedded_visible'),
          child: CustomScrollView(
            key: const PageStorageKey<String>('communities_embedded'),
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              SliverOverlapInjector(
                handle: ExtendedNestedScrollView
                    .sliverOverlapAbsorberHandleFor(innerContext),
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  top: 2,
                  bottom: MediaQuery.of(context).padding.bottom + 84,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final community = joinedCommunities[index];
                      return _buildCommunityTile(
                        context,
                        community,
                        horizontalPadding: 16,
                      );
                    },
                    childCount: joinedCommunities.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBody(
      BuildContext context, {
        required bool isSearching,
        required bool hasSearchResults,
        required bool hasCompletedSearch,
        required List<dynamic> searchResults,
        required double horizontalPadding,
      }) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);

    final double availableOverlayHeight =
        mediaQuery.size.height - mediaQuery.viewInsets.bottom - 240;
    final double overlayMaxHeight =
    availableOverlayHeight > 180 ? availableOverlayHeight : 180;

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 84),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
                color: colorScheme.outlineVariant.withValues(
                  alpha: 0.5,
                ),
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
                      color: colorScheme.onSurface.withValues(
                        alpha: 0.68,
                      ),
                    ),
                  )
                      : null,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurface.withValues(
                      alpha: 0.5,
                    ),
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
                      color: colorScheme.primary.withValues(
                        alpha: 0.10,
                      ),
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
                      color: colorScheme.onSurface.withValues(
                        alpha: 0.68,
                      ),
                    ),
                  ),
                ],
              ),
            )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildCommunityTile(
      BuildContext context,
      dynamic community, {
        required double horizontalPadding,
      }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
                communityDescription: community['description'],
                communityAvatarUrl: community['avatar_url'],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmbeddedScrollableEmptyState(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required Key storageKey,
      }) {
    return Builder(
      builder: (innerContext) {
        return ExtendedVisibilityDetector(
          uniqueKey: ValueKey(storageKey.toString()),
          child: CustomScrollView(
            key: storageKey,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              SliverOverlapInjector(
                handle: ExtendedNestedScrollView
                    .sliverOverlapAbsorberHandleFor(innerContext),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                fillOverscroll: true,
                child: _buildSimpleState(
                  context,
                  icon: icon,
                  title: title,
                  subtitle: subtitle,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 84,
                ),
              ),
            ],
          ),
        );
      },
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