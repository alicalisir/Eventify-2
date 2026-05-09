import 'context_state.dart';
import 'persona_model.dart';
import 'place_model.dart';

/// Everything the LLM needs to generate personalised event suggestions.
///
/// Built by [LlmPromptBuilder] from live [ContextState] and [PersonaModel].
/// In Faz 3, [SuggestionRepository] will pass this to [LlmService].
class LlmContextPayload {
  const LlmContextPayload({
    required this.persona,
    required this.context,
    required this.nearbyPlaces,
    required this.builtAt,
  });

  final PersonaModel persona;
  final ContextState context;
  final List<PlaceModel> nearbyPlaces;
  final DateTime builtAt;
}
