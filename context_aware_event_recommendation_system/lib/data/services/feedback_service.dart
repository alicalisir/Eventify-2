import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/suggestion_model.dart';
import '../../utils/app_logger.dart';

class FeedbackService {
  FeedbackService(this._supabase);

  final SupabaseClient _supabase;

  Future<void> logAction({
    required String suggestionId,
    required String action,
    required SuggestionModel suggestion,
  }) async {
    try {
      await _supabase.from('user_feedback').insert({
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
