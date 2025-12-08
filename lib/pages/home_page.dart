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

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
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

  File? _selectedImage;
  File? _selectedVideo;

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

  // -------------------------------
  // Create Post
  // -------------------------------
  void _openPostMessageBox() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setInnerState) => MyInputAlertBox(
            textController: messageController,
            hintText: "What's on your mind?",
            onPressedText: "Post",
            onPressed: () async {
              final message = messageController.text.trim();
              if (message.replaceAll(RegExp(r'\s+'), '').length < 2) {
                messenger?.showSnackBar(
                  const SnackBar(
                    content: Text("Your message must have at least 2 characters"),
                  ),
                );
                setInnerState(() {
                  _selectedImage = null;
                  _selectedVideo = null;
                });
                return;
              }

              try {
                await _postMessage(
                  message,
                  imageFile: _selectedImage,
                  videoFile: _selectedVideo,
                );

                messageController.clear();

                messenger?.showSnackBar(
                  const SnackBar(
                    content: Text("Post uploaded successfully!"),
                  ),
                );
              } catch (e) {
                debugPrint('Error posting home message: $e');
                messenger?.showSnackBar(
                  const SnackBar(
                    content: Text("Failed to post. Please try again."),
                  ),
                );
              }
            },
            extraWidget: Column(
              children: [
                if (_selectedImage != null)
                  Image.file(
                    _selectedImage!,
                    height: 150,
                    fit: BoxFit.cover,
                  )
                else if (_selectedVideo != null)
                  Container(
                    height: 150,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black12,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam, size: 28),
                        SizedBox(width: 8),
                        Text("Video selected"),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text("Add Image"),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (picked != null) {
                          setInnerState(() {
                            _selectedVideo = null;
                            _selectedImage = File(picked.path);
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.videocam),
                      label: const Text("Add Video"),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickVideo(
                          source: ImageSource.gallery,
                        );
                        if (picked != null) {
                          setInnerState(() {
                            _selectedImage = null;
                            _selectedVideo = File(picked.path);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _postMessage(
      String message, {
        File? imageFile,
        File? videoFile,
      }) async {
    // Show temporary post
    databaseProvider.showLoadingPost(
      message: message,
      imageFile: imageFile,
      videoFile: videoFile,
    );

    // Upload
    await databaseProvider.postMessage(
      message,
      imageFile: imageFile,
      videoFile: videoFile,
    );

    // Remove temporary tile
    databaseProvider.clearLoadingPost();

    if (!mounted) return;

    setState(() {
      _selectedImage = null;
      _selectedVideo = null;
    });
  }

  // -------------------------------
  // Build UI
  // -------------------------------
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final List<Post> forYouPosts =
    listeningProvider.allPosts.where((p) => p.communityId == null).toList();

    final List<Post> followingGlobalPosts = listeningProvider.followingPosts
        .where((p) => p.communityId == null)
        .toList();

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
      floatingActionButton: FloatingActionButton(
        onPressed: _openPostMessageBox,
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
              // optional but helps on small phones
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text("For You"),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text("Following"),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text("Communities"),
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
              child: const Center(
                child: Text("Nothing here.."),
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
      child: const Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              "Posting your content…",
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          )
        ],
      ),
    );
  }
}
