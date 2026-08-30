import 'package:flutter/material.dart';

class TimePickerWidget extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final Function(TimeOfDay) onTimePicked;

  const TimePickerWidget({
    super.key,
    required this.label,
    required this.value,
    required this.onTimePicked,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await _showDigitalTimePicker(
          context,
          initialTime: value ?? TimeOfDay.now(),
          title: label,
        );
        if (picked != null) {
          onTimePicked(picked);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color.fromRGBO(255, 255, 255, 0.15),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Color(0xFFFFA726), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value != null ? value!.format(context) : label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<TimeOfDay?> _showDigitalTimePicker(
    BuildContext context, {
    required TimeOfDay initialTime,
    required String title,
  }) async {
    int selectedHour = initialTime.hour;
    int selectedMinute = initialTime.minute;

    return showDialog<TimeOfDay>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2D3E),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                width: 320,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Color(0xFFED6C02),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Text(
                                'Saat',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  color: const Color.fromRGBO(42, 45, 62, 0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color.fromRGBO(255, 255, 255, 0.1),
                                    width: 1.5,
                                  ),
                                ),
                                child: ListView.builder(
                                  itemCount: 24,
                                  itemBuilder: (context, index) {
                                    final hour = index;
                                    final isSelected = selectedHour == hour;
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          selectedHour = hour;
                                        });
                                      },
                                      child: Container(
                                        height: 45,
                                        alignment: Alignment.center,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFFED6C02)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          hour.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white70,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            children: [
                              const Text(
                                'Dakika',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  color: const Color.fromRGBO(42, 45, 62, 0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color.fromRGBO(255, 255, 255, 0.1),
                                    width: 1.5,
                                  ),
                                ),
                                child: ListView.builder(
                                  itemCount: 60,
                                  itemBuilder: (context, index) {
                                    final minute = index;
                                    final isSelected = selectedMinute == minute;
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          selectedMinute = minute;
                                        });
                                      },
                                      child: Container(
                                        height: 45,
                                        alignment: Alignment.center,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFFED6C02)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          minute.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white70,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'İptal',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(
                            TimeOfDay(hour: selectedHour, minute: selectedMinute),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFED6C02),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          child: const Text(
                            'Tamam',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
