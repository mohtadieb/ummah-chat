// lib/pages/home_page.dart

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/post.dart';
import '../services/database/database_provider.dart';
import '../components/my_post_tile.dart';
import '../helper/navigate_pages.dart';
import 'create_post_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  @override
  void setState(VoidCallback fn) {
    if (!mounted) return;
    super.setState(fn);
  }

  late final DatabaseProvider databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);
  late final DatabaseProvider listeningProvider =
  Provider.of<DatabaseProvider>(context);

  final TextEditingController _messageController = TextEditingController();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    loadAllPosts();
    _loadCommunities();
  }

  Future<void> loadAllPosts() async {
    await databaseProvider.loadAllPosts();
  }

  Future<void> _loadCommunities() async {
    try {
      await databaseProvider.getAllCommunities();
    } catch (e) {
      debugPrint('Error loading communities for HomePage: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 🔁 all non-community posts
    final List<Post> forYouPosts =
    listeningProvider.posts.where((p) => p.communityId == null).toList();

    // 🔁 following posts without community
    final List<Post> followingGlobalPosts = listeningProvider.followingPosts
        .where((p) => p.communityId == null)
        .toList();

    // joined community IDs
    final joinedCommunityIds = listeningProvider.allCommunities
        .where((c) => c['is_joined'] == true)
        .map<String>((c) => c['id'] as String)
        .toSet();

    // 🔁 posts from communities the user joined
    final List<Post> communityPosts = listeningProvider.posts
        .where(
          (p) =>
      p.communityId != null &&
          joinedCommunityIds.contains(p.communityId),
    )
        .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreatePostPage(),
            ),
          );
        },
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Container(
            color: colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              labelColor: colorScheme.inversePrimary,
              unselectedLabelColor: colorScheme.primary,
              indicatorColor: colorScheme.secondary,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: [
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text("For You".tr()),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text("Following".tr()),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text("Communities".tr()),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostList(forYouPosts),
                _buildPostList(followingGlobalPosts),
                _buildPostList(communityPosts),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostList(List<Post> posts) {
    final loadingPost = listeningProvider.loadingPost;

    final list = [
      if (loadingPost != null) loadingPost,
      ...posts,
    ];

    return RefreshIndicator(
      onRefresh: () async {
        await loadAllPosts();
      },
      child: list.isEmpty
          ? LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Center(
                child: Text("Nothing here..".tr()),
              ),
            ),
          );
        },
      )
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final post = list[index];

          if (post.id == 'loading') {
            return _buildLoadingPostTile();
          }

          return MyPostTile(
            key: ValueKey(post.id),
            post: post,
            onUserTap: () => goUserPage(context, post.userId),
            onPostTap: () => goPostPage(context, post),
            scaffoldContext: context,
          );
        },
      ),
    );
  }

  Widget _buildLoadingPostTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(
            child: Text("Posting your content…".tr(),
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          )
        ],
      ),
    );
  }
}
