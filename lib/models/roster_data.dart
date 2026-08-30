import 'package:cloud_firestore/cloud_firestore.dart';

class RosterData {
  final String id;
  final DateTime date;
  final int hoursWorked;
  final String shiftType; // e.g., 'Day', 'Night', 'Weekend'
  final String userId;
  final double? hourlyRate;

  RosterData({
    required this.id,
    required this.date,
    required this.hoursWorked,
    required this.shiftType,
    required this.userId,
    this.hourlyRate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': Timestamp.fromDate(date),
      'hoursWorked': hoursWorked,
      'shiftType': shiftType,
      'userId': userId,
      'hourlyRate': hourlyRate,
    };
  }

  factory RosterData.fromMap(Map<String, dynamic> map) {
    return RosterData(
      id: map['id'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      hoursWorked: map['hoursWorked'] ?? 0,
      shiftType: map['shiftType'] ?? 'Day',
      userId: map['userId'] ?? '',
      hourlyRate: map['hourlyRate']?.toDouble(),
    );
  }

  @override
  String toString() {
    return 'RosterData(id: $id, date: $date, hoursWorked: $hoursWorked, shiftType: $shiftType, userId: $userId, hourlyRate: $hourlyRate)';
  }

  double get estimatedEarnings {
    if (hourlyRate == null) return 0.0;
    return hourlyRate! * hoursWorked;
  }
}
