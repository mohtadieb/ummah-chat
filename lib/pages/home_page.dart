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

  // Providers
  late final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);
  late final listeningProvider = Provider.of<DatabaseProvider>(context);

  // Text controllers
  final TextEditingController _messageController = TextEditingController();

  late final TabController _tabController;

  // on startup
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // let's load all the post
    loadAllPosts();
  }

  // load all posts
  Future<void> loadAllPosts() async {
    await databaseProvider.loadAllPosts();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  File? _selectedImage;

  // show post message dialog box
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
                const SnackBar(content: Text("Your message must have at least 2 characters")),
              );

              // 🆕 Clear the selected image after invalid post
              setState(() {
                _selectedImage = null;
              });
              return;
            }

            // Post the message (with optional image)
            await _postMessage(message, imageFile: _selectedImage);

            Navigator.pop(context);
          },
          extraWidget: Column(
            children: [
              // 🆕 Display selected image preview
              if (_selectedImage != null)
                Image.file(_selectedImage!, height: 150, fit: BoxFit.cover),

              // 🆕 Button to pick an image
              TextButton.icon(
                icon: const Icon(Icons.image),
                label: const Text("Add Image"),
                onPressed: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery);
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


  // user wants to post a message
  Future<void> _postMessage(String message, {File? imageFile}) async {
    // Forward both message and optional image to your database provider
    await databaseProvider.postMessage(message, imageFile: imageFile);

    // 🆕 Clear the selected image after posting
    setState(() {
      _selectedImage = null;
    });
  }

  // BUILD UI
  @override
  Widget build(BuildContext context) {
    // SCAFFOLD
    return Scaffold(

      // Floating action button
      floatingActionButton: FloatingActionButton(
        onPressed: _openPostMessageBox,
        child: const Icon(Icons.add),
        backgroundColor: const Color(0xFF0D6746),
      ),

      // Body: List of all posts
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              labelColor: Theme.of(context).colorScheme.inversePrimary,
              unselectedLabelColor: Theme.of(context).colorScheme.primary,
              indicatorColor: Theme.of(context).colorScheme.secondary,
              tabs: const [
                Tab(text: "For You"),
                Tab(text: "Following"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostList(listeningProvider.allPosts),
                _buildPostList(listeningProvider.followingPosts),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostList(List<Post> posts) {
    // if it's empty
    return (posts.isEmpty)
        ?
    // return Nothing here...
    const Center(child: Text("Nothing here.."))
        :
     // else, return listview of posts
     ListView.builder(
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