// Helper classes for event-based duty calculation
enum DutyEventType { report, release }

class DutyEvent {
  final DutyEventType type;
  final int time; // minutes from 00:00
  final int index; // position in text
  final String rawTime;

  DutyEvent({
    required this.type,
    required this.time,
    required this.index,
    required this.rawTime,
  });
}
