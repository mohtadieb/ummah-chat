import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/my_user_tile.dart';
import '../components/my_search_bar.dart';
import '../models/user_profile.dart';
import '../services/database/database_provider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final DatabaseProvider databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);
  late final DatabaseProvider listeningProvider =
  Provider.of<DatabaseProvider>(context);

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final query = value.trim();

      if (query.isNotEmpty) {
        setState(() {
          _isSearching = true;
          _hasSearched = true;
        });

        await databaseProvider.searchUsers(query);

        if (!mounted) return;
        setState(() {
          _isSearching = false;
        });
      } else {
        listeningProvider.clearSearchResults();
        if (!mounted) return;
        setState(() {
          _isSearching = false;
          _hasSearched = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final results = listeningProvider.searchResults;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
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
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Column(
              children: [
                _buildIntroCard(colorScheme),
                const SizedBox(height: 14),

                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: MySearchBar(
                    controller: _searchController,
                    hintText: 'search_users'.tr(),
                    onChanged: (value) {
                      _onSearchChanged(value);
                    },
                    onClear: () {
                      _searchController.clear();
                      listeningProvider.clearSearchResults();
                      setState(() {
                        _hasSearched = false;
                        _isSearching = false;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 14),

                if (_hasSearched && !_isSearching && results.isNotEmpty) ...[
                  _buildResultsHeader(colorScheme, results.length),
                  const SizedBox(height: 10),
                ],
                Expanded(
                  child: _buildBodyContent(colorScheme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.14),
            colorScheme.secondary.withValues(alpha: 0.55),
            colorScheme.surfaceContainerHigh,
          ],
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
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
              color: colorScheme.primary.withValues(alpha: 0.14),
            ),
            child: Icon(
              Icons.person_search_rounded,
              color: colorScheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Discover".tr(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Find people".tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Search by name or username to find people across Ummah Chat."
                      .tr(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
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

  Widget _buildResultsHeader(ColorScheme colorScheme, int count) {
    return Row(
      children: [
        Text(
          "Results".tr(),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBodyContent(ColorScheme colorScheme) {
    final results = listeningProvider.searchResults;

    if (_isSearching) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Searching...".tr(),
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasSearched && results.isEmpty) {
      return Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: 0.10),
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "No users found".tr(),
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Try a different name or username.".tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.primary.withValues(alpha: 0.72),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (results.isEmpty && !_hasSearched) {
      return Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: 0.10),
                ),
                child: Icon(
                  Icons.manage_search_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Start typing to search for people".tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "You can search by full name or username.".tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.primary.withValues(alpha: 0.72),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ScrollConfiguration(
      behavior: const _NoStretchScrollBehavior(),
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 14),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final UserProfile user = results[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MyUserTile(
              user: user,
              customTitle: user.name,
            ),
          );
        },
      ),
    );
  }
}

class _NoStretchScrollBehavior extends ScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}