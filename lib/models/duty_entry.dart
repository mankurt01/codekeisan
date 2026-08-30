class DutyEntry {
  final String date;
  final List<String> duties;

  DutyEntry({required this.date, required this.duties});

  Map<String, dynamic> toJson() => {
    'date': date,
    'duties': duties,
  };

  factory DutyEntry.fromJson(Map<String, dynamic> json) {
    return DutyEntry(
      date: json['date'] as String,
      duties: List<String>.from(json['duties']),
    );
  }

  @override
  String toString() {
    return 'Date: $date\nDuties:\n${duties.join('\n')}\n';
  }
}
