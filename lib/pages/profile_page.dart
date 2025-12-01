// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';        // 🆕 audio player
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:typed_data';




import '../components/my_bio_box.dart';
import '../components/my_follow_button.dart';
import '../components/my_friend_button.dart';
import '../components/my_input_alert_box.dart';
import '../components/my_post_tile.dart';
import '../components/my_profile_stats.dart';
import '../helper/navigate_pages.dart';
import '../models/user_profile.dart';
import '../services/auth/auth_service.dart';
import '../services/database/database_provider.dart';
import 'follow_list_page.dart';
import 'friends_page.dart';
import '../models/profile_song.dart';


// Story registry (id -> StoryData with chipLabel/title/icon)
import '../models/story_registry.dart';


/*
PROFILE PAGE (Supabase Ready)
Displays user profile, bio, follow button, posts, followers/following counts,
stories progress, horizontal Friends row, and now an optional profile song.
*/

class ProfilePage extends StatefulWidget {
  final String userId;
  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Providers
  late final databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);
  late final listeningProvider = Provider.of<DatabaseProvider>(context);

  // user info
  UserProfile? user;
  String currentUserId = AuthService().getCurrentUserId();

  // Text controller for bio
  final bioTextController = TextEditingController();

  // loading..
  bool _isLoading = true;

  // isFollowing state
  bool _isFollowing = false;

  // FRIENDS state
  // "none", "pending_sent", "pending_received", "accepted", "blocked"
  String _friendStatus = 'none';

  // Completed stories (for this profile – from DB for other users)
  List<String> _completedStoryIds = [];

  // Posts dropdown state
  bool _showPosts = false;

  // Scroll controller for the profile list
  final ScrollController _scrollController = ScrollController();

  bool get _isOwnProfile => widget.userId == currentUserId;

  /// For own profile → always use provider’s live set
  /// For other users → use the list loaded from DB in loadUser()
  List<String> get _effectiveCompletedStoryIds {
    if (_isOwnProfile) {
      return listeningProvider.completedStoryIds.toList();
    }
    return _completedStoryIds;
  }

  // 🆕 PROFILE SONG – audio player
  late final AudioPlayer _audioPlayer;
  bool _isPlayingProfileSong = false;
  String? _currentSongId;

  @override
  void initState() {
    super.initState();

    debugPrint(
      '👤 ProfilePage initState | userId=${widget.userId} | stateHash=${identityHashCode(this)}',
    );

    // init audio player
    _audioPlayer = AudioPlayer();

    // listen to player state to update the play/pause icon
    _audioPlayer.playerStateStream.listen((state) {
      final isPlaying = state.playing &&
          state.processingState != ProcessingState.completed &&
          state.processingState != ProcessingState.idle;

      if (mounted) {
        setState(() {
          _isPlayingProfileSong = isPlaying;
        });
      }
    });

    loadUser();
  }

  @override
  void dispose() {
    debugPrint(
      '👤 ProfilePage dispose | userId=${widget.userId} | stateHash=${identityHashCode(this)}',
    );
    bioTextController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose(); // 🆕 stop and clean audio
    super.dispose();
  }

  // 🆕 lookup helper
  ProfileSong? _getSongById(String? id) {
    if (id == null || id.isEmpty) return null;
    try {
      return kProfileSongs.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  // 🆕 start playing a given song id (if it exists locally)
  Future<void> _startProfileSong(String songId) async {
    final song = _getSongById(songId);
    if (song == null) {
      debugPrint('⚠️ No matching song found for id=$songId');
      return;
    }

    // If already playing this song, don't restart
    if (_audioPlayer.playing && _currentSongId == songId) {
      debugPrint('🎵 Already playing songId=$songId, skipping restart.');
      return;
    }

    try {
      // 1) Check asset is loadable
      try {
        final data = await rootBundle.load(song.assetPath);
        debugPrint(
          '✅ Asset loaded: ${song.assetPath}, bytes=${data.lengthInBytes}',
        );
      } catch (e) {
        debugPrint('❌ Unable to load asset ${song.assetPath}: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Asset not found: ${song.assetPath}')),
          );
        }
        return;
      }

      // 2) Reset + ensure volume is ok
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setSpeed(1.0);

      // 3) Load into just_audio
      debugPrint('🎵 Trying to play asset with just_audio: ${song.assetPath}');
      final duration = await _audioPlayer.setAsset(song.assetPath);
      debugPrint('⏱️ Profile song duration: $duration');

      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.play();

      // 4) Extra: log position a bit to confirm it’s actually moving
      _audioPlayer.positionStream.listen((pos) {
        debugPrint('🎧 Profile song position: ${pos.inMilliseconds} ms');
      });

      if (mounted) {
        setState(() {
          _currentSongId = songId;
        });
      }
    } on PlayerException catch (e) {
      debugPrint(
        '❌ PlayerException while playing profile song: code=${e.code}, message=${e.message}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play song: ${e.message}')),
        );
      }
    } on PlayerInterruptedException catch (e) {
      debugPrint('⏸️ PlayerInterruptedException: ${e.message}');
    } catch (e, st) {
      debugPrint('❌ Unknown error playing profile song: $e\n$st');
    }
  }


  // 🆕 toggle play/pause
  Future<void> _toggleProfileSongPlayPause() async {
    final songId = user?.profileSongId ?? '';

    // If no song set, do nothing
    if (songId.isEmpty) {
      debugPrint('⚠️ No profile song id set, cannot play.');
      return;
    }

    if (_audioPlayer.playing) {
      // Currently playing -> pause
      await _audioPlayer.pause();
    } else {
      // Not playing -> (re)start this user's song from the beginning
      await _startProfileSong(songId);
    }
  }

  Future<void> stopProfileSong() async {
    debugPrint('🛑 Stopping profile song');
    try {
      await _audioPlayer.stop();
    } catch (_) {
      // ignore
    }
  }

  Future<void> playProfileSongIfAny() async {
    final songId = user?.profileSongId ?? '';
    if (songId.isEmpty) {
      debugPrint('🎵 No profile song set for this user.');
      return;
    }

    // If already playing the correct song, do nothing
    if (_audioPlayer.playing && _currentSongId == songId) {
      debugPrint('🎵 Profile song already playing.');
      return;
    }

    debugPrint('▶️ Starting profile song from MainLayout for id=$songId');
    await _startProfileSong(songId);
  }



  // 🆕 change the song from the picker
  Future<void> _setProfileSong(String songId) async {
    if (!_isOwnProfile) return;

    // 1) update in DB
    await databaseProvider.updateProfileSong(songId);

    // 2) play immediately
    await _startProfileSong(songId);

    // 3) refresh user profile so profileSongId reflects it
    await loadUser();
  }

  Future<void> loadUser() async {
    setState(() {
      _isLoading = true;
    });

    const int maxAttempts = 8;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      user = await databaseProvider.getUserProfile(widget.userId);

      if (user != null) {
        break;
      }

      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    await databaseProvider.loadUserFollowers(widget.userId);
    await databaseProvider.loadUserFollowing(widget.userId);

    _isFollowing = databaseProvider.isFollowing(widget.userId);
    _friendStatus = await databaseProvider.getFriendStatus(widget.userId);
    _completedStoryIds =
    await databaseProvider.getCompletedStoriesForUser(widget.userId);

    // 🔊 PROFILE SONG HANDLING
    final songId = user!.profileSongId ?? '';

    if (songId.isNotEmpty) {
      _currentSongId = songId;

      if (_isOwnProfile) {
        // own profile: don't auto-play, just make sure nothing is playing
        await _audioPlayer.stop();
        debugPrint(
          '🎵 Own profile has songId=$songId, not auto-playing.',
        );
      } else {
        // other user's profile: AUTO-PLAY, but don't block loadUser()
        debugPrint(
          '🎵 Scheduling autoplay for other user profile songId=$songId',
        );

        // fire-and-forget so UI isn't stuck in loading state
        Future.microtask(() async {
          // extra mounted check in case user navigated away quickly
          if (!mounted) return;
          await _startProfileSong(songId);
        });
      }
    } else {
      // no song set
      await _audioPlayer.stop();
      _currentSongId = null;
      debugPrint('🎵 No profile song set for this profile.');
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }


  void _showEditBioBox() {
    bioTextController.text = user?.bio ?? '';
    showDialog(
      context: context,
      builder: (context) => MyInputAlertBox(
        textController: bioTextController,
        hintText: "Edit bio...",
        onPressed: _saveBio,
        onPressedText: "Save",
      ),
    );
  }

  Future<void> _saveBio() async {
    setState(() => _isLoading = true);
    await databaseProvider.updateBio(bioTextController.text);
    await loadUser();
    setState(() => _isLoading = false);
  }

  Widget _buildAboutMeSection() {
    if (user == null) return const SizedBox();

    final from = user!.fromLocation;
    final langs = user!.languages;
    final ints = user!.interests;

    final chips = <Widget>[];

    if (from != null && from.isNotEmpty) {
      chips.add(_chip("From: $from"));
    }

    if (langs.isNotEmpty) {
      chips.addAll(langs.map((l) => _chip(l)));
    }

    if (ints.isNotEmpty) {
      chips.addAll(ints.map((i) => _chip(i)));
    }

    if (chips.isEmpty) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      ),
    );
  }

  Widget _chip(String label) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colorScheme.primary.withValues(alpha: 0.08),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }


  void _editAboutMe() {
    // prefill fields with current values
    final fromCtrl = TextEditingController(text: user?.fromLocation ?? '');
    final langsCtrl = TextEditingController(
      text: (user?.languages ?? []).join(', '),
    );
    final intsCtrl = TextEditingController(
      text: (user?.interests ?? []).join(', '),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "About me",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: fromCtrl,
                decoration: const InputDecoration(
                  labelText: "From (city / country)",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: langsCtrl,
                decoration: const InputDecoration(
                  labelText: "Languages (comma separated)",
                  hintText: "Dutch, Arabic, English",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: intsCtrl,
                decoration: const InputDecoration(
                  labelText: "Interests (comma separated)",
                  hintText: "Qur’an, Psychology, Travel",
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final fromLocation = fromCtrl.text.trim().isEmpty
                        ? null
                        : fromCtrl.text.trim();

                    final languages = langsCtrl.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();

                    final interests = intsCtrl.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();

                    await databaseProvider.updateAboutMe(
                      fromLocation: fromLocation,
                      languages: languages,
                      interests: interests,
                    );

                    await loadUser();

                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditAboutMeButton() {
    if (!_isOwnProfile) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _editAboutMe,
          child: const Text(
            "Edit about me",
            style: TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }



  Future<void> _toggleFollow() async {
    if (_isFollowing) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Unfollow"),
          content: const Text("Are you sure you want to unfollow?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Yes"),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await databaseProvider.unfollowUser(widget.userId);
        databaseProvider.loadFollowingPosts();
        setState(() => _isFollowing = false);
      }
    } else {
      await databaseProvider.followUser(widget.userId);
      databaseProvider.loadFollowingPosts();
      setState(() => _isFollowing = true);
    }
  }

  Future<void> _pickProfilePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    final bytes = await file.readAsBytes();

    await databaseProvider.updateProfilePhoto(bytes);
    await loadUser();
  }


  Future<void> _removeProfilePhoto() async {
    await databaseProvider.updateProfilePhoto(Uint8List(0)); // or add a DB method to set null
    await loadUser();
  }



  Future<void> _addFriendFromProfile() async {
    await databaseProvider.sendFriendRequest(widget.userId);
    setState(() => _friendStatus = 'pending_sent');
  }

  Future<void> _cancelFriendFromProfile() async {
    await databaseProvider
        .cancelFriendRequest(widget.userId);
    setState(() => _friendStatus = 'none');
  }

  Future<void> _acceptFriendFromProfile() async {
    await databaseProvider.acceptFriendRequest(widget.userId);
    final updated = await databaseProvider.getFriendStatus(widget.userId);
    setState(() {
      _friendStatus = updated;
    });
  }

  Future<void> _declineFriendFromProfile() async {
    await databaseProvider.declineFriendRequest(widget.userId);
    final updated = await databaseProvider.getFriendStatus(widget.userId);
    setState(() {
      _friendStatus = updated;
    });
  }

  /// FRIENDS SECTION – horizontal row of friends
  Widget _buildFriendsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOwn = _isOwnProfile;

    void _openFriendsFullScreen() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            appBar: AppBar(
              title: const Text("Friends"),
              centerTitle: true,
              backgroundColor: Theme.of(ctx).colorScheme.surface,
              foregroundColor: Theme.of(ctx).colorScheme.primary,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
            body: const FriendsPage(),
          ),
        ),
      );
    }

    final friendsStream = isOwn
        ? databaseProvider.friendsStream()
        : databaseProvider.friendsStreamForUser(widget.userId);

    return Padding(
      padding: const EdgeInsets.only(top: 18.0, left: 20, right: 20),
      child: StreamBuilder<List<UserProfile>>(
        stream: friendsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const SizedBox.shrink();
          }

          if (!snapshot.hasData) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Friends",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
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
                        '-',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    if (isOwn) ...[
                      const Spacer(),
                      TextButton(
                        onPressed: _openFriendsFullScreen,
                        child: Text(
                          "View all",
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 72,
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          final allFriends =
          (snapshot.data ?? []).where((u) => u.id != currentUserId).toList();

          final totalFriends = allFriends.length;

          if (totalFriends == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Friends",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
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
                        '0',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    if (isOwn) ...[
                      const Spacer(),
                      TextButton(
                        onPressed: _openFriendsFullScreen,
                        child: Text(
                          "View all",
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isOwn
                      ? "Add friends to see them here."
                      : "No friends to show yet.",
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.primary.withOpacity(0.7),
                  ),
                ),
              ],
            );
          }

          final visibleFriends = allFriends.take(12).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "Friends",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
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
                      '$totalFriends',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  if (isOwn) ...[
                    const Spacer(),
                    TextButton(
                      onPressed: _openFriendsFullScreen,
                      child: Text(
                        "View all",
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: visibleFriends.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final friend = visibleFriends[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfilePage(userId: friend.id),
                          ),
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: colorScheme.secondary,
                                backgroundImage:
                                friend.profilePhotoUrl.isNotEmpty
                                    ? NetworkImage(
                                  friend.profilePhotoUrl,
                                )
                                    : null,
                                child: friend.profilePhotoUrl.isEmpty
                                    ? Icon(
                                  Icons.person,
                                  color: colorScheme.primary,
                                  size: 26,
                                )
                                    : null,
                              ),
                              if (friend.isOnline)
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.green,
                                      border: Border.all(
                                        color: colorScheme.surface,
                                        width: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 70,
                            child: Text(
                              friend.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🆕 PROFILE SONG SECTION
  Widget _buildProfileSongSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final songId = user?.profileSongId ?? '';
    final song = _getSongById(songId);
    final hasSong = song != null;

    void _openSongPicker() {
      if (!_isOwnProfile) return;

      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (ctx) {
          final currentId = user?.profileSongId ?? '';
          return ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: kProfileSongs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (ctx, index) {
              final s = kProfileSongs[index];
              final isSelected = s.id == currentId;

              return ListTile(
                leading: const Icon(Icons.music_note),
                title: Text(s.title),
                subtitle: Text(s.artist),
                trailing: isSelected
                    ? Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                )
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _setProfileSong(s.id);
                },
              );
            },
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.music_note_rounded, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Profile song",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasSong
                        ? '${song!.title} • ${song.artist}'
                        : (_isOwnProfile
                        ? "Choose a song that plays on your profile"
                        : "No profile song set"),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                      colorScheme.primary.withValues(alpha: hasSong ? 0.75 : 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (hasSong)
              IconButton(
                onPressed: _toggleProfileSongPlayPause,
                icon: Icon(
                  _isPlayingProfileSong
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  size: 26,
                  color: colorScheme.primary,
                ),
              ),
            if (_isOwnProfile)
              TextButton(
                onPressed: _openSongPicker,
                child: Text(
                  hasSong ? "Change" : "Choose",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Choose from gallery"),
              onTap: () async {
                Navigator.pop(context);
                await _pickProfilePhoto();
              },
            ),
            if (user!.profilePhotoUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text("Remove profile picture"),
                onTap: () async {
                  Navigator.pop(context);
                  await _removeProfilePhoto();
                },
              ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final allUserPosts = listeningProvider.getUserPosts(widget.userId);
    final postCount = allUserPosts.length;

    final followerCount = listeningProvider.getFollowerCount(widget.userId);
    final followingCount = listeningProvider.getFollowingCount(widget.userId);

    _isFollowing = listeningProvider.isFollowing(widget.userId);

    // Stories progress values
    final totalStories = allStoriesById.length;
    final effectiveCompletedIds = _effectiveCompletedStoryIds;

    Widget bodyChild;
    if (_isLoading) {
      bodyChild = const Center(child: CircularProgressIndicator());
    } else if (user == null) {
      bodyChild = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Profile not found yet.\nPlease try again in a moment.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    } else {
      bodyChild = ListView(
        controller: _scrollController,
        children: [
          const SizedBox(height: 18),

          // NAME + USERNAME
          Center(
            child: Column(
              children: [
                Text(
                  user!.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user!.username}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // PROFILE PICTURE (with edit button for own profile)
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Profile image or placeholder
                GestureDetector(
                  onTap: _isOwnProfile ? _pickProfilePhoto : null,
                  child: user!.profilePhotoUrl.isNotEmpty
                      ? CircleAvatar(
                    radius: 56,
                    backgroundImage: NetworkImage(user!.profilePhotoUrl),
                  )
                      : Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    child: Icon(
                      Icons.person,
                      size: 70,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

                // Small edit icon overlay (only on own profile)
                if (_isOwnProfile)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _pickProfilePhoto,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),


          const SizedBox(height: 28),

          // Stats
          MyProfileStats(
            postCount: allUserPosts.length,
            followerCount: followerCount,
            followingCount: followingCount,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FollowListPage(userId: widget.userId),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Follow / Friend buttons
          if (user!.id != currentUserId)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: MyFollowButton(
                      onPressed: _toggleFollow,
                      isFollowing: _isFollowing,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MyFriendButton(
                      friendStatus: _friendStatus,
                      onAddFriend: () async {
                        await _addFriendFromProfile();
                      },
                      onCancelRequest: () async {
                        await _cancelFriendFromProfile();
                      },
                      onAcceptRequest: () async {
                        await _acceptFriendFromProfile();
                      },
                      onDeclineRequest: () async {
                        await _declineFriendFromProfile();
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Bio header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Bio",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (user!.id == currentUserId)
                  GestureDetector(
                    onTap: _showEditBioBox,
                    child: Icon(
                      Icons.edit,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 7),

          MyBioBox(text: user!.bio),

          const SizedBox(height: 7),

          // 🔹 "About me" edit + chips
          _buildEditAboutMeButton(),
          _buildAboutMeSection(),

          // 🆕 Profile song section
          _buildProfileSongSection(context),

          // 🧑‍🤝‍🧑 FRIENDS ROW
          _buildFriendsSection(context),

          // Stories progress + medals with names
          if (totalStories > 0) ...[
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Text(
                "Stories completed: ${effectiveCompletedIds.length} / $totalStories",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),

            if (effectiveCompletedIds.isNotEmpty) ...[
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: effectiveCompletedIds.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  itemBuilder: (context, index) {
                    final id = effectiveCompletedIds[index];
                    final story = allStoriesById[id];
                    if (story == null) {
                      return const SizedBox.shrink();
                    }

                    final rawLabel = story.chipLabel;
                    final lower = rawLabel.toLowerCase();
                    final displayName = lower.startsWith('prophet ')
                        ? rawLabel.substring('Prophet '.length)
                        : rawLabel;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF0F8254),
                                Color(0xFF0B6841),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26.withOpacity(0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              story.icon,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          displayName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              if (effectiveCompletedIds.length == totalStories) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F8254).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF0F8254).withOpacity(0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 18,
                          color: Color(0xFF0F8254),
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Prophets Stories Level 1 completed",
                          style: TextStyle(
                            color: Color(0xFF0F8254),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],

          const SizedBox(height: 12),

          // Posts section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                final willShow = !_showPosts;

                setState(() {
                  _showPosts = willShow;
                });

                if (willShow) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_scrollController.hasClients) return;
                    final current = _scrollController.offset;
                    _scrollController.animateTo(
                      current + 140,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOut,
                    );
                  });
                }
              },
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        Icons.article_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Posts",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            postCount == 0
                                ? "Tap to view posts"
                                : "$postCount post${postCount == 1 ? '' : 's'} • tap to view",
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.08),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showPosts ? "Hide" : "Show",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showPosts
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          if (_showPosts)
            (allUserPosts.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Text(
                  "No posts yet..",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            )
                : ListView.builder(
              itemCount: allUserPosts.length,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final post = allUserPosts[index];
                return MyPostTile(
                  post: post,
                  onPostTap: () => goPostPage(context, post),
                  scaffoldContext: context,
                );
              },
            )),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: widget.userId != currentUserId
          ? AppBar(
        foregroundColor: Theme.of(context).colorScheme.primary,
      )
          : null,
      body: bodyChild,
    );
  }
}
