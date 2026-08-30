import 'package:cloud_firestore/cloud_firestore.dart';

class SalaryData {
  final String id;
  final double amount;
  final DateTime date;
  final int hoursWorked;
  final String userId;
  double? totalEarnings;

  SalaryData({
    required this.id,
    required this.amount,
    required this.date,
    required this.hoursWorked,
    required this.userId,
    this.totalEarnings,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'hoursWorked': hoursWorked,
      'userId': userId,
      'totalEarnings': totalEarnings ?? amount,
    };
  }

  factory SalaryData.fromMap(Map<String, dynamic> map) {
    return SalaryData(
      id: map['id'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      hoursWorked: map['hoursWorked'] ?? 0,
      userId: map['userId'] ?? '',
      totalEarnings: (map['totalEarnings'] ?? map['amount'] ?? 0.0).toDouble(),
    );
  }

  @override
  String toString() {
    return 'SalaryData(id: $id, amount: $amount, date: $date, hoursWorked: $hoursWorked, userId: $userId)';
  }
}
