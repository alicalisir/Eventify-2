import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/suggestion_model.dart';
import '../../utils/app_logger.dart';

class FeedbackService {
  FeedbackService(this._supabase);

  final SupabaseClient _supabase;

  /// Returns the set of suggestion IDs the user has disliked (persisted in DB).
  Future<Set<String>> loadDislikedIds() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};
    try {
      final rows = await _supabase
          .from('user_feedback')
          .select('suggestion_id')
          .eq('user_id', userId)
          .eq('action', 'dislike');
      return {for (final r in rows as List) r['suggestion_id'] as String};
    } catch (e) {
      AppLogger.w('[FeedbackService] loadDislikedIds failed', e);
      return {};
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
