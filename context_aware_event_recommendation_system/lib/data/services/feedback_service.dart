import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/suggestion_model.dart';
import '../../utils/app_logger.dart';

class FeedbackService {
  FeedbackService(this._supabase);

  final SupabaseClient _supabase;

  /// Returns suggestion IDs the user has dismissed (one-way, no undo across sessions).
  Future<Set<String>> loadDismissedIds(String userId) async {
    try {
      final rows = await _supabase
          .from('user_feedback')
          .select('suggestion_id')
          .eq('user_id', userId)
          .eq('action', 'dismiss');
      return {for (final r in rows as List) r['suggestion_id'] as String};
    } catch (e) {
      AppLogger.w('[FeedbackService] loadDismissedIds failed', e);
      return {};
    }
  }

  /// Returns suggestion IDs the user has disliked, respecting re-likes (latest action wins).
  Future<Set<String>> loadDislikedIds() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};
    try {
      final rows = await _supabase
          .from('user_feedback')
          .select('suggestion_id, action')
          .eq('user_id', userId)
          .inFilter('action', ['like', 'dislike'])
          .order('created_at');
      final Set<String> disliked = {};
      for (final r in rows as List) {
        final id = r['suggestion_id'] as String;
        if (r['action'] == 'dislike') {
          disliked.add(id);
        } else if (r['action'] == 'like') {
          disliked.remove(id);
        }
      }
      return disliked;
    } catch (e) {
      AppLogger.w('[FeedbackService] loadDislikedIds failed', e);
      return {};
    }
  }

  /// Returns liked and disliked history for the preferences screen.
  /// Latest action per suggestion wins.
  Future<({List<Map<String, dynamic>> liked, List<Map<String, dynamic>> disliked})>
      loadFeedbackHistory() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return (liked: <Map<String, dynamic>>[], disliked: <Map<String, dynamic>>[]);
    try {
      final rows = await _supabase
          .from('user_feedback')
          .select('suggestion_id, action, suggestion_snapshot, created_at')
          .eq('user_id', userId)
          .inFilter('action', ['like', 'dislike'])
          .order('created_at');
      // Latest action per suggestion_id wins
      final Map<String, Map<String, dynamic>> latest = {};
      for (final r in rows as List) {
        latest[r['suggestion_id'] as String] = Map<String, dynamic>.from(r as Map);
      }
      final liked = <Map<String, dynamic>>[];
      final disliked = <Map<String, dynamic>>[];
      for (final e in latest.values) {
        if (e['action'] == 'like') liked.add(e);
        else if (e['action'] == 'dislike') disliked.add(e);
      }
      // Most recent first
      liked.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      disliked.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      return (liked: liked, disliked: disliked);
    } catch (e) {
      AppLogger.w('[FeedbackService] loadFeedbackHistory failed', e);
      return (liked: <Map<String, dynamic>>[], disliked: <Map<String, dynamic>>[]);
    }
  }

  Future<void> logAction({
    required String suggestionId,
    required String action,
    required SuggestionModel suggestion,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      AppLogger.w('[FeedbackService] $action skipped — no authenticated user');
      return;
    }
    try {
      await _supabase.from('user_feedback').insert({
        'user_id': userId,
        'suggestion_id': suggestionId,
        'action': action,
        if (suggestion.eventId != null) 'event_id': suggestion.eventId,
        'suggestion_snapshot': {
          'id': suggestion.id,
          'title': suggestion.title,
          'category': suggestion.category,
          'rationale': suggestion.rationale,
          'rationale_signals': suggestion.tags,
          'match_score': null,
        },
      });
      AppLogger.d('[FeedbackService] $action logged for "${suggestion.title}"');
    } catch (e) {
      AppLogger.w('[FeedbackService] $action log failed', e);
    }
  }
}
