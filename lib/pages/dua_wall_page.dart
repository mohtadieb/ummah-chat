import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/database/database_provider.dart';
import '../services/auth/auth_service.dart';
import '../components/my_input_alert_box.dart';

// You’ll need to create this model in ../models/dua.dart
import '../models/dua.dart';

class DuaWallPage extends StatefulWidget {
  const DuaWallPage({super.key});

  @override
  State<DuaWallPage> createState() => _DuaWallPageState();
}

class _DuaWallPageState extends State<DuaWallPage> {
  late final DatabaseProvider databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);
  late final DatabaseProvider listeningProvider =
  Provider.of<DatabaseProvider>(context);

  bool _isLoading = true;
  final String _currentUserId = AuthService().getCurrentUserId();

  @override
  void initState() {
    super.initState();
    _loadDuaWall();
  }

  Future<void> _loadDuaWall() async {
    setState(() => _isLoading = true);
    try {
      await databaseProvider.loadDuaWall();
    } catch (e) {
      debugPrint('Error loading Dua Wall: $e');
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  // ---------------------------
  // Create new dua dialog
  // ---------------------------
  void _openCreateDuaDialog() {
    final TextEditingController duaController = TextEditingController();
    final messenger = ScaffoldMessenger.maybeOf(context);

    bool isAnonymous = false;
    bool isPrivate = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setInnerState) {
            return MyInputAlertBox(
              textController: duaController,
              hintText: "Write your dua here...",
              onPressedText: "Post",
              onPressed: () async {
                final text = duaController.text.trim();

                if (text.replaceAll(RegExp(r'\s+'), '').length < 5) {
                  messenger?.showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Your dua should be at least 5 characters.",
                      ),
                    ),
                  );
                  return;
                }

                try {
                  await databaseProvider.createDua(
                    text: text,
                    isAnonymous: isAnonymous,
                    isPrivate: isPrivate,
                  );

                  duaController.clear();
                  messenger?.showSnackBar(
                    const SnackBar(
                      content: Text("Your dua has been shared."),
                    ),
                  );

                  // Refresh list
                  await _loadDuaWall();
                } catch (e) {
                  debugPrint('Error creating dua: $e');
                  messenger?.showSnackBar(
                    const SnackBar(
                      content:
                      Text("Could not share dua. Please try again."),
                    ),
                  );
                }
              },
              extraWidget: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    "Visibility",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text("Show my name"),
                        selected: !isAnonymous && !isPrivate,
                        onSelected: (_) {
                          setInnerState(() {
                            isAnonymous = false;
                            isPrivate = false;
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text("Anonymous"),
                        selected: isAnonymous,
                        onSelected: (value) {
                          setInnerState(() {
                            isAnonymous = value;
                            if (value) isPrivate = false;
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text("Private (only me)"),
                        selected: isPrivate,
                        onSelected: (value) {
                          setInnerState(() {
                            isPrivate = value;
                            if (value) isAnonymous = false;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "• Anonymous: others see “Anonymous” instead of your name.\n"
                        "• Private: only you can see this dua in your Dua Wall.",
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------
  // Ameen toggle
  // ---------------------------
  Future<void> _toggleAmeen(Dua dua) async {
    try {
      await databaseProvider.toggleAmeenForDua(dua.id);
    } catch (e) {
      debugPrint('Error toggling Ameen: $e');
    }
  }

  // ---------------------------
  // Helpers
  // ---------------------------
  String _formatTimeAgo(DateTime createdAt) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
    if (diff.inHours < 24) return "${diff.inHours} h ago";
    if (diff.inDays < 7) return "${diff.inDays} d ago";

    // fallback: simple date
    return "${createdAt.day.toString().padLeft(2, '0')}-"
        "${createdAt.month.toString().padLeft(2, '0')}-"
        "${createdAt.year}";
  }

  Future<void> _confirmDeleteDua(Dua dua) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete dua?'),
          content: const Text(
              'Are you sure you want to delete this dua? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await databaseProvider.deleteDua(dua.id);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Dua deleted.')),
      );
    } catch (e) {
      debugPrint('Error deleting dua: $e');
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Could not delete dua. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // ❗ from DatabaseProvider: a List<Dua> e.g. duaWall
    final List<Dua> allDuas = listeningProvider.duaWall;

    // Filter out private duas from other users
    final visibleDuas = allDuas.where((d) {
      if (!d.isPrivate) return true;
      return d.userId == _currentUserId;
    }).toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dua Wall',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: const Color(0xFF0F8254),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Share your duas and say Ameen for others.',
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDuaDialog,
        backgroundColor: colorScheme.primary,
        icon: const Icon(Icons.auto_awesome),
        label: const Text("Write a dua"),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDuaWall,
        child: _isLoading && visibleDuas.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : visibleDuas.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 48,
                    color: colorScheme.primary
                        .withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "No duas yet",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Be the first to write a dua and let others say Ameen 💚",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.primary
                          .withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        )
            : ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 20),
          itemCount: visibleDuas.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final dua = visibleDuas[index];
            final isMine = dua.userId == _currentUserId;
            final isAmeened = dua.userHasAmeened;
            final timeLabel = _formatTimeAgo(dua.createdAt);

            final String displayName =
            dua.isAnonymous && !isMine
                ? 'Anonymous'
                : dua.userName;

            final avatarInitial = displayName.isNotEmpty
                ? displayName.trim()[0].toUpperCase()
                : '?';

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // CARD (with internal stack for Ameen counter)
                Container(
                  margin: const EdgeInsets.only(bottom: 22),
                  child: Stack(
                    children: [
                      // Card background + content
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.secondary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                              color: Colors.black
                                  .withValues(alpha: 0.05),
                            ),
                          ],
                        ),
                        child: Padding(
                          // extra bottom padding so text doesn't overlap counter
                          padding: const EdgeInsets.fromLTRB(
                              14, 12, 14, 30),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              // Header: avatar + name + time
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: dua
                                        .isAnonymous &&
                                        !isMine
                                        ? colorScheme.primary
                                        .withValues(alpha: 0.1)
                                        : colorScheme.primary
                                        .withValues(alpha: 0.15),
                                    child: dua.isAnonymous &&
                                        !isMine
                                        ? Icon(
                                      Icons.nightlight_round,
                                      color:
                                      colorScheme.primary,
                                      size: 20,
                                    )
                                        : Text(
                                      avatarInitial,
                                      style: TextStyle(
                                        color: colorScheme
                                            .primary,
                                        fontWeight:
                                        FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                displayName,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight:
                                                  FontWeight.w600,
                                                  color:
                                                  colorScheme
                                                      .primary,
                                                ),
                                                overflow: TextOverflow
                                                    .ellipsis,
                                              ),
                                            ),
                                            if (dua.isPrivate) ...[
                                              const SizedBox(
                                                  width: 6),
                                              Container(
                                                padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration:
                                                BoxDecoration(
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                      999),
                                                  color: Colors
                                                      .orange
                                                      .withValues(
                                                      alpha:
                                                      0.08),
                                                ),
                                                child: const Text(
                                                  "Private",
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight:
                                                    FontWeight
                                                        .w600,
                                                    color: Colors
                                                        .orange,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          timeLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colorScheme.primary
                                                .withValues(
                                                alpha: 0.65),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Dua text
                              Text(
                                dua.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.95),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ❤️ Ameen counter bottom-right inside the card
                      Positioned(
                        right: 12,
                        bottom: 8,
                        child: Text(
                          dua.ameenCount == 0
                              ? "No Ameens yet"
                              : "${dua.ameenCount} Ameen${dua.ameenCount == 1 ? '' : 's'}",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.primary
                                .withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // DELETE ICON (only for your own duas)
                if (isMine)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                      ),
                      color:
                      Colors.red.withValues(alpha: 0.85),
                      onPressed: () => _confirmDeleteDua(dua),
                      tooltip: 'Delete dua',
                    ),
                  ),

                // FLOATING AMEEN BUTTON (half in / half out of the card)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -16, // half sticks out below the card
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          elevation: isAmeened ? 3 : 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          // 🌿 Solid subtle green when NOT Ameen'ed, deep green when Ameen'ed
                          backgroundColor: isAmeened
                              ? const Color(0xFF0F8254)
                              : const Color(0xFFE0F2EB),
                          foregroundColor: isAmeened
                              ? Colors.white
                              : colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(999),
                            side: isAmeened
                                ? BorderSide.none
                                : BorderSide(
                              color: colorScheme.primary
                                  .withValues(alpha: 0.35),
                              width: 1.3,
                            ),
                          ),
                        ),
                        icon: const Text(
                          '🤲',
                          style: TextStyle(fontSize: 21),
                        ),
                        label: const Text(
                          "Ameen",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => _toggleAmeen(dua),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
