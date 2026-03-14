import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/my_search_bar.dart';
import '../components/my_community_tile.dart';
import '../services/database/database_provider.dart';
import 'community_posts_page.dart';

class CommunitiesPage extends StatefulWidget {
  const CommunitiesPage({super.key});

  @override
  _CommunitiesPageState createState() => _CommunitiesPageState();
}

class _CommunitiesPageState extends State<CommunitiesPage> {
  late final DatabaseProvider _db;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Timer? _searchDebounce;
  static const _debounceDuration = Duration(milliseconds: 350);

  bool _isSearching = false;

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

    setState(() {
      _searchQuery = value;
      _isSearching = trimmed.isNotEmpty;
    });

    _searchDebounce?.cancel();

    _searchDebounce = Timer(_debounceDuration, () async {
      if (!mounted) return;

      final provider = Provider.of<DatabaseProvider>(context, listen: false);

      if (trimmed.isNotEmpty) {
        await provider.searchCommunities(trimmed);

        if (!mounted) return;
        setState(() => _isSearching = false);
      } else {
        provider.clearCommunitySearchResults();

        if (!mounted) return;
        setState(() => _isSearching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final listeningProvider = Provider.of<DatabaseProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);

    final joinedCommunities = listeningProvider.allCommunities
        .where((c) => c['is_joined'] == true)
        .toList();

    final hasSearchText = _searchQuery.trim().isNotEmpty;
    final hasSearchResults =
        listeningProvider.communitySearchResults.isNotEmpty;

    const double searchBarAndTopSpacing = 68;
    const double overlayGapBelowSearch = 12;

    final double availableOverlayHeight =
        mediaQuery.size.height - mediaQuery.viewInsets.bottom - 220;

    final double overlayMaxHeight =
    availableOverlayHeight > 180 ? availableOverlayHeight : 180;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MySearchBar(
                controller: _searchController,
                hintText: 'Search communities'.tr(),
                onChanged: (value) {
                  _onCommunitySearchChanged(value);
                },
                onClear: () {
                  _searchDebounce?.cancel();
                  setState(() {
                    _searchQuery = '';
                    _isSearching = false;
                  });
                  listeningProvider.clearCommunitySearchResults();
                },
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Text(
                      'Your communities'.tr(),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (joinedCommunities.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${joinedCommunities.length}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: joinedCommunities.isEmpty
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_2_outlined,
                          size: 48,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "You haven't joined any communities yet".tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Explore communities above or create your own to connect with others."
                              .tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(overscroll: false),
                  child: ListView.separated(
                    physics: const ClampingScrollPhysics(),
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(top: 2),
                    itemCount: joinedCommunities.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
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
                  ),
                ),
              ),
            ],
          ),

          if (hasSearchText)
            Positioned(
              top: searchBarAndTopSpacing,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: overlayMaxHeight,
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(top: overlayGapBelowSearch),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.secondary,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _isSearching
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
                      padding:
                      const EdgeInsets.symmetric(vertical: 4),
                      itemCount: listeningProvider
                          .communitySearchResults.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: colorScheme.secondary,
                      ),
                      itemBuilder: (context, index) {
                        final community = listeningProvider
                            .communitySearchResults[index];

                        return ListTile(
                          dense: true,
                          title: Text(
                            community['name'],
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: colorScheme.primary,
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
                              color: colorScheme.primary,
                            ),
                          )
                              : null,
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
                    )
                        : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 42,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No communities found'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try a different search term.'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}