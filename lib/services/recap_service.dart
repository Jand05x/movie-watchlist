import '../models/recap.dart';
import 'review_service.dart';

class RecapService {
  static Future<RecapStats> currentMonth({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final start = DateTime(current.year, current.month);
    final end = DateTime(current.year, current.month + 1);

    final reviews = await ReviewService.inMonth(start, end);
    return computeRecap(reviews, current);
  }
}
