// lib/pages/profile_page.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

// ✅ NEW: unified Saved page (Posts / Ayat / Reflections)
import 'package:ummah_chat/pages/saved_page.dart';

import '../models/post.dart';
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
stories progress, horizontal Friends row, and an optional profile song.
*/

class ProfilePage extends StatefulWidget {
  final String userId;
  final String? inquiryId; // ✅ add

  const ProfilePage({super.key, required this.userId, this.inquiryId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ✅ Consistent spacing between the tiles:
  // Saved / Posts
  static const double _profileSectionGap = 12;

  // Providers
  late final databaseProvider = Provider.of<DatabaseProvider>(
    context,
    listen: false,
  );
  late final listeningProvider = Provider.of<DatabaseProvider>(
    context,
    listen: true,
  );

  // user info
  UserProfile? user;
  final String currentUserId = AuthService().getCurrentUserId();

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

  String? _myGender;

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

  // PROFILE SONG – audio player
  late final AudioPlayer _audioPlayer;
  bool _isPlayingProfileSong = false;
  String? _currentSongId;

  @override
  void initState() {
    super.initState();

    debugPrint(
      '👤 ProfilePage initState | userId=${widget.userId} | stateHash=${identityHashCode(this)}',
    );

    _audioPlayer = AudioPlayer();

    // listen to player state to update the play/pause icon
    _audioPlayer.playerStateStream.listen((state) {
      final isPlaying =
          state.playing &&
          state.processingState != ProcessingState.completed &&
          state.processingState != ProcessingState.idle;

      if (!mounted) return;
      setState(() => _isPlayingProfileSong = isPlaying);
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
    _audioPlayer.dispose();
    super.dispose();
  }

  // lookup helper
  ProfileSong? _getSongById(String? id) {
    if (id == null || id.isEmpty) return null;
    try {
      return kProfileSongs.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  // start playing a given song id (if it exists locally)
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
            SnackBar(
              content: Text(
                'asset_not_found'.tr(namedArgs: {'path': song.assetPath}),
              ),
            ),
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

      if (mounted) setState(() => _currentSongId = songId);
    } on PlayerException catch (e) {
      debugPrint('❌ PlayerException: code=${e.code}, message=${e.message}');
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

  // toggle play/pause
  Future<void> _toggleProfileSongPlayPause() async {
    final songId = user?.profileSongId ?? '';
    if (songId.isEmpty) return;

    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _startProfileSong(songId);
    }
  }

  // change the song from the picker
  Future<void> _setProfileSong(String songId) async {
    if (!_isOwnProfile) return;

    // update local UI immediately
    if (mounted) {
      setState(() {
        _currentSongId = songId;
        if (user != null) user = user!.copyWith(profileSongId: songId);
      });
    }

    await databaseProvider.updateProfileSong(songId);
    await _startProfileSong(songId);
  }

  Future<void> loadUser() async {
    if (mounted) setState(() => _isLoading = true);

    const int maxAttempts = 8;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      user = await databaseProvider.getUserProfile(widget.userId);
      if (user != null) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted) return;

    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final me = await databaseProvider.getUserProfile(currentUserId);
    if (!mounted) return;
    _myGender = me?.gender;

    await databaseProvider.loadUserFollowers(widget.userId);
    if (!mounted) return;

    await databaseProvider.loadUserFollowing(widget.userId);
    if (!mounted) return;

    _isFollowing = databaseProvider.isFollowing(widget.userId);

// ✅ IMPORTANT: if we arrived via a notification with inquiryId,
// use that exact inquiry to compute the UI status.
// This prevents "latest inquiry" mismatches and fixes mahram seeing "Add friend".
    final passedInquiryId = (widget.inquiryId ?? '').trim();

    if (passedInquiryId.isNotEmpty) {
      final inquiry = await databaseProvider.getInquiryById(passedInquiryId);

      if (inquiry != null) {
        final ui = databaseProvider.computeInquiryUiStatus(
          inquiry: inquiry,
          viewerId: currentUserId,
          otherUserId: widget.userId,
        );

        if (ui != null) {
          _friendStatus = ui;
        } else {
          // Inquiry is not actionable for this viewer anymore -> fall back to friendship status
          _friendStatus =
          await databaseProvider.getFriendshipStatus(widget.userId);
        }
      } else {
        // Fallback if inquiry was deleted/ended
        _friendStatus =
        await databaseProvider.getCombinedRelationshipStatus(widget.userId);
      }
    } else {
      _friendStatus =
      await databaseProvider.getCombinedRelationshipStatus(widget.userId);
    }

    if (!mounted) return;


    _completedStoryIds =
    await databaseProvider.getCompletedStoriesForUser(widget.userId);
    if (!mounted) return;

    // PROFILE SONG HANDLING
    final songId = user!.profileSongId ?? '';
    if (songId.isNotEmpty) {
      _currentSongId = songId;

      if (!_isOwnProfile) {
        Future.microtask(() async {
          if (!mounted) return;
          await _startProfileSong(songId);
        });
      }
    } else {
      await _audioPlayer.stop();
      _currentSongId = null;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
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

    if (country.isNotEmpty) chips.add(_chip(country.tr()));
    if (city != null && city.isNotEmpty) chips.add(_chip(city));
    if (langs.isNotEmpty) chips.addAll(langs.map((l) => _chip(l)));
    if (ints.isNotEmpty) chips.addAll(ints.map((i) => _chip(i)));

    if (chips.isEmpty) return const SizedBox();

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
            bottom: viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "About me".tr(),
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
          child: Text(
            "Edit about me".tr(),
            style: const TextStyle(fontSize: 12),
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
          title: Text("Unfollow".tr()),
          content: Text("are_you_sure_you_want_to_unfollow".tr()),
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
    final updated = await databaseProvider.getCombinedRelationshipStatus(widget.userId);
    setState(() => _friendStatus = updated);
  }

  Future<void> _declineFriendFromProfile() async {
    await databaseProvider.declineFriendRequest(widget.userId);
    final updated = await databaseProvider.getCombinedRelationshipStatus(widget.userId);
    setState(() => _friendStatus = updated);
  }

  Future<void> _unfriendFromProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Unfriend".tr()),
        content: Text("confirm_unfriend_message".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel".tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("yes_unfriend".tr()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await databaseProvider.unfriendUser(widget.userId);
    final updated = await databaseProvider.getCombinedRelationshipStatus(widget.userId);
    if (!mounted) return;
    setState(() => _friendStatus = updated);
  }

  void _goToMyProfileInMainLayout() {
    // If we're already on the root Profile tab (no pushed routes), do nothing.
    if (!Navigator.of(context).canPop()) return;

    // 1) Switch bottom nav to Profile tab
    Provider.of<BottomNavProvider>(context, listen: false).setIndex(4);

    // 2) Pop everything above MainLayout (root route)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _cancelMahramFromProfile() async {
    await databaseProvider.cancelMahramRequest(widget.userId);
    setState(() => _friendStatus = 'none');
  }

  Future<void> _acceptMahramFromProfile() async {
    final db = context.read<DatabaseProvider>();
    final String otherUserId = widget.userId;
    if (otherUserId.isEmpty) return;

    final bool? isMahram = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: Text('mahram_confirmation_title'.tr()),
          content: Text('mahram_confirmation_question'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('no'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('yes'.tr()),
            ),
          ],
        );
      },
    );

    if (isMahram == null) return;

    try {
      if (isMahram == true) {
        if (mounted) setState(() => _friendStatus = 'mahram');

        await db.acceptMahramRequest(otherUserId);

        final updated =
        await databaseProvider.getCombinedRelationshipStatus(widget.userId);
        if (!mounted) return;
        setState(() => _friendStatus = updated);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('mahram_accepted'.tr())),
        );
      } else {
        if (mounted) setState(() => _friendStatus = 'none');

        await db.declineMahramRequest(otherUserId);

        final updated =
        await databaseProvider.getCombinedRelationshipStatus(widget.userId);
        if (!mounted) return;
        setState(() => _friendStatus = updated);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('mahram_declined'.tr())),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('something_went_wrong'.tr())),
      );
    }
  }


  Future<void> _declineMahramFromProfile() async {
    await databaseProvider.declineMahramRequest(widget.userId);
    final updated = await databaseProvider.getCombinedRelationshipStatus(widget.userId);
    if (!mounted) return;
    setState(() => _friendStatus = updated);
  }

  bool _isOppositeGender({
    required String? myGender,
    required String? theirGender,
  }) {
    final a = (myGender ?? '').trim().toLowerCase();
    final b = (theirGender ?? '').trim().toLowerCase();
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return false;
    // Your app uses 'male' / 'female'
    return (a == 'male' || a == 'female') && (b == 'male' || b == 'female');
  }

  Future<String?> _pickMahramDialog({
    required List<UserProfile> myFriends,
  }) async {
    if (!mounted) return null;

    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: Text('Pick a mahram'.tr()),
          content: SizedBox(
            width: double.maxFinite,
            child: myFriends.isEmpty
                ? Text('No friends found'.tr())
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: myFriends.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = myFriends[i];
                      final label = (p.name.trim().isNotEmpty)
                          ? p.name.trim()
                          : (p.username.trim().isNotEmpty
                                ? p.username.trim()
                                : 'User'.tr());

                      return ListTile(
                        title: Text(label),
                        onTap: () => Navigator.pop(context, p.id),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Cancel'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startMarriageInquiry() async {
    final db = context.read<DatabaseProvider>();

    final targetUserId = widget.userId; // profile you're viewing
    if (targetUserId.isEmpty) return;

    try {
      final myUserId = AuthService().getCurrentUserId();
      if (myUserId.isEmpty) return;

      final myGender = (_myGender ?? '').trim().toLowerCase();

      String initiatedBy;
      String manId;
      String womanId;
      String? mahramId;

      // ✅ Flow 2 (woman initiates): pick mahram immediately
      if (myGender == 'female') {
        initiatedBy = 'woman';
        manId = targetUserId;
        womanId = myUserId;

        final mahrams = await db.getMyMahrams();
        final picked = await _pickMahramDialog(myFriends: mahrams);
        if (picked == null || picked.isEmpty) return;

        mahramId = picked;
      } else {
        // ✅ Flow 1 (man initiates): no mahram upfront
        initiatedBy = 'man';
        manId = myUserId;
        womanId = targetUserId;
        mahramId = null;
      }

      final inquiryId = await db.createMarriageInquiry(
        manId: manId,
        womanId: womanId,
        initiatedBy: initiatedBy,
        mahramId: mahramId,
      );

      if (!mounted) return;

      // ✅ Instant UI feedback
      setState(() => _friendStatus = 'inquiry_pending_sent');

      // ✅ Refresh actual combined status from DB (always pass the profile you're viewing)
      final updated = await databaseProvider.getCombinedRelationshipStatus(targetUserId);
      if (!mounted) return;
      setState(() => _friendStatus = updated);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('marriage_inquiry_sent'.tr())),
      );

      debugPrint('✅ Marriage inquiry created: $inquiryId | initiatedBy=$initiatedBy');
    } catch (e, st) {
      debugPrint('❌ _startMarriageInquiry failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('something_went_wrong'.tr())),
      );
    }
  }


  Future<void> _womanPickMahramForInquiry({
    required String inquiryId,
  }) async {
    final db = context.read<DatabaseProvider>();

    try {
      // Woman picks from HER friends
      final mahrams = await db.getMyMahrams();

      final selectedMahramId = await _pickMahramDialog(myFriends: mahrams);
      if (selectedMahramId == null || selectedMahramId.isEmpty) return;

      // ✅ NEW final method
      await db.womanAcceptAndSelectMahramForInquiry(
        inquiryId: inquiryId,
        mahramId: selectedMahramId,
      );

      setState(() => _friendStatus = 'inquiry_pending_sent');

      if (!mounted) return;

      // refresh combined status so button becomes pending_mahram etc.
      final updated = await databaseProvider.getCombinedRelationshipStatus(widget.userId);
      if (!mounted) return;
      setState(() => _friendStatus = updated);

      debugPrint('✅ woman selected mahram; refreshing relationship status...');


      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mahram selected'.tr())),
      );
    } catch (e, st) {
      debugPrint('❌ womanAcceptAndSelectMahramForInquiry failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('something_went_wrong'.tr())),
      );
    }
  }

  Future<String?> _resolveInquiryId() async {
    final id = widget.inquiryId;
    if (id != null && id.isNotEmpty) return id;

    final latest = await databaseProvider.getLatestActiveInquiryBetweenMeAnd(widget.userId);
    if (latest == null) return null;

    final latestId = (latest['id'] ?? '').toString();
    return latestId.isEmpty ? null : latestId;
  }




  void _showOppositeGenderRequestSheet({
    required String targetUserId,
    required String targetName,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),

                ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: Text('Marriage inquiry'.tr()),
                  onTap: () async {
                    Navigator.pop(context);
                    await _startMarriageInquiry();
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text('Mahram'.tr()),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _confirmAndSendMahramRequest(
                      targetUserId: targetUserId,
                      targetName: targetName,
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.block),
                  title: Text('Neither'.tr()),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('cannot_add_opposite_gender'.tr()),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 4),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: Text('Cancel'.tr()),
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmAndSendMahramRequest({
    required String targetUserId,
    required String targetName,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('mahram_confirmation_title'.tr()),
        content: Text('mahram_confirmation_question'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('no'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('yes'.tr()),
          ),
        ],
      ),
    );

    if (ok != true) return;

    // Calls Provider → DatabaseService.sendMahramRequestInDatabase(...)
    if (!mounted) return;
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    await dbProvider.sendMahramRequest(targetUserId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'mahram_request_sent'.tr(namedArgs: {'name': targetName}),
        ),
      ),
    );

    // ✅ refresh button state after sending
    final updated = await databaseProvider.getCombinedRelationshipStatus(widget.userId);
    if (!mounted) return;
    setState(() => _friendStatus = updated);
  }

  Future<void> _confirmAndDeleteMahram({
    required String targetUserId,
    required String targetName,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('remove_mahram_title'.tr()),
        content: Text(
          'remove_mahram_confirm'.tr(namedArgs: {'name': targetName}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'.tr()),
          ),
        ],
      ),
    );

    if (ok != true) return;

    if (!mounted) return;
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    await dbProvider.deleteMahramRelationship(targetUserId);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('mahram_removed'.tr())));

    // ✅ refresh button state after deleting
    final updated = await databaseProvider.getCombinedRelationshipStatus(widget.userId);
    if (!mounted) return;
    setState(() => _friendStatus = updated);
  }

  /// FRIENDS SECTION – horizontal row of friends
  Widget _buildFriendsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOwn = _isOwnProfile;

    void openFriendsFullScreen() {
      final displayName = (user?.name ?? '').trim();
      final firstName = displayName.isEmpty
          ? ''
          : displayName.split(RegExp(r'\s+')).first;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            appBar: AppBar(
              title: Text(
                isOwn
                    ? "Friends".tr()
                    : "friends_of".tr(namedArgs: {'name': firstName}),
              ),
              centerTitle: true,
              backgroundColor: Theme.of(ctx).colorScheme.surface,
              foregroundColor: Theme.of(ctx).colorScheme.primary,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
            body: isOwn
                ? const FriendsPage()
                : FriendsPage(userId: widget.userId),
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
          if (snapshot.hasError) return const SizedBox.shrink();

          final rawFriends = snapshot.data ?? [];
          final allFriends = isOwn
              ? rawFriends.where((u) => u.id != currentUserId).toList()
              : rawFriends;
          final totalFriends = allFriends.length;

          if (!snapshot.hasData) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Friends".tr(),
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
                    const Spacer(),
                    TextButton(
                      onPressed: openFriendsFullScreen,
                      child: Text(
                        "View all".tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
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

          if (totalFriends == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Friends".tr(),
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
                    const Spacer(),
                    TextButton(
                      onPressed: openFriendsFullScreen,
                      child: Text(
                        "View all".tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
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

          const int maxTiles = 12;

          // Show 11 friends + 1 "+X" tile if needed
          final bool hasMore = allFriends.length > maxTiles;
          final int friendTilesCount = hasMore
              ? (maxTiles - 1)
              : allFriends.length;

          final visibleFriends = allFriends.take(friendTilesCount).toList();
          final int remainingCount = allFriends.length - friendTilesCount;

          // Total tiles in the horizontal row
          final int itemCount = hasMore
              ? friendTilesCount + 1
              : friendTilesCount;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "Friends".tr(),
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
                  const Spacer(),
                  TextButton(
                    onPressed: openFriendsFullScreen,
                    child: Text(
                      "View all".tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: itemCount,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    // ✅ last tile is "+X more"
                    if (hasMore && index == itemCount - 1) {
                      return GestureDetector(
                        onTap: openFriendsFullScreen,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.primary.withValues(
                                  alpha: 0.10,
                                ),
                                border: Border.all(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '+$remainingCount',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 70,
                              child: Text(
                                "More".tr(),
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
                    }

                    // ✅ normal friend tile
                    final friend = visibleFriends[index];

                    return GestureDetector(
                      onTap: () {
                        if (friend.id == currentUserId) {
                          _goToMyProfileInMainLayout();
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

  // PROFILE SONG SECTION
  Widget _buildProfileSongSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final songId = user?.profileSongId ?? '';
    final song = _getSongById(songId);
    final hasSong = song != null;

    void openSongPicker() {
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
                  Text(
                    "Profile song".tr(),
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
                onPressed: openSongPicker,
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

  // ✅ NEW: Saved entry that opens SavedPage (3 tabs)
  Widget _buildSavedEntry(BuildContext context) {
    if (!_isOwnProfile) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          // Warm up caches so SavedPage feels instant
          await databaseProvider.loadBookmarks();
          await databaseProvider.loadPrivateReflections();

          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SavedPage()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withValues(alpha: 0.12),
                ),
                child: Icon(Icons.bookmark_border, size: 18, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Saved".tr(),
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "saved_subtitle_all".tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.primary.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.keyboard_arrow_right_rounded, color: cs.primary),
            ],
          ),
        ),
      ),
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

    // split completed stories
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
        int? partNo;

        final idMatch = RegExp(r'(\d+)').firstMatch(story.id);
        if (idMatch != null) partNo = int.tryParse(idMatch.group(1)!);

        if (partNo == null) {
          final chipMatch = RegExp(r'(\d+)').firstMatch(story.chipLabel);
          if (chipMatch != null) partNo = int.tryParse(chipMatch.group(1)!);
        }

        muhammadPartInfos.add(_MuhammadPartInfo(id: id, partNo: partNo));
      } else {
        otherCompletedIds.add(id);
      }
    }

    const nonMuhammadOrder = [
      // Early prophets
      'adam',
      'idris',
      'nuh',
      'hud',
      'salih',

      // Ibrahim family
      'ibrahim',
      'lut',
      'ismail',
      'ishaq',
      'yaqub',
      'yusuf',

      // Other nations
      'shuayb',
      'ayyub',
      'dhul_kifl',

      // Musa era
      'musa',
      'harun',

      // Kings & prophets
      'dawud',
      'sulayman',
      'ilyas',
      'alyasa',
      'yunus',

      // Later prophets
      'zakariya',
      'yahya',
      'maryam',
      'isa',
    ];

    final List<String> nonMuhammadSorted = [
      ...nonMuhammadOrder.where((id) => otherCompletedIds.contains(id)),
      ...otherCompletedIds.where((id) => !nonMuhammadOrder.contains(id)),
    ];

    muhammadPartInfos.sort((a, b) {
      if (a.partNo == null && b.partNo == null) return 0;
      if (a.partNo == null) return 1;
      if (b.partNo == null) return -1;
      return a.partNo!.compareTo(b.partNo!);
    });

    final muhammadIdSet = muhammadPartInfos.map((m) => m.id).toSet();

    final List<String> sortedCompletedIds = [
      ...nonMuhammadSorted,
      ...muhammadPartInfos.map((m) => m.id),
    ];

    final int levelsCompleted = sortedCompletedIds.length ~/ 3;

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
          child: Text(
            "Profile not found yet.\nPlease try again in a moment.".tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      );
    } else {
      final theme = Theme.of(context);

      // ✅ opposite-gender detection (DB stores lowercase, but we still normalize)
      final bool isOpposite = _isOppositeGender(
        myGender: _myGender,
        theirGender: user!.gender,
      );

      // ✅ IMPORTANT FIX:
      // If no relationship exists AND it's opposite gender -> force button into "request" mode.
      final bool isInquiryStatus = _friendStatus.startsWith('inquiry_');

      final String effectiveFriendStatus =
      (!isInquiryStatus && _friendStatus == 'none' && isOpposite)
          ? 'request'
          : _friendStatus;



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
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user!.username}',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.primary,
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
                            color: theme.colorScheme.secondary,
                          ),
                          child: Icon(
                            Icons.person,
                            size: 70,
                            color: theme.colorScheme.primary,
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
                          color: theme.colorScheme.primary,
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
            postCount: postCount,
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
                      // ✅ use effective status so opposite gender shows "Request"
                      friendStatus: effectiveFriendStatus,

                      // ✅ normal add friend only when NOT in "request" mode
                      onAddFriend: (effectiveFriendStatus == 'request')
                          ? null
                          : _addFriendFromProfile,

                      onCancelRequest: () async {
                        // inquiry cancel/end has priority
                        if (_friendStatus == 'inquiry_pending_sent' || _friendStatus == 'inquiry_cancel_inquiry') {
                          final id = await _resolveInquiryId();
                          if (id == null) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('something_went_wrong'.tr())),
                            );
                            return;
                          }

                          await databaseProvider.cancelOrEndMarriageInquiry(inquiryId: id);

                          final updated = await databaseProvider.getCombinedRelationshipStatus(widget.userId);
                          if (!mounted) return;
                          setState(() => _friendStatus = updated);
                          return;
                        }

                        // mahram/friend cancel
                        if (_friendStatus == 'pending_mahram_sent') {
                          await _cancelMahramFromProfile();
                        } else {
                          await _cancelFriendFromProfile();
                        }

                        final updated = await databaseProvider.getCombinedRelationshipStatus(widget.userId);
                        if (!mounted) return;
                        setState(() => _friendStatus = updated);
                      },

                      onAcceptRequest: () async {
                        // ✅ Inquiry accept (role-specific)
                        if (_friendStatus.startsWith('inquiry_')) {
                          final id = await _resolveInquiryId();
                          if (id == null) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('something_went_wrong'.tr())),
                            );
                            return;
                          }

                          if (_friendStatus == 'inquiry_pending_received_woman') {
                            // woman picks mahram (and accepts)
                            await _womanPickMahramForInquiry(inquiryId: id);
                          } else if (_friendStatus == 'inquiry_pending_received_mahram') {
                            // mahram approves
                            await databaseProvider.mahramRespondToInquiry(inquiryId: id, approve: true);
                          } else if (_friendStatus == 'inquiry_pending_received_man') {
                            // man accepts (Flow 2)
                            await databaseProvider.manRespondToInquiry(inquiryId: id, accept: true);
                          }

                          final updated = await databaseProvider.getCombinedRelationshipStatus(widget.userId);
                          if (!mounted) return;
                          setState(() => _friendStatus = updated);
                          return;
                        }

                        // ✅ Mahram / friend accept
                        if (_friendStatus == 'pending_mahram_received') {
                          await _acceptMahramFromProfile();
                        } else {
                          await _acceptFriendFromProfile();
                        }

                        final updated = await databaseProvider.getCombinedRelationshipStatus(widget.userId);
                        if (!mounted) return;
                        setState(() => _friendStatus = updated);
                      },

                      onDeclineRequest: () async {
                        // ✅ Inquiry decline (role-specific)
                        if (_friendStatus.startsWith('inquiry_')) {
                          final id = await _resolveInquiryId();
                          if (id == null) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('something_went_wrong'.tr())),
                            );
                            return;
                          }

                          if (_friendStatus == 'inquiry_pending_received_woman') {
                            await databaseProvider.womanDeclineInquiry(inquiryId: id);
                          } else if (_friendStatus == 'inquiry_pending_received_mahram') {
                            await databaseProvider.mahramRespondToInquiry(inquiryId: id, approve: false);
                          } else if (_friendStatus == 'inquiry_pending_received_man') {
                            await databaseProvider.manRespondToInquiry(inquiryId: id, accept: false);
                          }

                          final updated = await databaseProvider.getCombinedRelationshipStatus(widget.userId);
                          if (!mounted) return;
                          setState(() => _friendStatus = updated);
                          return;
                        }

                        // mahram/friend decline
                        if (_friendStatus == 'pending_mahram_received') {
                          await _declineMahramFromProfile();
                        } else {
                          await _declineFriendFromProfile();
                        }

                        final updated = await databaseProvider.getCombinedRelationshipStatus(widget.userId);
                        if (!mounted) return;
                        setState(() => _friendStatus = updated);
                      },

                      // ✅ normal unfriend
                      onUnfriend: _unfriendFromProfile,

                      // ✅ NEW: opposite-gender “Request” sheet
                      onOpenRequestSheet: (effectiveFriendStatus == 'request')
                          ? () => _showOppositeGenderRequestSheet(
                              targetUserId: widget.userId,
                              targetName: user!.name,
                            )
                          : null,

                      // ✅ delete mahram relationship when status == 'mahram'
                      onDeleteMahram: () => _confirmAndDeleteMahram(
                        targetUserId: widget.userId,
                        targetName: user!.name,
                      ),
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
                  "Bio".tr(),
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
                if (_isOwnProfile)
                  GestureDetector(
                    onTap: _showEditBioBox,
                    child: Icon(Icons.edit, color: theme.colorScheme.primary),
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

          // Stories progress + medals (UPDATED: hide if 0 completed)
          if (totalStories > 0) ...[
            const SizedBox(height: 24),

            // ✅ hide "stories completed" text when 0
            if (sortedCompletedIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Text(
                  'stories_completed'.tr(
                    namedArgs: {
                      'done': sortedCompletedIds.length.toString(),
                      'total': totalStories.toString(),
                    },
                  ),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
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
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, index) {
                    final id = sortedCompletedIds[index];
                    final story = allStoriesById[id];
                    if (story == null) return const SizedBox.shrink();

                    final bool isMuhammad = muhammadIdSet.contains(id);

                    final Color startColor = isMuhammad
                        ? const Color(0xFFF7D98A)
                        : const Color(0xFF0F8254);
                    final Color endColor = isMuhammad
                        ? const Color(0xFFE0B95A)
                        : const Color(0xFF0B6841);

                    String displayName;
                    if (isMuhammad) {
                      final partInfo = muhammadPartInfos.firstWhere(
                        (m) => m.id == id,
                        orElse: () => _MuhammadPartInfo(id: id),
                      );
                      final int? partNo = partInfo.partNo;
                      displayName = partNo != null
                          ? 'muhammad_part'.tr(
                              namedArgs: {'part': partNo.toString()},
                            )
                          : 'muhammad'.tr();
                    } else {
                      final rawLabel = story.chipLabel.tr();
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
                              color: theme.colorScheme.primary,
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
                        Text(
                          "Muhammad (ﷺ) series completed".tr(),
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
                        Text(
                          'prophets_stories_level'.tr(
                            namedArgs: {'level': levelsCompleted.toString()},
                          ),
                          style: const TextStyle(
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

          // ✅ Saved (opens SavedPage with 3 tabs) — no dropdown anymore
          const SizedBox(height: _profileSectionGap),
          _buildSavedEntry(context),

          const SizedBox(height: _profileSectionGap),

          // POSTS SECTION
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                final willShow = !_showPosts;
                setState(() => _showPosts = willShow);

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
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                      ),
                      child: Icon(
                        Icons.article_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Posts".tr(),
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            postCount == 0
                                ? 'tap_to_view_posts'.tr()
                                : 'posts_tap_to_view'.plural(
                                    postCount,
                                    namedArgs: {'count': postCount.toString()},
                                  ),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.75,
                              ),
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
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.08,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showPosts ? "Hide".tr() : "Show".tr(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showPosts
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_showPosts) ...[
            const SizedBox(height: 8),
            (allUserPosts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Text(
                        "No posts yet..".tr(),
                        style: TextStyle(color: theme.colorScheme.primary),
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

          const SizedBox(height: 18),
        ],
      );
    }

    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: canPop
          ? AppBar(
              foregroundColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              scrolledUnderElevation: 0,
            )
          : null,
      body: bodyChild,
    );
  }
}
