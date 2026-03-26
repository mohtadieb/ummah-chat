import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/my_search_bar.dart';
import '../components/my_community_tile.dart';
import '../services/database/database_provider.dart';
import 'community_posts_page.dart';

const double kCommunitiesPinnedSearchHeight = 126.0;
const double kCommunitiesPinnedSearchCardHeight = 120.0;

class CommunitiesPage extends StatefulWidget {
  final bool embeddedMode;

  const CommunitiesPage({
    super.key,
    this.embeddedMode = false,
  });

  @override
  State<CommunitiesPage> createState() => _CommunitiesPageState();
}

class _CommunitiesPageState extends State<CommunitiesPage>
    with AutomaticKeepAliveClientMixin<CommunitiesPage> {
  late final DatabaseProvider _db;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Timer? _searchDebounce;
  static const _debounceDuration = Duration(milliseconds: 350);

  bool _isSearching = false;
  bool _hasCompletedSearch = false;

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
    _searchDebounce?.cancel();
    _searchController.dispose();
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

    final bool showingSearchState =
        hasSearchText || _isSearching || _hasCompletedSearch;

    final String cardTitle = showingSearchState
        ? 'All communities'.tr()
        : 'Your communities'.tr();

    final int? cardCount = showingSearchState ? null : joinedCommunities.length;

    if (!widget.embeddedMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            _buildTopSection(
              context,
              title: cardTitle,
              count: cardCount,
            ),
            Expanded(
              child: hasSearchText
                  ? _buildStandaloneSearchResultsBody(
                context,
                searchResults: searchResults,
                hasSearchResults: hasSearchResults,
                isSearching: _isSearching,
                hasCompletedSearch: _hasCompletedSearch,
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
                  : ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(overscroll: false),
                child: ListView.builder(
                  key: const PageStorageKey<String>(
                    'communities_normal_list',
                  ),
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(top: 0, bottom: 96),
                  itemCount: joinedCommunities.length,
                  itemBuilder: (context, index) {
                    final community = joinedCommunities[index];
                    return MyCommunityTile(
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
                              communityName:
                              community['name'] ?? '',
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
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Builder(
      builder: (innerContext) {
        return ExtendedVisibilityDetector(
          uniqueKey: const Key('communities_embedded'),
          child: CustomScrollView(
            key: const PageStorageKey<String>('communities_embedded_scroll'),
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            slivers: [
              SliverOverlapInjector(
                handle: ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
                  innerContext,
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedBoxDelegate(
                  extent: kCommunitiesPinnedSearchHeight,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: SizedBox(
                        height: kCommunitiesPinnedSearchCardHeight,
                        child: _buildTopSection(
                          context,
                          title: cardTitle,
                          count: cardCount,
                          embedded: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ..._buildEmbeddedBodySlivers(
                context,
                joinedCommunities: joinedCommunities,
                hasSearchText: hasSearchText,
                searchResults: searchResults,
                hasSearchResults: hasSearchResults,
                isSearching: _isSearching,
                hasCompletedSearch: _hasCompletedSearch,
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 96,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildEmbeddedBodySlivers(
      BuildContext context, {
        required List<dynamic> joinedCommunities,
        required bool hasSearchText,
        required List<dynamic> searchResults,
        required bool hasSearchResults,
        required bool isSearching,
        required bool hasCompletedSearch,
      }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (hasSearchText) {
      if (isSearching) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
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
          ),
        ];
      }

      if (hasSearchResults) {
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList.separated(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final community = searchResults[index];

                return Container(
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
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
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
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
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
              },
              separatorBuilder: (context, index) => const SizedBox(height: 10),
            ),
          ),
        ];
      }

      if (hasCompletedSearch) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _buildSearchEmptyCard(context),
            ),
          ),
        ];
      }
    }

    if (joinedCommunities.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildSimpleState(
            context,
            icon: Icons.groups_2_outlined,
            title: "You haven't joined any communities yet".tr(),
            subtitle:
            "Explore communities above or create your own to connect with others."
                .tr(),
          ),
        ),
      ];
    }

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final community = joinedCommunities[index];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
          },
          childCount: joinedCommunities.length,
        ),
      ),
    ];
  }

  Widget _buildTopSection(
      BuildContext context, {
        required String title,
        required int? count,
        bool embedded = false,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MySearchBar(
            controller: _searchController,
            hintText: 'Search all communities'.tr(),
            onChanged: _onCommunitySearchChanged,
            onClear: () => _clearSearch(
              Provider.of<DatabaseProvider>(context, listen: false),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (count != null) ...[
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStandaloneSearchResultsBody(
      BuildContext context, {
        required List<dynamic> searchResults,
        required bool hasSearchResults,
        required bool isSearching,
        required bool hasCompletedSearch,
      }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isSearching) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        ),
      );
    }

    if (hasSearchResults) {
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: ListView.separated(
          key: const PageStorageKey<String>('communities_search_results_list'),
          physics: const ClampingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
          itemCount: searchResults.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final community = searchResults[index];

            return Container(
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
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
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
                    color: colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                )
                    : null,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
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
          },
        ),
      );
    }

    if (hasCompletedSearch) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        child: _buildSearchEmptyCard(context),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSearchEmptyCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 24,
      ),
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
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
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
              color: colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ],
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

class _PinnedBoxDelegate extends SliverPersistentHeaderDelegate {
  final double extent;
  final Widget child;

  _PinnedBoxDelegate({
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
    return ClipRect(child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedBoxDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}