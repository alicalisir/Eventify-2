import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:context_aware_event_recommendation_system/data/services/context_service.dart';
import 'package:context_aware_event_recommendation_system/domain/models/suggestion_model.dart';
import 'package:context_aware_event_recommendation_system/domain/models/persona_model.dart';
import 'package:context_aware_event_recommendation_system/domain/models/context_state.dart';

final contextServiceProvider = Provider((ref) => ContextService());

final suggestionProvider = FutureProvider<List<SuggestionModel>>((ref) async {
  return ref.watch(contextServiceProvider).getSuggestions();
});

final contextProvider = FutureProvider<ContextState>((ref) async {
  return ref.watch(contextServiceProvider).getCurrentContext();
});

final personaProvider = FutureProvider<PersonaModel>((ref) async {
  return ref.watch(contextServiceProvider).getUserPersona();
});
