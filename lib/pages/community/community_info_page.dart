import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/my_user_tile.dart';
import '../../models/user.dart';
import '../../services/database/database_provider.dart';

class CommunityInfoPage extends StatefulWidget {
  final String communityId;

  const CommunityInfoPage({super.key, required this.communityId});

  @override
  State<CommunityInfoPage> createState() => _CommunityInfoPageState();
}

class _CommunityInfoPageState extends State<CommunityInfoPage> {
  late final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);
  // late final listeningProvider = Provider.of<DatabaseProvider>(context);

  Map<String, dynamic>? _community;
  List<Map<String, dynamic>> _members = [];
  bool _isJoined = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCommunityData();
  }

  Future<void> _loadCommunityData() async {
    setState(() => _loading = true);

    // Load community info
    final community = databaseProvider.allCommunities.firstWhere(
          (c) => c['id'] == widget.communityId,
      orElse: () => {},
    );

    // Load full member profiles
    final members = await databaseProvider.getCommunityMemberProfiles(widget.communityId);

    // Check if current user is a member
    final isJoined = await databaseProvider.isMember(widget.communityId);

    setState(() {
      _community = community;
      _members = members;
      _isJoined = isJoined;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_community == null || _community!.isEmpty) {
      return Scaffold(
        backgroundColor: theme.surface,
        body: Center(
          child: Text("Community not found", style: TextStyle(color: theme.primary)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_community!['name'] ?? "Community", style: TextStyle(color: theme.inversePrimary)),
        backgroundColor: theme.surface,
        iconTheme: IconThemeData(color: theme.primary),
      ),
      backgroundColor: theme.surface,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Community Description & Country
            Text(
              _community!['description'] ?? "No description",
              style: TextStyle(color: theme.primary, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              "Country: ${_community!['country'] ?? 'Unknown'}",
              style: TextStyle(color: theme.primary, fontSize: 14),
            ),
            const SizedBox(height: 12),

            // Join/Leave Button
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.secondary,
                  foregroundColor: theme.inversePrimary,
                ),
                onPressed: () async {
                  if (_isJoined) {
                    await databaseProvider.leaveCommunity(widget.communityId);
                  } else {
                    await databaseProvider.joinCommunity(widget.communityId);
                  }
                  await _loadCommunityData();
                },
                child: Text(_isJoined ? 'Leave Community' : 'Join Community'),
              ),
            ),
            const SizedBox(height: 16),

            // Members Header
            Text(
              "Members (${_members.length}):",
              style: TextStyle(color: theme.inversePrimary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            // Member List
            Expanded(
              child: _members.isEmpty
                  ? Center(
                child: Text(
                  "No members yet.",
                  style: TextStyle(color: theme.primary),
                ),
              )
                  : ListView.builder(
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final member = _members[index];

                  // Safely parse createdAt
                  final createdAt = member['created_at'] != null
                      ? DateTime.tryParse(member['created_at'].toString()) ?? DateTime.now()
                      : DateTime.now();

                  // Map to UserProfile
                  final user = UserProfile(
                    id: member['id'] ?? '',
                    name: member['name'] ?? 'Unknown', // Corrected column
                    username: member['username'] ?? 'user',
                    email: member['email'] ?? '',
                    bio: member['bio'] ?? '',
                    profilePhotoUrl: member['profile_photo_url'] ?? '',
                    createdAt: createdAt,
                  );

                  return MyUserTile(user: user);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
