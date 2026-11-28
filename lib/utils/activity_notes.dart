import '../models/activity_entry.dart';

List<ActivityEntry> filterNotesWithText(Iterable<ActivityEntry> entries) {
  return entries.where((entry) => entry.note.trim().isNotEmpty).toList();
}
