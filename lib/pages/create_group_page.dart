// lib/pages/create_group_page.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../services/auth/auth_service.dart';
import '../services/chat/chat_provider.dart';
import '../services/database/database_provider.dart';
import 'group_chat_page.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();
  final _authService = AuthService();

  final Set<String> _selectedFriendIds = {};

  bool _isCreating = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createGroup(BuildContext context) async {
    final currentUserId = _authService.getCurrentUserId();
    if (currentUserId.isEmpty) return;

    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a group name'.tr())),
      );
      return;
    }

    if (_selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one member'.tr())),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      final roomId = await chatProvider.createGroupRoom(
        name: name,
        creatorId: currentUserId,
        initialMemberIds: _selectedFriendIds.toList(),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatPage(
            chatRoomId: roomId,
            groupName: name,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Failed to create group:'.tr()} $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _toggleMember(String userId, bool currentlySelected) {
    setState(() {
      if (currentlySelected) {
        _selectedFriendIds.remove(userId);
      } else {
        _selectedFriendIds.add(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final currentUserId = _authService.getCurrentUserId();

    if (currentUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('New group'.tr()),
          backgroundColor: colorScheme.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: Center(
          child: Text(
            'You must be logged in to create a group'.tr(),
            style: TextStyle(color: colorScheme.primary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'New group'.tr(),
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surface,
              colorScheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.12),
                      colorScheme.secondary.withValues(alpha: 0.45),
                      colorScheme.surfaceContainerHigh,
                    ],
                  ),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary.withValues(alpha: 0.14),
                      ),
                      child: Icon(
                        Icons.groups_2_rounded,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create your group'.tr(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Choose a name and select friends or mahrams to start chatting together.'
                                .tr(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary.withValues(alpha: 0.72),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _groupNameController,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Group name'.tr(),
                  labelStyle: TextStyle(
                    color: colorScheme.primary.withValues(alpha: 0.72),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh,
                  prefixIcon: Icon(
                    Icons.edit_outlined,
                    color: colorScheme.primary.withValues(alpha: 0.78),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search members'.tr(),
                  hintStyle: TextStyle(
                    color: colorScheme.primary.withValues(alpha: 0.60),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: colorScheme.primary.withValues(alpha: 0.72),
                  ),
                  suffixIcon: _searchQuery.trim().isEmpty
                      ? null
                      : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      color: colorScheme.primary.withValues(alpha: 0.72),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Select members'.tr(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_selectedFriendIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_selectedFriendIds.length}',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<List<UserProfile>>(
                stream: dbProvider.connectionsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading members'.tr(),
                        style: TextStyle(color: colorScheme.primary),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allConnections = (snapshot.data ?? [])
                      .where((u) => u.id != currentUserId)
                      .toList();

                  if (allConnections.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.group_outlined,
                              size: 52,
                              color: colorScheme.primary.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No friends or mahrams yet'.tr(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add friends or mahrams before creating a group.'
                                  .tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.primary.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  List<UserProfile> filteredConnections = allConnections;
                  if (_searchQuery.trim().isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    filteredConnections = allConnections.where((u) {
                      final name = u.name.toLowerCase();
                      final username = u.username.toLowerCase();
                      return name.contains(q) || username.contains(q);
                    }).toList();
                  }

                  filteredConnections.sort((a, b) {
                    final aMahram = dbProvider.isMahramUser(a.id);
                    final bMahram = dbProvider.isMahramUser(b.id);

                    if (aMahram != bMahram) {
                      return aMahram ? 1 : -1;
                    }
                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  });

                  if (filteredConnections.isEmpty) {
                    return Center(
                      child: Text(
                        'No members match your search'.tr(),
                        style: TextStyle(
                          color: colorScheme.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: filteredConnections.length,
                    itemBuilder: (context, index) {
                      final user = filteredConnections[index];
                      final isSelected = _selectedFriendIds.contains(user.id);
                      final isMahram = dbProvider.isMahramUser(user.id);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MemberSelectionTile(
                          user: user,
                          isSelected: isSelected,
                          isMahram: isMahram,
                          onTap: () => _toggleMember(user.id, isSelected),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCreating ? null : () => _createGroup(context),
                  icon: _isCreating
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _isCreating ? 'Creating...'.tr() : 'Create group'.tr(),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF0D6746),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberSelectionTile extends StatelessWidget {
  final UserProfile user;
  final bool isSelected;
  final bool isMahram;
  final VoidCallback onTap;

  const _MemberSelectionTile({
    required this.user,
    required this.isSelected,
    required this.isMahram,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.10)
                : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? colors.primary.withValues(alpha: 0.35)
                  : colors.outlineVariant.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                _buildAvatar(colors, user),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '@${user.username}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.primary.withValues(alpha: 0.68),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isMahram) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Mahram'.tr(),
                                style: TextStyle(
                                  color: colors.primary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? colors.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? colors.primary
                          : colors.primary.withValues(alpha: 0.35),
                      width: 1.6,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: colors.onPrimary,
                  )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ColorScheme colors, UserProfile user) {
    const radius = 22.0;

    if (user.profilePhotoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(user.profilePhotoUrl),
      );
    }

    final initials = () {
      if (user.name.trim().isEmpty) return '?';
      final parts = user.name.trim().split(' ');
      if (parts.length == 1) return parts.first[0].toUpperCase();
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }();

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primary.withValues(alpha: 0.12),
      child: Text(
        initials,
        style: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}