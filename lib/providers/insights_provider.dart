import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/insights.dart';
import '../services/insights_service.dart';

class InsightsNotifier extends StateNotifier<AsyncValue<InsightsData>> {
  InsightsNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool refresh = false}) async {
    state = const AsyncValue.loading();
    try {
      final data = await InsightsService().fetchInsights(refresh: refresh);
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final insightsProvider =
    StateNotifierProvider<InsightsNotifier, AsyncValue<InsightsData>>(
  (ref) => InsightsNotifier(),
);