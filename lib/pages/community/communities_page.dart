import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/my_search_bar.dart';
import '../../components/my_card_tile.dart';
import '../../services/database/database_provider.dart';
import 'community_info_page.dart';

class CommunitiesPage extends StatefulWidget {
  @override
  _CommunitiesPageState createState() => _CommunitiesPageState();
}

class _CommunitiesPageState extends State<CommunitiesPage> {
  late final DatabaseProvider _db;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // safe because listen: false
    _db = Provider.of<DatabaseProvider>(context, listen: false);
    _db.getAllCommunities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listeningProvider = Provider.of<DatabaseProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final joinedCommunities = listeningProvider.allCommunities
        .where((c) => c['is_joined'] == true)
        .toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // Explicit, helps with keyboard + layout behaviour
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text(
          'Communities',
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔍 Rounded search bar (shared MySearchBar component)
            MySearchBar(
              controller: _searchController,
              hintText: 'Search communities',
              onChanged: (value) async {
                // Update local query and trigger communities search
                setState(() => _searchQuery = value);

                if (value.isNotEmpty) {
                  await listeningProvider.searchCommunities(value);
                } else {
                  listeningProvider.clearCommunitySearchResults();
                }
              },
              onClear: () {
                // Clear query + search results when user taps clear
                setState(() => _searchQuery = '');
                listeningProvider.clearCommunitySearchResults();
              },
            ),

            const SizedBox(height: 12),

            // 🧾 Immediate search results (floating card)
            if (_searchQuery.isNotEmpty &&
                listeningProvider.communitySearchResults.isNotEmpty)
              Flexible(
                // Flexible → this block can shrink when keyboard is open,
                // which helps prevent bottom overflow.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 260, // Maximum height cap
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
                          // subtle shadow under the dropdown
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      // 🔹 Only as tall as the content needs (up to maxHeight)
                      shrinkWrap: true,
                      // Let this list scroll if there are many results
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount:
                      listeningProvider.communitySearchResults.length,
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
                          subtitle:
                          (community['description'] ?? '')
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
                                builder: (_) => CommunityInfoPage(
                                  communityId: community['id'],
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
              const SizedBox(height: 16)
            else
              const SizedBox(height: 12),

            // ➕ Button to add community
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.group_add),
                label: const Text('Create new community'),
                style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                onPressed: () async {
                  await _showAddCommunityDialog(context, _db);
                },
              ),
            ),

            const SizedBox(height: 24),

            // ⭐ Joined communities
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Joined communities',
                        style: TextStyle(
                          fontSize: 16,
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
                  const SizedBox(height: 8),
                  Expanded(
                    child: joinedCommunities.isEmpty
                        ? Center(
                      child: Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 24.0),
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
                              "You haven't joined any communities yet",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Explore communities above or create your own to connect with others.",
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
                        : ListView.separated(
                      keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: joinedCommunities.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final community = joinedCommunities[index];

                        // 🔹 Each joined community as a MyCardTile for consistency
                        return MyCardTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CommunityInfoPage(
                                  communityId: community['id'],
                                ),
                              ),
                            );
                          },
                          child: Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.center,
                            children: [
                              // Small avatar / icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorScheme.secondary,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.groups_2,
                                  size: 22,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Texts
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      community['name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if ((community['description'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Text(
                                        community['description'],
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.primary
                                              .withOpacity(0.75),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  minimumSize: const Size(0, 0),
                                  side: BorderSide(
                                    color: colorScheme.error
                                        .withOpacity(0.9),
                                  ),
                                  foregroundColor: colorScheme.error,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(999),
                                  ),
                                ),
                                onPressed: () async {
                                  await listeningProvider
                                      .leaveCommunity(
                                    community['id'],
                                  );
                                },
                                child: const Text(
                                  'Leave',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

  Future<void> _showAddCommunityDialog(
      BuildContext context,
      DatabaseProvider db,
      ) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final countryController = TextEditingController();

    final colorScheme = Theme.of(context).colorScheme;

    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          'Create community',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final desc = descController.text.trim();
              final country = countryController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a name for your community.'),
                  ),
                );
                return;
              }

              db.addCommunityLocally({
                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                'name': name,
                'description': desc,
                'country': country,
                'created_by': db.currentUserId,
                'created_at': DateTime.now().toIso8601String(),
                'is_joined': true,
              });

              await db.createCommunity(name, desc, country);
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
