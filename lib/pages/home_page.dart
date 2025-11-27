import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/post.dart';
import '../services/database/database_provider.dart';
import '../components/my_input_alert_box.dart';
import '../components/my_post_tile.dart';
import '../helper/navigate_pages.dart';

/*
HOME PAGE

This is the main page of the app, it displays a list of all the posts.
*/

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // Providers
  late final DatabaseProvider databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);
  late final DatabaseProvider listeningProvider =
  Provider.of<DatabaseProvider>(context);

  // Text controllers
  final TextEditingController _messageController = TextEditingController();

  late final TabController _tabController;

  File? _selectedImage;

  @override
  void initState() {
    super.initState();

    // ➕ 3 tabs now: For You, Following, Communities
    _tabController = TabController(length: 3, vsync: this);

    // Load all posts on startup
    loadAllPosts();

    // Load communities so we know which ones the user joined
    _loadCommunities();
  }

  // Load all posts
  Future<void> loadAllPosts() async {
    await databaseProvider.loadAllPosts();
  }

  // Load communities (for membership info)
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

  // Show "create post" dialog
  void _openPostMessageBox() {
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => MyInputAlertBox(
          textController: messageController,
          hintText: "What's on your mind?",
          onPressedText: "Post",
          onPressed: () async {
            final message = messageController.text.trim();
            if (message.replaceAll(RegExp(r'\s+'), '').length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Your message must have at least 2 characters",
                  ),
                ),
              );

              // Clear selected image after invalid post
              setState(() {
                _selectedImage = null;
              });
              return;
            }

            // Post the message (with optional image)
            await _postMessage(message, imageFile: _selectedImage);

            if (!mounted) return;
            Navigator.pop(context);
          },
          extraWidget: Column(
            children: [
              // Selected image preview
              if (_selectedImage != null)
                Image.file(
                  _selectedImage!,
                  height: 150,
                  fit: BoxFit.cover,
                ),

              // Button to pick an image
              TextButton.icon(
                icon: const Icon(Icons.image),
                label: const Text("Add Image"),
                onPressed: () async {
                  final picker = ImagePicker();
                  final picked =
                  await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setState(() {
                      _selectedImage = File(picked.path);
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // User posts a message (normal/global post, not community)
  Future<void> _postMessage(String message, {File? imageFile}) async {
    // Global feed post → no communityId
    await databaseProvider.postMessage(
      message,
      imageFile: imageFile,
    );

    // Clear the selected image after posting
    setState(() {
      _selectedImage = null;
    });
  }

  // BUILD UI
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 🔎 Global posts (no communityId)
    final List<Post> forYouPosts = listeningProvider.allPosts
        .where((p) => p.communityId == null)
        .toList();

    final List<Post> followingGlobalPosts = listeningProvider.followingPosts
        .where((p) => p.communityId == null)
        .toList();

    // 🟣 Community posts from communities the user joined
    final joinedCommunityIds = listeningProvider.allCommunities
        .where((c) => c['is_joined'] == true)
        .map<String>((c) => c['id'] as String)
        .toSet();

    final List<Post> communityPosts = listeningProvider.allPosts
        .where(
          (p) =>
      p.communityId != null &&
          joinedCommunityIds.contains(p.communityId),
    )
        .toList();

    return Scaffold(
      // Floating action button (global post only)
      floatingActionButton: FloatingActionButton(
        onPressed: _openPostMessageBox,
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add),
      ),

      // Body: tabbed feed
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
              tabs: const [
                Tab(text: "For You"),
                Tab(text: "Following"),
                Tab(text: "Communities"),
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
    if (posts.isEmpty) {
      return const Center(
        child: Text("Nothing here.."),
      );
    }

    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return MyPostTile(
          post: post,
          onUserTap: () => goUserPage(context, post.userId),
          onPostTap: () => goPostPage(context, post),
          scaffoldContext: context,
        );
      },
    );
  }
}
