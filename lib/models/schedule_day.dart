class ScheduleDay {
  final DateTime date;
  final String dayOfWeek;
  final List<String> events;

  ScheduleDay({
    required this.date,
    required this.dayOfWeek,
    required this.events,
  });
}
