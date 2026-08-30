import 'package:flutter/material.dart';
import '../models/duty_model.dart';
import '../models/legality_result.dart';
import '../widgets/neumorphic_card.dart';
import '../services/ftl_checker_service.dart';

// Models are imported from separate model files
// FTL Checker Service is imported from separate service file

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
                  color: value != null ? Colors.white : Colors.white60,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

class ShgmFtlScreen extends StatefulWidget {
  const ShgmFtlScreen({super.key});

  static const routeName = '/shgmFtl';

  @override
  State<ShgmFtlScreen> createState() => _ShgmFtlScreenState();
}

class _ShgmFtlScreenState extends State<ShgmFtlScreen> {
  DateTime? _notificationDateTime;
  DateTime? _previousDutyCheckOut;
  String _restLocation = 'Home Base';
  final Duty _currentDuty = Duty(type: 'Normal');
  final Duty _newDuty = Duty(type: 'Normal');
  bool _sameDate = false;
  LegalityResult? _result;

  final List<String> _dutyTypes = ['Normal', 'SBY', 'RZV'];
  final List<String> _restLocations = ['Home Base', 'Layover'];

  void _checkLegality() {
    if (_notificationDateTime == null ||
        _currentDuty.date == null ||
        _currentDuty.checkIn == null ||
        _currentDuty.checkOut == null ||
        _newDuty.date == null ||
        _newDuty.checkIn == null ||
        _newDuty.checkOut == null) {
      _showSnackBar('Please fill all required fields');
      return;
    }

    final result = FTLCheckerService.checkDutyChangeLegality(
      notificationTime: _notificationDateTime!,
      currentDuty: _currentDuty,
      newDuty: _newDuty,
      previousDutyCheckOut: _previousDutyCheckOut,
      restLocation: _restLocation,
      isExtension: false, // Default: duty replacement (new duty replaces current duty)
    );

    setState(() {
      _result = result;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFED6C02),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildNotificationSection(),
              const SizedBox(height: 24),
              _buildRestPeriodSection(),
              const SizedBox(height: 24),
              _buildCurrentDutySection(),
              const SizedBox(height: 24),
              _buildNewDutySection(),
              const SizedBox(height: 32),
              _buildCheckButton(),
              if (_result != null) ...[
                const SizedBox(height: 24),
                _buildResultSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.assignment_turned_in,
              color: Color(0xFFED6C02),
              size: 32,
            ),
            const SizedBox(width: 16),
            const Text(
              'SHGM FTL Checker',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 4,
          width: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFED6C02),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Check if your duty change is legal according to SHGM FTL regulations and company rules.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSection() {
    return NeumorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications, color: Color(0xFF924A1A), size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Notification Time',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Saati GMT olarak giriniz(Yerel Saat-3) ',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _notificationDateTime ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (date != null && mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null && mounted) {
                    setState(() {
                      _notificationDateTime = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  }
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                    const Icon(Icons.event, color: Color(0xFFFFA726), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _notificationDateTime != null
                            ? "${_notificationDateTime!.year}-${_notificationDateTime!.month.toString().padLeft(2, '0')}-${_notificationDateTime!.day.toString().padLeft(2, '0')} ${_notificationDateTime!.hour.toString().padLeft(2, '0')}:${_notificationDateTime!.minute.toString().padLeft(2, '0')}"
                            : "Select notification date & time",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          color: _notificationDateTime != null 
                              ? Colors.white 
                              : Colors.white60,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestPeriodSection() {
    return NeumorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bed, color: Color(0xFF4A5568), size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Rest Period Details',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Previous duty checkout time and location type for accurate rest calculation',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 16),
            
            // Location Type Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  const Icon(Icons.location_on, color: Color(0xFFFFA726), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _restLocation,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF22243A),
                      iconEnabledColor: const Color(0xFFFFA726),
                      underline: const SizedBox(),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        color: Colors.white,
                      ),
                      items: _restLocations.map((location) {
                        return DropdownMenuItem(
                          value: location,
                          child: Text(location),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _restLocation = val!;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Previous Duty C/O DateTime
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _previousDutyCheckOut ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (date != null && mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _previousDutyCheckOut != null
                        ? TimeOfDay.fromDateTime(_previousDutyCheckOut!)
                        : TimeOfDay.now(),
                  );
                  if (time != null && mounted) {
                    setState(() {
                      _previousDutyCheckOut = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  }
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                    const Icon(Icons.flight_takeoff, color: Color(0xFFFFA726), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Previous Duty C/O',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _previousDutyCheckOut != null
                                ? "${_previousDutyCheckOut!.year}-${_previousDutyCheckOut!.month.toString().padLeft(2, '0')}-${_previousDutyCheckOut!.day.toString().padLeft(2, '0')} ${_previousDutyCheckOut!.hour.toString().padLeft(2, '0')}:${_previousDutyCheckOut!.minute.toString().padLeft(2, '0')}"
                                : "Select previous duty checkout (optional)",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              color: _previousDutyCheckOut != null
                                  ? Colors.white
                                  : Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_previousDutyCheckOut != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                        onPressed: () {
                          setState(() {
                            _previousDutyCheckOut = null;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 193, 7, 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color.fromRGBO(255, 193, 7, 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Color(0xFFFFC107), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _previousDutyCheckOut != null
                          ? 'Using actual previous duty checkout time for rest calculation'
                          : 'If not provided, current duty end time will be used for rest calculation',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Color(0xFFFFC107),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentDutySection() {
    return NeumorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.work_outline, color: Color(0xFF157BA3), size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Current Duty',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Your currently assigned duty details',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 16),
            _buildDutyTypeDropdown(
              value: _currentDuty.type,
              onChanged: (val) {
                setState(() {
                  _currentDuty.type = val!;
                });
              },
            ),
            const SizedBox(height: 16),
            DatePickerWidget(
              label: 'Duty Date',
              value: _currentDuty.date,
              onDatePicked: (date) {
                setState(() {
                  _currentDuty.date = date;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TimePickerWidget(
                    label: 'Check-in',
                    value: _currentDuty.checkIn,
                    onTimePicked: (time) {
                      setState(() {
                        _currentDuty.checkIn = time;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TimePickerWidget(
                    label: 'Check-out',
                    value: _currentDuty.checkOut,
                    onTimePicked: (time) {
                      setState(() {
                        _currentDuty.checkOut = time;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewDutySection() {
    return NeumorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.update, color: Color(0xFF924A1A), size: 24),
                const SizedBox(width: 12),
                const Text(
                  'New Duty',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'The new duty you are being assigned to',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 16),
            _buildDutyTypeDropdown(
              value: _newDuty.type,
              onChanged: (val) {
                setState(() {
                  _newDuty.type = val!;
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _sameDate,
                  onChanged: (val) {
                    setState(() {
                      _sameDate = val ?? false;
                      if (_sameDate && _currentDuty.date != null) {
                        _newDuty.date = _currentDuty.date;
                      }
                    });
                  },
                  activeColor: const Color(0xFFED6C02),
                  checkColor: Colors.white,
                ),
                const Text(
                  'Same date as current duty',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DatePickerWidget(
              label: 'Duty Date',
              value: _sameDate ? _currentDuty.date : _newDuty.date,
              enabled: !_sameDate,
              onDatePicked: (date) {
                if (!_sameDate) {
                  setState(() {
                    _newDuty.date = date;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TimePickerWidget(
                    label: 'Check-in',
                    value: _newDuty.checkIn,
                    onTimePicked: (time) {
                      setState(() {
                        _newDuty.checkIn = time;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TimePickerWidget(
                    label: 'Check-out',
                    value: _newDuty.checkOut,
                    onTimePicked: (time) {
                      setState(() {
                        _newDuty.checkOut = time;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDutyTypeDropdown({
    required String value,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.15),
          width: 1.2,
        ),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: const Color(0xFF22243A),
        iconEnabledColor: const Color(0xFFFFA726),
        underline: const SizedBox(),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 15,
          color: Colors.white,
        ),
        items: _dutyTypes.map((type) {
          String displayText = type;
          if (type == 'SBY') displayText = 'SBY (Standby)';
          if (type == 'RZV') displayText = 'RZV (Reserve)';
          
          return DropdownMenuItem(
            value: type,
            child: Text(displayText),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCheckButton() {
    return Center(
      child: NeumorphicCard(
        child: InkWell(
          onTap: _checkLegality,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 280,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFED6C02),
                  Color(0xFFFFA726),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFED6C02).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Check Legality',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    if (_result == null) return const SizedBox();

    Color statusColor;
    IconData statusIcon;

    if (_result!.type == 'success') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (_result!.type == 'warning') {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    }

    return Column(
      children: [
        // Summary Card
        NeumorphicCard(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor.withValues(alpha: 0.2),
                  statusColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 48,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _result!.isLegal ? 'LEGAL' : 'NOT LEGAL',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _result!.summary,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Individual Checks
        ...(_result!.checks.map((check) => _buildCheckCard(check)).toList()),
      ],
    );
  }

  Widget _buildCheckCard(LegalityCheck check) {
    Color statusColor;
    IconData statusIcon;

    if (check.status == 'pass') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
    } else if (check.status == 'warning') {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel_outlined;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeumorphicCard(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    statusIcon,
                    color: statusColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      check.rule,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                check.message,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 255, 255, 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFFFFA726),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      check.reference,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Color(0xFFFFA726),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


