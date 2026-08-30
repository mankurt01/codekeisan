import 'package:flutter/material.dart';
import '../constants/fdp_limits.dart';
import '../widgets/neumorphic_card.dart';

class DutyTimeCalculatorScreen extends StatefulWidget {
  const DutyTimeCalculatorScreen({super.key});

  static const routeName = '/duty-time-calculator';

  @override
  State<DutyTimeCalculatorScreen> createState() => _DutyTimeCalculatorScreenState();
}

class _DutyTimeCalculatorScreenState extends State<DutyTimeCalculatorScreen> {
  TimeOfDay? _checkInTime;
  TimeOfDay? _checkOutTime;
  int _sectorCount = 2;
  String? _fdpLimit;
  Duration? _calculatedDutyTime;
  bool _isWithinLimits = true;

  // Available sector options
  final List<int> _sectorOptions = [1, 2, 3, 4, 5, 6];

  void _calculateDutyTime() {
    if (_checkInTime == null || _checkOutTime == null) {
      _showSnackBar('Lütfen giriş ve çıkış saatlerini seçin');
      return;
    }

    // Calculate duty time duration
    final checkInMinutes = _checkInTime!.hour * 60 + _checkInTime!.minute;
    final checkOutMinutes = _checkOutTime!.hour * 60 + _checkOutTime!.minute;

    int dutyMinutes;
    if (checkOutMinutes >= checkInMinutes) {
      dutyMinutes = checkOutMinutes - checkInMinutes;
    } else {
      // Handle overnight shifts (check-out is next day)
      dutyMinutes = (24 * 60 - checkInMinutes) + checkOutMinutes;
    }

    setState(() {
      _calculatedDutyTime = Duration(minutes: dutyMinutes);
    });

    _checkFdpLimits();
  }

  void _checkFdpLimits() {
    if (_checkInTime == null || _checkOutTime == null) return;

    // Determine the time range for FDP lookup
    final checkInMinutes = _checkInTime!.hour * 60 + _checkInTime!.minute;

    // Find the appropriate time range
    String timeRange = '';
    if (checkInMinutes >= 360 && checkInMinutes < 809) { // 06:00 - 13:29
      timeRange = "06:00 - 13:29";
    } else if (checkInMinutes >= 810 && checkInMinutes < 839) { // 13:30 - 13:59
      timeRange = "13:30 - 13:59";
    } else if (checkInMinutes >= 840 && checkInMinutes < 869) { // 14:00 - 14:29
      timeRange = "14:00 - 14:29";
    } else if (checkInMinutes >= 870 && checkInMinutes < 899) { // 14:30 - 14:59
      timeRange = "14:30 - 14:59";
    } else if (checkInMinutes >= 900 && checkInMinutes < 929) { // 15:00 - 15:29
      timeRange = "15:00 - 15:29";
    } else if (checkInMinutes >= 930 && checkInMinutes < 959) { // 15:30 - 15:59
      timeRange = "15:30 - 15:59";
    } else if (checkInMinutes >= 960 && checkInMinutes < 989) { // 16:00 - 16:29
      timeRange = "16:00 - 16:29";
    } else if (checkInMinutes >= 990 && checkInMinutes < 1019) { // 16:30 - 16:59
      timeRange = "16:30 - 16:59";
    } else if ((checkInMinutes >= 1020 && checkInMinutes <= 1439) || // 17:00 - 23:59
               (checkInMinutes >= 0 && checkInMinutes < 299)) {     // 00:00 - 04:59
      timeRange = "17:00 - 04:59";
    } else if (checkInMinutes >= 300 && checkInMinutes < 314) { // 05:00 - 05:14
      timeRange = "05:00 - 05:14";
    } else if (checkInMinutes >= 315 && checkInMinutes < 329) { // 05:15 - 05:29
      timeRange = "05:15 - 05:29";
    } else if (checkInMinutes >= 330 && checkInMinutes < 344) { // 05:30 - 05:44
      timeRange = "05:30 - 05:44";
    } else if (checkInMinutes >= 345 && checkInMinutes < 359) { // 05:45 - 05:59
      timeRange = "05:45 - 05:59";
    }

    if (timeRange.isNotEmpty && maxFdpTable.containsKey(timeRange)) {
      final limits = maxFdpTable[timeRange]!;
      if (_sectorCount <= limits.length) {
        setState(() {
          _fdpLimit = limits[_sectorCount - 1]; // 0-indexed array
        });

        // Check if duty time is within limits
        if (_calculatedDutyTime != null) {
          final limitDuration = _parseDuration(_fdpLimit!);
          setState(() {
            _isWithinLimits = _calculatedDutyTime! <= limitDuration;
          });
        }
      } else {
        setState(() {
          _fdpLimit = 'Sınır bulunamadı';
          _isWithinLimits = false;
        });
      }
    } else {
      setState(() {
        _fdpLimit = 'Zaman aralığı bulunamadı';
        _isWithinLimits = false;
      });
    }
  }

  Duration _parseDuration(String timeString) {
    final parts = timeString.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    return Duration(hours: hours, minutes: minutes);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFED6C02),
      ),
    );
  }

  Future<void> _selectCheckInTime() async {
    final TimeOfDay? picked = await _showDigitalTimePicker(
      context,
      initialTime: _checkInTime ?? TimeOfDay.now(),
      title: 'Check-in Saati Seçin',
    );

    if (picked != null && picked != _checkInTime) {
      setState(() {
        _checkInTime = picked;
      });
    }
  }

  Future<void> _selectCheckOutTime() async {
    final TimeOfDay? picked = await _showDigitalTimePicker(
      context,
      initialTime: _checkOutTime ?? TimeOfDay.now(),
      title: 'Check-out Saati Seçin',
    );

    if (picked != null && picked != _checkOutTime) {
      setState(() {
        _checkOutTime = picked;
      });
    }
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
              child: NeumorphicCard(
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: const Color(0xFFED6C02),
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
                      const SizedBox(height: 8),
                      Container(
                        height: 3,
                        width: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFFED6C02),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Time selectors row
                      Row(
                        children: [
                          // Hour selector
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
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color.fromRGBO(0, 0, 0, 0.4),
                                        offset: Offset(3, 3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                      BoxShadow(
                                        color: Color.fromRGBO(255, 255, 255, 0.15),
                                        offset: Offset(-3, -3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
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
                                        borderRadius: BorderRadius.circular(12),
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

                          // Time separator
                          Container(
                            width: 3,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(255, 255, 255, 0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Minute selector
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
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color.fromRGBO(0, 0, 0, 0.4),
                                        offset: Offset(3, 3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                      BoxShadow(
                                        color: Color.fromRGBO(255, 255, 255, 0.15),
                                        offset: Offset(-3, -3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
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
                                        borderRadius: BorderRadius.circular(12),
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

                      // Digital time display
                      NeumorphicCard(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.access_time,
                                color: const Color(0xFFFFA726),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFA726),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          NeumorphicCard(
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                child: const Text(
                                  'İptal',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          NeumorphicCard(
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(
                                TimeOfDay(hour: selectedHour, minute: selectedMinute),
                              ),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFED6C02),
                                      Color(0xFFFFA726),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
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
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 32),
              _buildTimeInputs(),
              const SizedBox(height: 32),
              _buildSectorSelector(),
              const SizedBox(height: 32),
              _buildCalculateButton(),
              const SizedBox(height: 32),
              if (_fdpLimit != null || _calculatedDutyTime != null) ...[
                _buildResults(),
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
            Icon(
              Icons.access_time,
              color: const Color(0xFFED6C02),
              size: 32,
            ),
            const SizedBox(width: 16),
            const Text(
              'Duty Time Hesaplama',
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
        Text(
          'Check-in ve check-out saatlerinizi girin. Uygulama FDP sınırlarını kontrol edecek ve maksimum çalışma saatinizi gösterecektir.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.white70,
            height: 1.5,
          ),
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
      ],
    );
  }

  Widget _buildTimeInputs() {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Use Column layout for smaller screens to prevent overflow
            if (constraints.maxWidth < 600) {
              return Column(
                children: [
                  NeumorphicCard(
                    child: InkWell(
                      onTap: _selectCheckInTime,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.login,
                                  color: const Color(0xFF157BA3),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Check-in Saati',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _checkInTime?.format(context) ?? 'Saat seçin',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _checkInTime != null
                                    ? const Color(0xFFFFA726)
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  NeumorphicCard(
                    child: InkWell(
                      onTap: _selectCheckOutTime,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.logout,
                                  color: const Color(0xFF157BA3),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Check-out Saati',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _checkOutTime?.format(context) ?? 'Saat seçin',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _checkOutTime != null
                                    ? const Color(0xFFFFA726)
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              // Use Row layout for larger screens
              return Row(
                children: [
                  Expanded(
                    child: NeumorphicCard(
                      child: InkWell(
                        onTap: _selectCheckInTime,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.login,
                                    color: const Color(0xFF157BA3),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Check-in Saati',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _checkInTime?.format(context) ?? 'Saat seçin',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _checkInTime != null
                                      ? const Color(0xFFFFA726)
                                      : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: NeumorphicCard(
                      child: InkWell(
                        onTap: _selectCheckOutTime,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.logout,
                                    color: const Color(0xFF157BA3),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Check-out Saati',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _checkOutTime?.format(context) ?? 'Saat seçin',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _checkOutTime != null
                                      ? const Color(0xFFFFA726)
                                      : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildSectorSelector() {
    return NeumorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flight,
                  color: const Color(0xFF924A1A),
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Sektör Sayısı',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _sectorOptions.map((sector) {
                final isSelected = _sectorCount == sector;
                return InkWell(
                  onTap: () => setState(() => _sectorCount = sector),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFED6C02)
                          : const Color.fromRGBO(255, 255, 255, 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFFA726)
                            : const Color.fromRGBO(255, 255, 255, 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        sector.toString(),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculateButton() {
    return Center(
      child: NeumorphicCard(
        child: InkWell(
          onTap: _calculateDutyTime,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 200,
            height: 60,
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
            ),
            child: const Center(
              child: Text(
                'HESAPLA',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        if (_calculatedDutyTime != null) ...[
          NeumorphicCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: _isWithinLimits ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Hesaplanan Çalışma Süresi',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatDuration(_calculatedDutyTime!),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _isWithinLimits
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFF44336),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_fdpLimit != null) ...[
          NeumorphicCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.rule,
                        color: const Color(0xFF924A1A),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'FDP Sınırı',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _fdpLimit!,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFFA726),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
