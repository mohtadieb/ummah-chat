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

  // ✅ Debounce to avoid calling DB/RPC every keystroke
  Timer? _searchDebounce;
  static const _debounceDuration = Duration(milliseconds: 350);

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
    setState(() => _searchQuery = value);

    _searchDebounce?.cancel();
    _searchDebounce = Timer(_debounceDuration, () async {
      final q = value.trim();

      if (!mounted) return;

      final provider = Provider.of<DatabaseProvider>(context, listen: false);

      if (q.isNotEmpty) {
        await provider.searchCommunities(q);
      } else {
        provider.clearCommunitySearchResults();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ⬇️ No Scaffold here; this is content-only inside ChatTabsPage.
    final listeningProvider = Provider.of<DatabaseProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final joinedCommunities = listeningProvider.allCommunities
        .where((c) => c['is_joined'] == true)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔍 Search bar
          MySearchBar(
            controller: _searchController,
            hintText: 'Search communities'.tr(),
            onChanged: (value) {
              _onCommunitySearchChanged(value);
            },
            onClear: () {
              _searchDebounce?.cancel();
              setState(() => _searchQuery = '');
              listeningProvider.clearCommunitySearchResults();
            },
          ),

          const SizedBox(height: 12),

          // 🧾 Search results dropdown
          if (_searchQuery.isNotEmpty &&
              listeningProvider.communitySearchResults.isNotEmpty)
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 260,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.secondary,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: listeningProvider.communitySearchResults.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: colorScheme.secondary),
                    itemBuilder: (context, index) {
                      final community =
                      listeningProvider.communitySearchResults[index];
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
                          // Directly open CommunityPostsPage
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommunityPostsPage(
                                communityId: community['id'],
                                communityName: community['name'] ?? '',
                                communityDescription: community['description'],
                                communityAvatarUrl: community['avatar_url'], // ✅ adjust field name
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

          if (!(_searchQuery.isNotEmpty &&
              listeningProvider.communitySearchResults.isNotEmpty))
            const SizedBox(height: 6)
          else
            const SizedBox(height: 6),

          // ⭐ Header like Friends/Groups: "Your communities" + count
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

          // Joined communities list
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
              // ✅ Disable stretch / weird independent text movement
              behavior: ScrollConfiguration.of(context)
                  .copyWith(overscroll: false),
              child: ListView.separated(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: joinedCommunities.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                            communityDescription: community['description'],
                            communityAvatarUrl: community['avatar_url'], // ✅ adjust field name
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
}
