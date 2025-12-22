import '../models/user_profile.dart';

/// ✅ UserSearchRanker
/// Scores search candidates so the list feels "smart":
/// - friends first
/// - friends-of-friends next
/// - following next
/// - then best textual match (username > name > city/country)
class UserSearchRanker {
  static List<UserProfile> rank({
    required List<UserProfile> candidates,
    required String currentUserId,
    required String query,
    required Set<String> friendIds,
    required Set<String> friendsOfFriendsIds,
    required Set<String> followingIds,
    int? limit,
  }) {
    final q = query.trim().toLowerCase();

    final scored = <_ScoredUser>[];
    for (final u in candidates) {
      if (u.id == currentUserId) continue;

      final s = _score(
        user: u,
        q: q,
        friendIds: friendIds,
        foafIds: friendsOfFriendsIds,
        followingIds: followingIds,
      );

      // DB is the filter; ranker is only ordering.
      scored.add(_ScoredUser(u, s));
    }

    // ✅ Deterministic sorting (no shuffling on rebuilds)
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;

      // Prefer the stronger textual match if scores tie
      final aText = _textMatchScore(a.user, q);
      final bText = _textMatchScore(b.user, q);
      final byText = bText.compareTo(aText);
      if (byText != 0) return byText;

      // Stable human-friendly
      final byName = a.user.name.toLowerCase().compareTo(b.user.name.toLowerCase());
      if (byName != 0) return byName;

      // Stable fallback
      return a.user.id.compareTo(b.user.id);
    });

    final out = scored.map((e) => e.user).toList();

    if (limit != null && out.length > limit) return out.take(limit).toList();
    return out;
  }

  static double _score({
    required UserProfile user,
    required String q,
    required Set<String> friendIds,
    required Set<String> foafIds,
    required Set<String> followingIds,
  }) {
    double score = 0;

    final id = user.id;
    final name = user.name.trim().toLowerCase();
    final username = user.username.trim().toLowerCase(); // ✅ not nullable in your model
    final city = (user.city ?? '').trim().toLowerCase();
    final country = user.country.trim().toLowerCase();

    // --- Relationship boosts (dominant)
    if (friendIds.contains(id)) {
      score += 80;
    } else if (foafIds.contains(id)) {
      score += 55;
    } else if (followingIds.contains(id)) {
      score += 35;
    }

    // --- Query match quality (username strongest)
    score += _textMatchScore(user, q);

    return score;
  }

  /// Text relevance score used in both main score and tie-breaking.
  /// Keeps ordering stable + “feels right”.
  static double _textMatchScore(UserProfile user, String q) {
    if (q.isEmpty) return 0;

    double score = 0;

    final name = user.name.trim().toLowerCase();
    final username = user.username.trim().toLowerCase(); // ✅ not nullable
    final city = (user.city ?? '').trim().toLowerCase();
    final country = user.country.trim().toLowerCase();

    // Exact username match: "@tasx" or "tasx"
    final qNoAt = q.startsWith('@') ? q.substring(1) : q;

    if (username == qNoAt) {
      score += 70;
    } else if (username.startsWith(qNoAt)) {
      score += 45;
    } else if (username.contains(qNoAt)) {
      score += 25;
    }

    // Name match
    if (name == q) {
      score += 35;
    } else if (name.startsWith(q)) {
      score += 22;
    } else if (name.contains(q)) {
      score += 12;
    }

    // City/Country match (lighter)
    if (city == q) {
      score += 18;
    } else if (city.startsWith(q)) {
      score += 12;
    } else if (city.contains(q)) {
      score += 7;
    }

    if (country == q) {
      score += 14;
    } else if (country.startsWith(q)) {
      score += 9;
    } else if (country.contains(q)) {
      score += 5;
    }

    // Bonus: multi-token match (e.g. "rotterdam nl")
    final parts = q.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      int hits = 0;
      for (final p in parts) {
        if (username.contains(p) || name.contains(p) || city.contains(p) || country.contains(p)) {
          hits++;
        }
      }
      score += hits * 6.0;
    }

    return score;
  }
}

class _ScoredUser {
  final UserProfile user;
  final double score;
  const _ScoredUser(this.user, this.score);
}
