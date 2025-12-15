// lib/pages/profile_page.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart'; // 🆕 audio player
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../services/navigation/bottom_nav_provider.dart';

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

/// Internal helper to keep track of Muhammad (ﷺ) parts and their number.
class _MuhammadPartInfo {
  final String id;
  final int? partNo;

  _MuhammadPartInfo({required this.id, this.partNo});
}

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
  late final databaseProvider = Provider.of<DatabaseProvider>(
    context,
    listen: false,
  );
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
      final isPlaying =
          state.playing &&
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
            SnackBar(content: Text('Asset not found: ${song.assetPath}'.tr())),
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

    // 👉 Immediately update local state so UI changes right away
    if (mounted) {
      setState(() {
        _currentSongId =
            songId; // ok now because _startProfileSong always reloads
        if (user != null) {
          user = user!.copyWith(profileSongId: songId);
        }
      });
    }

    // 1) update in DB
    await databaseProvider.updateProfileSong(songId);

    // 2) play immediately (this will stop old song + load new one)
    await _startProfileSong(songId);
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
    _completedStoryIds = await databaseProvider.getCompletedStoriesForUser(
      widget.userId,
    );

    // 🔊 PROFILE SONG HANDLING
    final songId = user!.profileSongId ?? '';

    if (songId.isNotEmpty) {
      _currentSongId = songId;

      if (_isOwnProfile) {
        // 🔧 Own profile: no auto-play
        debugPrint(
          '🎵 Own profile has songId=$songId (no auto-play, no forced stop).',
        );
      } else {
        // other user's profile: AUTO-PLAY, but don't block loadUser()
        debugPrint(
          '🎵 Scheduling autoplay for other user profile songId=$songId',
        );

        Future.microtask(() async {
          if (!mounted) return;
          await _startProfileSong(songId);
        });
      }
    } else {
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
        hintText: "Edit bio...".tr(),
        onPressed: _saveBio,
        onPressedText: "Save".tr(),
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

    final country = user!.country;
    final city = user!.city;
    final langs = user!.languages;
    final ints = user!.interests;

    final chips = <Widget>[];

    // Country first (always set after CompleteProfilePage)
    if (country.isNotEmpty) {
      chips.add(_chip(country));
    }

    // Then city
    if (city != null && city.isNotEmpty) {
      chips.add(_chip(city));
    }

    // Then languages
    if (langs.isNotEmpty) {
      chips.addAll(langs.map((l) => _chip(l)));
    }

    // Then interests
    if (ints.isNotEmpty) {
      chips.addAll(ints.map((i) => _chip(i)));
    }

    if (chips.isEmpty) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
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
    final cityCtrl = TextEditingController(text: user?.city ?? '');
    final langsCtrl = TextEditingController(
      text: (user?.languages ?? []).join(', '),
    );
    final intsCtrl = TextEditingController(
      text: (user?.interests ?? []).join(', '),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // ✅ important so sheet can move with keyboard
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: viewInsets.bottom + 16, // ✅ shifts up with keyboard
          ),
          child: SingleChildScrollView(
            // ✅ makes content scrollable when space is tight
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("About me".tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cityCtrl,
                  decoration: InputDecoration(
                    labelText: "City".tr(),
                    hintText: "e.g. Rotterdam".tr(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: langsCtrl,
                  decoration: InputDecoration(
                    labelText: "Languages (comma separated)".tr(),
                    hintText: "Dutch, Arabic, English".tr(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: intsCtrl,
                  decoration: InputDecoration(
                    labelText: "Interests (comma separated)".tr(),
                    hintText: "Qur’an, Psychology, Travel".tr(),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final city = cityCtrl.text.trim().isEmpty
                          ? null
                          : cityCtrl.text.trim();

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
                        city: city,
                        languages: languages,
                        interests: interests,
                      );

                      await loadUser();

                      if (mounted) Navigator.pop(context);
                    },
                    child: Text("Save".tr()),
                  ),
                ),
              ],
            ),
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
          child: Text("Edit about me".tr(), style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    if (_isFollowing) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Unfollow".tr()),
          content: Text("Are you sure you want to unfollow?".tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel".tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Yes".tr()),
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
    try {
      final ImagePicker picker = ImagePicker();

      final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        maxWidth: 800,
        maxHeight: 800,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop profile photo'.tr(),
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: true,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: 'Crop profile photo'.tr(),
            aspectRatioLockEnabled: true,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      if (cropped == null) return;

      final Uint8List bytes = await cropped.readAsBytes();

      await databaseProvider.updateProfilePhoto(bytes);
      await loadUser();
    } catch (e, st) {
      debugPrint('❌ Error in _pickProfilePhoto: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile picture'.tr())),
      );
    }
  }

  Future<void> _removeProfilePhoto() async {
    await databaseProvider.updateProfilePhoto(Uint8List(0));
    await loadUser();
  }

  Future<void> _addFriendFromProfile() async {
    await databaseProvider.sendFriendRequest(widget.userId);
    setState(() => _friendStatus = 'pending_sent');
  }

  Future<void> _cancelFriendFromProfile() async {
    await databaseProvider.cancelFriendRequest(widget.userId);
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

  Future<void> _unfriendFromProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Unfriend".tr()),
        content: Text("Are you sure you want to remove this person from your friends?".tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel".tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Yes, unfriend".tr()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await databaseProvider.unfriendUser(widget.userId);

    // refresh local status from DB
    final updated = await databaseProvider.getFriendStatus(widget.userId);
    if (!mounted) return;
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
              title: Text("Friends".tr()),
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
                    Text("Friends".tr(),
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
                        child: Text("View all".tr(),
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

          final rawFriends = snapshot.data ?? [];

          final allFriends = isOwn
              ? rawFriends.where((u) => u.id != currentUserId).toList()
              : rawFriends;
          final totalFriends = allFriends.length;

          if (totalFriends == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text("Friends".tr(),
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
                        child: Text("View all".tr(),
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
                      ? "Add friends to see them here.".tr()
                      : "No friends to show yet.".tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.primary.withValues(alpha: 0.7),
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
                  Text("Friends".tr(),
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
                      child: Text("View all".tr(),
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
                        if (friend.id == currentUserId) {
                          final bottomNav = Provider.of<BottomNavProvider>(
                            context,
                            listen: false,
                          );

                          bottomNav.setIndex(4);
                          Navigator.pop(context);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfilePage(userId: friend.id),
                            ),
                          );
                        }
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
                                    ? NetworkImage(friend.profilePhotoUrl)
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
                    ? Icon(Icons.check_circle, color: colorScheme.primary)
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
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                  Text("Profile song".tr(),
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
                              ? "Choose a song that plays on your profile".tr()
                              : "No profile song set".tr()),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.primary.withValues(
                        alpha: hasSong ? 0.75 : 0.6,
                      ),
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
                  hasSong ? "Change".tr() : "Choose".tr(),
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
              title: Text("Choose from gallery".tr()),
              onTap: () async {
                Navigator.pop(context);
                await _pickProfilePhoto();
              },
            ),
            if (user!.profilePhotoUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete),
                title: Text("Remove profile picture".tr()),
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

    // 🔹 First: split completed stories into Muhammad (ﷺ) parts and other prophets
    final List<String> otherCompletedIds = [];
    final List<_MuhammadPartInfo> muhammadPartInfos = [];

    for (final id in effectiveCompletedIds) {
      final story = allStoriesById[id];
      if (story == null) continue;

      final chipLower = story.chipLabel.toLowerCase();
      final titleLower = story.title.toLowerCase();

      final bool isMuhammadStory =
          chipLower.contains('muhammad') || titleLower.contains('muhammad');

      if (isMuhammadStory) {
        // Try to detect part number from id or chipLabel
        int? partNo;

        final idMatch = RegExp(r'(\d+)').firstMatch(story.id);
        if (idMatch != null) {
          partNo = int.tryParse(idMatch.group(1)!);
        }

        if (partNo == null) {
          final chipMatch = RegExp(r'(\d+)').firstMatch(story.chipLabel);
          if (chipMatch != null) {
            partNo = int.tryParse(chipMatch.group(1)!);
          }
        }

        muhammadPartInfos.add(_MuhammadPartInfo(id: id, partNo: partNo));
      } else {
        otherCompletedIds.add(id);
      }
    }

    // 🔹 Order non-Muhammad stories according to SelectStoriesPage order
    const nonMuhammadOrder = [
      'yunus',
      'yusuf',
      'musa',
      'ibrahim',
      'nuh',
      'sulayman',
      'ayyub',
      'ishaq',
      'zakariya',
      'idris',
      'harun',
      'maryam',
    ];

    final List<String> nonMuhammadSorted = [
      ...nonMuhammadOrder.where((id) => otherCompletedIds.contains(id)),
      ...otherCompletedIds.where((id) => !nonMuhammadOrder.contains(id)),
    ];

    // 🔹 Sort Muhammad parts by part number (1 → 7)
    muhammadPartInfos.sort((a, b) {
      if (a.partNo == null && b.partNo == null) return 0;
      if (a.partNo == null) return 1;
      if (b.partNo == null) return -1;
      return a.partNo!.compareTo(b.partNo!);
    });

    final muhammadIdSet = muhammadPartInfos
        .map((m) => m.id)
        .toSet(); // For quick lookup

    // Final ordered list: all other prophets, then Muhammad (ﷺ) 1–7
    final List<String> sortedCompletedIds = [
      ...nonMuhammadSorted,
      ...muhammadPartInfos.map((m) => m.id),
    ];

    // Level system: every 3 completed stories = +1 level
    final int levelsCompleted = sortedCompletedIds.length ~/ 3;

    // Muhammad series completion: must have parts 1–7
    final Set<int> muhammadParts = {
      for (final m in muhammadPartInfos)
        if (m.partNo != null) m.partNo!,
    };
    final bool muhammadSeriesCompleted = muhammadParts.containsAll({
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    });

    Widget bodyChild;
    if (_isLoading) {
      bodyChild = const Center(child: CircularProgressIndicator());
    } else if (user == null) {
      bodyChild = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("Profile not found yet.\nPlease try again in a moment.".tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
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

          // PROFILE PICTURE
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
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
                      onUnfriend: () async {
                        await _unfriendFromProfile(); // 👈 confirmation + unfriend
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
                Text("Bio".tr(),
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

          _buildEditAboutMeButton(),
          _buildAboutMeSection(),

          _buildProfileSongSection(context),

          _buildFriendsSection(context),

          // Stories progress + medals
          if (totalStories > 0) ...[
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Text("Stories completed: ${sortedCompletedIds.length} / $totalStories",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),

            if (sortedCompletedIds.isNotEmpty) ...[
              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedCompletedIds.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, // ✅ 4 badges per row
                    mainAxisSpacing: 10, // ✅ compact vertical spacing
                    crossAxisSpacing: 10,
                    childAspectRatio:
                        0.85, // ✅ slightly taller for 2-line labels
                  ),
                  itemBuilder: (context, index) {
                    final id = sortedCompletedIds[index];
                    final story = allStoriesById[id];
                    if (story == null) {
                      return const SizedBox.shrink();
                    }

                    final bool isMuhammad = muhammadIdSet.contains(id);

                    // Badge colors: golden for Muhammad (ﷺ) stories, green for others
                    final Color startColor = isMuhammad
                        ? const Color(0xFFF7D98A) // gold
                        : const Color(0xFF0F8254); // green
                    final Color endColor = isMuhammad
                        ? const Color(0xFFE0B95A)
                        : const Color(0xFF0B6841);

                    // Label text (no special Musa anymore)
                    String displayName;
                    if (isMuhammad) {
                      final partInfo = muhammadPartInfos.firstWhere(
                        (m) => m.id == id,
                        orElse: () => _MuhammadPartInfo(id: id),
                      );
                      final int? partNo = partInfo.partNo;
                      displayName = partNo != null
                          ? 'Muhammad (ﷺ) $partNo'
                          : 'Muhammad (ﷺ)';
                    } else {
                      final rawLabel = story.chipLabel;
                      final lower = rawLabel.toLowerCase();
                      displayName = lower.startsWith('prophet ')
                          ? rawLabel.substring('Prophet '.length)
                          : rawLabel;
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [startColor, endColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26.withValues(alpha: 0.12),
                                blurRadius: 5,
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
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 72,
                          child: Text(
                            displayName,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // Muhammad (ﷺ) series completed ribbon (golden)
              if (muhammadSeriesCompleted) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7D98A).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFE0B95A).withValues(alpha: 0.7),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 18,
                          color: Color(0xFFE0B95A),
                        ),
                        const SizedBox(width: 8),
                        Text("Muhammad (ﷺ) series completed".tr(),
                          style: const TextStyle(
                            color: Color(0xFF8C6B24),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],

              // Prophets Stories Level X ribbon – every 3 stories = +1 level
              if (levelsCompleted > 0) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F8254).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF0F8254).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 18,
                          color: Color(0xFF0F8254),
                        ),
                        const SizedBox(width: 8),
                        Text("Prophets Stories Level $levelsCompleted".tr(),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
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
                          Text("Posts".tr(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            postCount == 0
                                ? "Tap to view posts".tr()
                                : "$postCount post${postCount == 1 ? '' : 's'} • tap to view",
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showPosts ? "Hide".tr() : "Show".tr(),
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
                      child: Text("No posts yet..".tr(),
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
          ? AppBar(foregroundColor: Theme.of(context).colorScheme.primary)
          : null,
      body: bodyChild,
    );
  }
}
