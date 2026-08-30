import 'package:flutter/material.dart';

class Duty {
  DateTime? date;
  TimeOfDay? checkIn;
  TimeOfDay? checkOut;
  String type;

  Duty({
    this.date,
    this.checkIn,
    this.checkOut,
    this.type = 'Normal',
  });

  DateTime? get checkInDateTime {
    if (date == null || checkIn == null) return null;
    return DateTime(
      date!.year,
      date!.month,
      date!.day,
      checkIn!.hour,
      checkIn!.minute,
    );
  }

  DateTime? get checkOutDateTime {
    if (date == null || checkOut == null) return null;
    return DateTime(
      date!.year,
      date!.month,
      date!.day,
      checkOut!.hour,
      checkOut!.minute,
    );
  }
}
