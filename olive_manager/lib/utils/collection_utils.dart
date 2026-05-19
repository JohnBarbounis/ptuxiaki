// lib/utils/collection_utils.dart
// ✅ Utilities for filtering, sorting, and grouping collections

import '../models/olive_grove.dart';
import '../models/tasks.dart';
import '../models/harvest.dart';

class CollectionUtils {
  // ✅ Filter groves by date range
  static List<OliveGrove> filterGrovesByExpenseRange(
    List<OliveGrove> groves,
    DateTime startDate,
    DateTime endDate,
  ) {
    return groves.where((grove) {
      // Filter logic based on grove creation date or last modified
      return true; // Adjust based on your data model
    }).toList();
  }

  // ✅ Sort groves by profitability (high to low)
  static List<OliveGrove> sortByProfitability(
    List<OliveGrove> groves,
    Map<String, double> profitMap,
  ) {
    groves.sort((a, b) {
      final profitA = profitMap[a.id] ?? 0.0;
      final profitB = profitMap[b.id] ?? 0.0;
      return profitB.compareTo(profitA);
    });
    return groves;
  }

  // ✅ Group tasks by type
  static Map<String, List<Task>> groupTasksByType(List<Task> tasks) {
    final grouped = <String, List<Task>>{};
    for (final task in tasks) {
      grouped.putIfAbsent(task.type, () => []).add(task);
    }
    return grouped;
  }

  // ✅ Get upcoming tasks (within next N days)
  static List<Task> getUpcomingTasks(List<Task> tasks, int daysAhead) {
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: daysAhead));

    return tasks
        .where(
          (task) => task.date.isAfter(now) && task.date.isBefore(futureDate),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  // ✅ Get overdue tasks
  static List<Task> getOverdueTasks(List<Task> tasks) {
    final now = DateTime.now();
    return tasks.where((task) => task.date.isBefore(now)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // ✅ Calculate total by property
  static double calculateTotal<T>(List<T> items, double Function(T) selector) {
    return items.fold(0.0, (sum, item) => sum + selector(item));
  }

  // ✅ Group harvests by month
  static Map<String, List<Harvest>> groupHarvestsByMonth(
    List<Harvest> harvests,
  ) {
    final grouped = <String, List<Harvest>>{};
    for (final harvest in harvests) {
      final monthKey =
          '${harvest.date.year}-${harvest.date.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(monthKey, () => []).add(harvest);
    }
    return grouped;
  }

  // ✅ Get best performing grove (highest profit per stremma)
  static OliveGrove? getTopPerformingGrove(
    List<OliveGrove> groves,
    Map<String, double> profitPerStremmaMap,
  ) {
    if (groves.isEmpty) return null;

    OliveGrove? best;
    double maxProfit = -1;

    for (final grove in groves) {
      final profit = profitPerStremmaMap[grove.id] ?? 0.0;
      if (profit > maxProfit) {
        maxProfit = profit;
        best = grove;
      }
    }

    return best;
  }

  // ✅ Paginate list
  static List<T> paginate<T>(List<T> items, int page, int pageSize) {
    final start = page * pageSize;
    final end = (page + 1) * pageSize;

    if (start >= items.length) return [];
    return items.sublist(start, end.clamp(0, items.length));
  }

  // ✅ Remove duplicates from list
  static List<T> removeDuplicates<T>(
    List<T> items,
    Object Function(T) keyExtractor,
  ) {
    final seen = <Object>{};
    return items.where((item) => seen.add(keyExtractor(item))).toList();
  }
}
