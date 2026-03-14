import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'friends_page.dart';
import 'groups_page.dart';
import 'create_group_page.dart';
import 'communities_page.dart';
import 'search_page.dart';
import '../services/database/database_provider.dart';

class ChatTabsPage extends StatefulWidget {
  const ChatTabsPage({super.key});

  @override
  State<ChatTabsPage> createState() => _ChatTabsPageState();
}

class _ChatTabsPageState extends State<ChatTabsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _currentFabLabel() {
    if (_tabController.index == 0) return "Find people".tr();
    if (_tabController.index == 1) return "New group".tr();
    return "Add community".tr();
  }

  IconData _currentFabIcon() {
    if (_tabController.index == 0) return Icons.person_search;
    if (_tabController.index == 1) return Icons.group_add;
    return Icons.group_add;
  }

  Future<void> _onFabPressed() async {
    if (_tabController.index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SearchPage(),
        ),
      );
      return;
    }

    if (_tabController.index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CreateGroupPage(),
        ),
      );
      return;
    }

    await _showAddCommunityDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onFabPressed,
        icon: Icon(_currentFabIcon()),
        label: Text(_currentFabLabel()),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 6,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.surface,
              cs.surface,
              cs.surfaceContainerLowest,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: _PremiumChatsHeader(
                  title: "Chats".tr(),
                  subtitle: "Stay connected with friends, groups, and communities."
                      .tr(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _PremiumTabBar(
                  controller: _tabController,
                  tabs: [
                    "Friends".tr(),
                    "Groups".tr(),
                    "Communities".tr(),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: const [
                    FriendsPage(),
                    GroupsPage(),
                    CommunitiesPage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddCommunityDialog(BuildContext context) async {
    final db = Provider.of<DatabaseProvider>(context, listen: false);

    final nameController = TextEditingController();
    final descController = TextEditingController();
    final countryController = TextEditingController();

    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isPrivate = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: cs.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Create community'.tr(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PremiumDialogField(
                      controller: nameController,
                      label: 'Name'.tr(),
                    ),
                    const SizedBox(height: 12),
                    _PremiumDialogField(
                      controller: descController,
                      label: 'Description'.tr(),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _PremiumDialogField(
                      controller: countryController,
                      label: 'Country'.tr(),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainer,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Private community'.tr(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            value: isPrivate,
                            onChanged: (v) => setState(() => isPrivate = v),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'private_community_hint'.tr(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.68),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Cancel'.tr()),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final desc = descController.text.trim();
                    final country = countryController.text.trim();

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(dialogCtx).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please enter a name for your community.'.tr(),
                          ),
                        ),
                      );
                      return;
                    }

                    await db.createCommunity(
                      name,
                      desc,
                      country,
                      isPrivate: isPrivate,
                    );

                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                  },
                  child: Text('Create'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PremiumChatsHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PremiumChatsHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.14),
            cs.secondary.withValues(alpha: 0.55),
            cs.surfaceContainerHigh,
          ],
        ),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.14),
            ),
            child: Icon(
              Icons.forum_rounded,
              color: cs.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.72),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;

  const _PremiumTabBar({
    required this.controller,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        labelColor: cs.onPrimary,
        unselectedLabelColor: cs.onSurface.withValues(alpha: 0.72),
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        tabs: tabs
            .map(
              (tab) => Tab(
            height: 42,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(tab),
            ),
          ),
        )
            .toList(),
      ),
    );
  }
}

class _PremiumDialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;

  const _PremiumDialogField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: cs.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: cs.primary,
            width: 1.2,
          ),
        ),
      ),
    );
  }
}