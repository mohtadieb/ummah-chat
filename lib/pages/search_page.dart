import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/my_user_tile.dart';
import '../components/my_search_bar.dart';
import '../models/user.dart';
import '../services/database/database_provider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // providers
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

  /// Debounced search logic:
  /// - waits 350ms after user stops typing
  /// - if query is empty: clears results + reset UI state
  /// - if query has text: triggers provider search
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

        setState(() {
          _isSearching = false;
        });
      } else {
        listeningProvider.clearSearchResults();
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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              "Find people",
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "Search all users on Ummah Chat",
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          children: [
            // 🔍 Rounded search bar (shared MySearchBar component)
            MySearchBar(
              controller: _searchController,
              hintText: 'Search users',
              onChanged: (value) {
                // Use debounced search logic from _onSearchChanged
                _onSearchChanged(value);
              },
              onClear: () {
                // Clear search results + reset state when user taps the clear icon
                listeningProvider.clearSearchResults();
                setState(() {
                  _hasSearched = false;
                  _isSearching = false;
                });
              },
            ),

            const SizedBox(height: 12),

            // 🔽 Results / empty states
            Expanded(
              child: _buildBodyContent(colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the body content:
  /// - "Searching..." state
  /// - "No users found" state
  /// - "Start typing" helper
  /// - or the actual result list
  Widget _buildBodyContent(ColorScheme colorScheme) {
    if (_isSearching) {
      return Center(
        child: Text(
          "Searching...",
          style: TextStyle(color: colorScheme.primary),
        ),
      );
    }

    if (_hasSearched && listeningProvider.searchResults.isEmpty) {
      return Center(
        child: Text(
          "No users found",
          style: TextStyle(color: colorScheme.primary),
        ),
      );
    }

    // Results list
    final results = listeningProvider.searchResults;

    if (results.isEmpty && !_hasSearched) {
      return Center(
        child: Text(
          "Start typing to search for people",
          style: TextStyle(
            color: colorScheme.primary.withValues(alpha: 0.75),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final UserProfile user = results[index];
        return MyUserTile(
          user: user,
          customTitle: user.name,
        );
      },
    );
  }
}
