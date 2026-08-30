import 'package:cloud_firestore/cloud_firestore.dart';

class LayoverEvent {
  final String id;
  final DateTime checkOutTime;
  final DateTime layoverStartTime; // 30 minutes after checkout
  final DateTime reportingTime;
  final double allowanceMultiplier; // 1.0, 0.5, or 0.0
  final bool isInternational;
  final String location;
  final String userId;
  final DateTime date; // Date of the layover

  LayoverEvent({
    required this.id,
    required this.checkOutTime,
    required this.layoverStartTime,
    required this.reportingTime,
    required this.allowanceMultiplier,
    required this.isInternational,
    required this.location,
    required this.userId,
    required this.date,
  });

  // Calculate layover duration in hours
  Duration get layoverDuration {
    return reportingTime.difference(layoverStartTime);
  }

  // Calculate payment amount based on allowance and type
  double get paymentAmount {
    final baseRate = isInternational ? 50.0 : 30.0; // €50 international, €30 domestic
    return baseRate * allowanceMultiplier;
  }

  // Get layover type description
  String get layoverType {
    if (allowanceMultiplier == 1.0) return 'Full Day';
    if (allowanceMultiplier == 0.5) return 'Half Day';
    return 'No Allowance';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'checkOutTime': Timestamp.fromDate(checkOutTime),
      'layoverStartTime': Timestamp.fromDate(layoverStartTime),
      'reportingTime': Timestamp.fromDate(reportingTime),
      'allowanceMultiplier': allowanceMultiplier,
      'isInternational': isInternational,
      'location': location,
      'userId': userId,
      'date': Timestamp.fromDate(date),
    };
  }

  factory LayoverEvent.fromMap(Map<String, dynamic> map) {
    return LayoverEvent(
      id: map['id'] ?? '',
      checkOutTime: (map['checkOutTime'] as Timestamp).toDate(),
      layoverStartTime: (map['layoverStartTime'] as Timestamp).toDate(),
      reportingTime: (map['reportingTime'] as Timestamp).toDate(),
      allowanceMultiplier: (map['allowanceMultiplier'] ?? 0.0).toDouble(),
      isInternational: map['isInternational'] ?? false,
      location: map['location'] ?? '',
      userId: map['userId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
    );
  }

  @override
  String toString() {
    return 'LayoverEvent(id: $id, location: $location, allowance: ${layoverType}, payment: €${paymentAmount.toStringAsFixed(2)})';
  }

  // Create layover from checkout and reporting times
  static LayoverEvent createFromTimes({
    required String id,
    required DateTime checkOutTime,
    required DateTime reportingTime,
    required bool isInternational,
    required String location,
    required String userId,
  }) {
    final layoverStartTime = checkOutTime.add(const Duration(minutes: 30));
    final allowanceMultiplier = _calculateAllowanceMultiplier(reportingTime);
    
    return LayoverEvent(
      id: id,
      checkOutTime: checkOutTime,
      layoverStartTime: layoverStartTime,
      reportingTime: reportingTime,
      allowanceMultiplier: allowanceMultiplier,
      isInternational: isInternational,
      location: location,
      userId: userId,
      date: DateTime(layoverStartTime.year, layoverStartTime.month, layoverStartTime.day),
    );
  }

  // Calculate allowance multiplier based on reporting time
  static double _calculateAllowanceMultiplier(DateTime reportingTime) {
    final hour = reportingTime.hour;
    final minute = reportingTime.minute;
    final decimalTime = hour + (minute / 60);

    if (decimalTime <= 10.0) {
      return 1.0; // Full allowance
    } else if (decimalTime <= 17.0) {
      return 0.5; // Half allowance
    } else {
      return 0.0; // No allowance
    }
  }
}