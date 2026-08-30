import 'package:flutter/material.dart';

class DatePickerWidget extends StatelessWidget {
  final String label;
  final DateTime? value;
  final Function(DateTime) onDatePicked;
  final bool enabled;

  const DatePickerWidget({
    super.key,
    required this.label,
    required this.value,
    required this.onDatePicked,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onDatePicked(picked);
        }
      } : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: enabled 
              ? const Color.fromRGBO(255, 255, 255, 0.05)
              : const Color.fromRGBO(255, 255, 255, 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color.fromRGBO(255, 255, 255, 0.15),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today, 
              color: enabled ? const Color(0xFFFFA726) : Colors.white30, 
              size: 20
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value != null
                    ? "${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}"
                    : label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  color: enabled ? Colors.white : Colors.white30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}