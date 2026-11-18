import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/weekly_report.dart';
import '../services/report_service.dart';
import 'food_log_provider.dart';

/// Your week, refreshed when the number of logged foods changes. Null when it
/// couldn't be loaded.
final weeklyReportProvider = FutureProvider.autoDispose<WeeklyReport?>((ref) {
  ref.watch(foodLogProvider.select((entries) => entries.length));
  return ReportService().weekly();
});
