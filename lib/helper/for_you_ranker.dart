import '../models/post.dart';

/// ✅ ForYouRanker
/// Keeps HomePage clean: it just asks for a ranked list.
/// This is a simple, explainable scoring algorithm (not ML).
///
/// You can tune the weights later without touching UI.
class ForYouRanker {
  /// Rank posts for the "For You" tab.
  ///
  /// Inputs are separated so you can keep your provider in charge of fetching,
  /// and keep ranking pure + testable.
  static List<Post> rank({
    required List<Post> candidates,

    /// current user id
    required String currentUserId,

    /// Users the current user follows
    required Set<String> followingIds,

    /// Users who are friends with current user
    required Set<String> friendIds,

    /// Map: postId -> set of users who liked it
    /// (If you don't have this yet, see the "data needed" section below.)
    required Map<String, Set<String>> likesByPostId,

    /// Optional: postId -> comment count, share count etc (if you have)
    Map<String, int> commentCountByPostId = const {},

    /// Optional: userId -> how much current user interacted with them before
    /// (likes/comments/dms/visits) — can be added later.
    Map<String, double> affinityByUserId = const {},

    /// Hard limit if you want
    int? limit,
  }) {
    final now = DateTime.now().toUtc();

    // 1) Filter out stuff you never want to show
    final filtered = List<Post>.from(candidates);

    // 2) Score each post
    final scored = <_ScoredPost>[];
    for (final p in filtered) {
      final score = _scorePost(
        post: p,
        nowUtc: now,
        currentUserId: currentUserId, // ✅ NEW
        followingIds: followingIds,
        friendIds: friendIds,
        likesByPostId: likesByPostId,
        commentCountByPostId: commentCountByPostId,
        affinityByUserId: affinityByUserId,
      );
      scored.add(_ScoredPost(p, score));
    }

    // 3) Sort by score desc
    // ✅ Deterministic tie-breakers to prevent "shuffling" on rebuilds
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;

      // newer first
      final byTime = b.post.createdAt.compareTo(a.post.createdAt);
      if (byTime != 0) return byTime;

      // stable fallback
      return b.post.id.compareTo(a.post.id);
    });

    // 4) Diversify (avoid too many from same author/community)
    // ✅ Keep your newest own post "pinned" on top BEFORE diversification,
    // so diversification cannot push it down.
    final pinned = _extractPinnedOwnNewestPost(
      scored.map((e) => e.post).toList(),
      currentUserId: currentUserId,
      nowUtc: now,
      pinWindow: const Duration(hours: 2), // tweak if you want (1-6h typical)
    );

    final diversified = _diversify(pinned.rest);

    final out = <Post>[
      if (pinned.pinned != null) pinned.pinned!,
      ...diversified,
    ];

    if (limit != null && out.length > limit) {
      return out.take(limit).toList();
    }
    return out;
  }

  static double _scorePost({
    required Post post,
    required DateTime nowUtc,

    // ✅ NEW
    required String currentUserId,

    required Set<String> followingIds,
    required Set<String> friendIds,
    required Map<String, Set<String>> likesByPostId,
    required Map<String, int> commentCountByPostId,
    required Map<String, double> affinityByUserId,
  }) {
    double score = 0;

    // --- 0) Small "own post" preference (so your post is very likely high)
    // (The actual "top pin" is handled separately so it stays on top.)
    final isOwnPost = post.userId == currentUserId;
    if (isOwnPost) score += 4.0;

    // --- 1) Strong personalization: friends/following likes
    final likers = likesByPostId[post.id] ?? const <String>{};

    final friendsWhoLiked = likers.where(friendIds.contains).length;
    final followingWhoLiked = likers.where(followingIds.contains).length;

    // Friends likes matter a lot
    score += friendsWhoLiked * 5.0;

    // Following likes matter, but less than friends
    score += followingWhoLiked * 2.5;

    // --- 2) Author relationship
    if (friendIds.contains(post.userId)) score += 6.0;
    if (followingIds.contains(post.userId)) score += 3.0;

    // Optional "affinity" (you can compute later)
    score += (affinityByUserId[post.userId] ?? 0) * 2.0;

    // --- 3) Popularity (global)
    // If you have likeCount/commentCount fields on Post, use those.
    // If not, use likers.length and commentCountByPostId.
    final likeCount = likers.length;
    final commentCount = commentCountByPostId[post.id] ?? 0;

    // Diminishing returns so viral posts don't fully dominate
    score += _log1p(likeCount.toDouble()) * 2.0;
    score += _log1p(commentCount.toDouble()) * 1.5;

    // --- 4) Recency boost (HIGH priority)
    final createdAt = post.createdAt.toUtc();
    final hoursOld = nowUtc.difference(createdAt).inMinutes / 60.0;

    // ✅ Stronger recency than before:
    // - higher weight (9.0 instead of 6.0)
    // - faster decay (half-life 18h instead of 24h)
    // This makes new posts rise faster without completely ignoring engagement.
    score += 9.0 * _expDecay(hoursOld, halfLifeHours: 18);

    // ✅ Extra “fresh” bonus for very recent posts (first 30 min / 2h)
    // This helps “just posted” content appear near the top immediately.
    if (hoursOld <= 0.5) {
      score += 4.0; // first 30 minutes
    } else if (hoursOld <= 2.0) {
      score += 2.0; // first 2 hours
    }

    return score;
  }

  /// Pull out the newest post by currentUserId (if within pinWindow)
  /// and return it as pinned + rest of list.
  static _PinnedResult _extractPinnedOwnNewestPost(
      List<Post> posts, {
        required String currentUserId,
        required DateTime nowUtc,
        required Duration pinWindow,
      }) {
    Post? newestOwn;
    int newestIndex = -1;

    for (int i = 0; i < posts.length; i++) {
      final p = posts[i];
      if (p.userId != currentUserId) continue;

      if (newestOwn == null ||
          p.createdAt.isAfter(newestOwn!.createdAt)) {
        newestOwn = p;
        newestIndex = i;
      }
    }

    if (newestOwn == null) {
      return _PinnedResult(pinned: null, rest: posts);
    }

    final age = nowUtc.difference(newestOwn.createdAt.toUtc());

    // Only pin if it’s "recently posted"
    if (age > pinWindow) {
      return _PinnedResult(pinned: null, rest: posts);
    }

    final rest = List<Post>.from(posts);
    rest.removeAt(newestIndex);

    return _PinnedResult(pinned: newestOwn, rest: rest);
  }

  static List<Post> _diversify(List<Post> sorted) {
    // Simple diversification:
    // - avoid showing many consecutive posts by same author
    // - avoid too many consecutive posts from same community
    final result = <Post>[];

    String? lastAuthor;
    String? lastCommunity;
    int authorStreak = 0;
    int communityStreak = 0;

    final pool = List<Post>.from(sorted);

    while (pool.isNotEmpty) {
      int pickIndex = 0;

      // Try to find a post that breaks streaks
      for (int i = 0; i < pool.length; i++) {
        final p = pool[i];

        final sameAuthor = (lastAuthor != null && p.userId == lastAuthor);
        final sameCommunity =
        (lastCommunity != null && p.communityId == lastCommunity);

        final wouldBreakAuthor = !sameAuthor || authorStreak < 1;
        final wouldBreakCommunity = !sameCommunity || communityStreak < 2;

        if (wouldBreakAuthor && wouldBreakCommunity) {
          pickIndex = i;
          break;
        }
      }

      final picked = pool.removeAt(pickIndex);
      result.add(picked);

      if (picked.userId == lastAuthor) {
        authorStreak++;
      } else {
        lastAuthor = picked.userId;
        authorStreak = 0;
      }

      if (picked.communityId != null && picked.communityId == lastCommunity) {
        communityStreak++;
      } else {
        lastCommunity = picked.communityId;
        communityStreak = 0;
      }
    }

    return result;
  }

  static double _log1p(double x) {
    // log(1 + x) approximation without dart:math (keeps file lightweight)
    // Good enough for ranking weights.
    // For more precise, import dart:math and use log(1 + x).
    // Using a simple series for small x and fallback for larger.
    if (x <= 0) return 0;
    if (x < 1) return x - (x * x) / 2;
    // rough: ln(1+x) ~ ln(x) + small => do a cheap approximation
    // We'll just use a monotonic sqrt-ish curve:
    return (x).sqrtApprox();
  }

  static double _expDecay(double hoursOld, {required double halfLifeHours}) {
    // score multiplier = 0.5^(hoursOld/halfLife)
    if (hoursOld <= 0) return 1.0;
    final k = hoursOld / halfLifeHours;
    return _powHalf(k);
  }

  static double _powHalf(double k) {
    // approx 0.5^k using exp2 approximation: 2^-k
    // Keep it simple: piecewise based on k.
    if (k <= 0) return 1.0;
    if (k >= 10) return 0.0;
    // crude but monotonic
    double v = 1.0;
    final steps = (k * 8).clamp(1, 80).toInt();
    final step = k / steps;
    for (int i = 0; i < steps; i++) {
      // 0.5^step ~ 1 - step*ln(2) for small step
      v *= (1 - step * 0.693).clamp(0.0, 1.0);
    }
    return v;
  }
}

class _ScoredPost {
  final Post post;
  final double score;
  const _ScoredPost(this.post, this.score);
}

class _PinnedResult {
  final Post? pinned;
  final List<Post> rest;
  const _PinnedResult({required this.pinned, required this.rest});
}

/// Small extension to avoid importing dart:math
extension _SqrtApprox on double {
  double sqrtApprox() {
    // Newton's method quick sqrt approximation
    if (this <= 0) return 0;
    double x = this;
    double r = this;
    for (int i = 0; i < 6; i++) {
      r = 0.5 * (r + x / r);
    }
    return r;
  }
}
