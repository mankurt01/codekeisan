import 'package:flutter/material.dart';
import '../models/schedule_day.dart';

/// Full-screen roster calendar opened from the PDF upload results header.
///
/// Receives the already-parsed schedule from [PdfUploadScreen]'s analysis
/// result so the calendar mirrors what was uploaded instead of showing an
/// empty placeholder screen.
class RosterTakvimiScreen extends StatefulWidget {
  final Map<DateTime, ScheduleDay> schedule;
  final Map<DateTime, String> dailyDuties;
  final DateTime? firstDate;

  const RosterTakvimiScreen({
    super.key,
    this.schedule = const {},
    this.dailyDuties = const {},
    this.firstDate,
  });

  @override
  State<RosterTakvimiScreen> createState() => _RosterTakvimiScreenState();
}

class _RosterTakvimiScreenState extends State<RosterTakvimiScreen> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    // Start on the roster's first month; fall back to the earliest parsed
    // day, then to the current month.
    DateTime initial;
    if (widget.firstDate != null) {
      initial = widget.firstDate!;
    } else if (widget.schedule.isNotEmpty) {
      final sorted = widget.schedule.keys.toList()
        ..sort((a, b) => a.compareTo(b));
      initial = sorted.first;
    } else {
      initial = DateTime.now();
    }
    _visibleMonth = DateTime(initial.year, initial.month, 1);
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1);
    });
  }

  String _getMonthName(int month) {
    const names = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    if (month < 1 || month > 12) return '';
    return names[month - 1];
  }

  /// Finds the ScheduleDay for a given calendar date by comparing
  /// year/month/day (map keys may carry arbitrary time components).
  ScheduleDay? _findDay(DateTime date) {
    for (final k in widget.schedule.keys) {
      if (k.year == date.year && k.month == date.month && k.day == date.day) {
        return widget.schedule[k];
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Explicit dark background — the global theme uses a light colorScheme
      // while body text defaults to white, so default surfaces would render
      // white-on-white (invisible) without this.
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Roster Takvimi',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: widget.schedule.isEmpty ? _buildEmptyState() : _buildCalendar(),
    );
  }

  /// Visible fallback when the screen is opened without parsed roster data.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_busy, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            'Görüntülenecek roster verisi yok',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              color: Colors.white.withAlpha(179),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Önce bir ICS/PDF roster dosyası yükleyin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Lato',
              fontSize: 13,
              color: Colors.white.withAlpha(102),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final daysInMonth =
        DateUtils.getDaysInMonth(_visibleMonth.year, _visibleMonth.month);
    // Monday-based grid offset (1 = Mon ... 7 = Sun)
    final monthStartedOn = _visibleMonth.weekday;
    final totalSlots = daysInMonth + (monthStartedOn - 1);

    return Column(
      children: [
        // Month header with prev/next navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Color(0xFFED6C02)),
                tooltip: 'Önceki Ay',
                onPressed: () => _changeMonth(-1),
              ),
              Text(
                '${_getMonthName(_visibleMonth.month)} ${_visibleMonth.year}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon:
                    const Icon(Icons.chevron_right, color: Color(0xFFED6C02)),
                tooltip: 'Sonraki Ay',
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
        ),
        _buildMonthlySummary(),
        const SizedBox(height: 8),
        // Weekday names header (Monday start)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Pts', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']
                .map((d) => Text(d,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Poppins',
                        fontSize: 12)))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Day grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.62, // Taller cells for duties
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: totalSlots,
            itemBuilder: (context, index) {
              if (index < monthStartedOn - 1) return const SizedBox();

              final dayNum = index - (monthStartedOn - 1) + 1;
              final currentDate =
                  DateTime(_visibleMonth.year, _visibleMonth.month, dayNum);
              final dayData = _findDay(currentDate);
              final dutyTime = widget.dailyDuties[dayData?.date] ?? '';

              return _buildDayCell(dayNum, dayData, dutyTime);
            },
          ),
        ),
      ],
    );
  }

  /// Summary strip: counts of FLY / SBY / OFF days and total duty hours
  /// for the currently viewed month.
  Widget _buildMonthlySummary() {
    int flyDays = 0, standbyDays = 0, offDays = 0;
    int totalDutyMinutes = 0;

    for (final day in widget.schedule.values) {
      if (day.date.year != _visibleMonth.year ||
          day.date.month != _visibleMonth.month) {
        continue;
      }
      final events = day.events;
      final isOff = events.any((e) => e.contains('OFF'));
      final isStandby = events.any((e) => e.contains('SB'));
      final isFly = events.any((e) =>
          (e.contains('XQ') || e.contains('TK') || e.contains('~')) &&
          !isOff &&
          !isStandby);

      if (isOff) {
        offDays++;
      } else if (isStandby) {
        standbyDays++;
      } else if (isFly) {
        flyDays++;
      }

      // Accumulate duty time from Report/Release intervals
      String? reportTime, releaseTime;
      for (final event in events) {
        if (event.contains('Report')) {
          final m = RegExp(r'(\d{1,2}:\d{2})').firstMatch(event);
          if (m != null) reportTime = m.group(1);
        }
        if (event.contains('Release')) {
          final m = RegExp(r'(\d{1,2}:\d{2})').firstMatch(event);
          if (m != null) releaseTime = m.group(1);
        }
      }
      if (reportTime != null && releaseTime != null) {
        final sp = reportTime.split(':');
        final ep = releaseTime.split(':');
        if (sp.length == 2 && ep.length == 2) {
          final start =
              (int.tryParse(sp[0]) ?? 0) * 60 + (int.tryParse(sp[1]) ?? 0);
          final end =
              (int.tryParse(ep[0]) ?? 0) * 60 + (int.tryParse(ep[1]) ?? 0);
          int diff = end - start;
          if (diff < 0) diff += 24 * 60; // release after midnight
          totalDutyMinutes += diff;
        }
      }
    }

    final dutyH = totalDutyMinutes ~/ 60;
    final dutyM = totalDutyMinutes % 60;
    final dutyStr =
        '${dutyH.toString().padLeft(2, '0')}:${dutyM.toString().padLeft(2, '0')}';

    Widget chip(Color color, String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(38),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(128)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              '$label $value',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          chip(Colors.orange, 'Uçuş', '$flyDays'),
          chip(Colors.amber, 'SBY', '$standbyDays'),
          chip(Colors.green, 'İzin', '$offDays'),
          chip(Colors.lightBlue, 'Görev', dutyStr),
        ],
      ),
    );
  }
  /// A single calendar day cell, color-coded by day type:
  /// OFF -> green, SBY -> amber, flight/duty -> orange, empty -> neutral.
  Widget _buildDayCell(int day, ScheduleDay? data, String dutyTime) {
    bool isOff = false;
    bool isStandby = false;
    bool isFly = false;
    String mainEvent = '';

    if (data != null) {
      // OFF days take priority
      isOff = data.events.any((e) => e.contains('OFF'));
      // Standby days (SB1/SB2/SB3)
      isStandby = data.events.any((e) => e.contains('SB'));
      // FLY / duty days (XQ/TK flight legs or ~ intervals)
      isFly = data.events.any((e) =>
          (e.contains('XQ') || e.contains('TK') || e.contains('~')) &&
          !isOff &&
          !isStandby);

      if (isOff) {
        mainEvent = 'OFF';
      } else if (isStandby) {
        final sbEvent = data.events
            .firstWhere((e) => e.contains('SB'), orElse: () => 'SBY');
        mainEvent = sbEvent.split(' ').take(2).join(' ');
      } else {
        final firstRelevant = data.events.firstWhere(
            (e) =>
                !e.contains('Report') &&
                !e.contains('Release') &&
                !e.startsWith('~') &&
                !e.startsWith('📅'),
            orElse: () => data.events.isNotEmpty ? data.events.first : '');
        mainEvent = firstRelevant.split(' ').take(2).join(' ');
      }
    }

    Color cellColor, cellBorder, textColor;
    if (isOff) {
      cellColor = Colors.green.withAlpha(64);
      cellBorder = Colors.green.withAlpha(128);
      textColor = Colors.greenAccent;
    } else if (isStandby) {
      cellColor = Colors.amber.withAlpha(64);
      cellBorder = Colors.amber.withAlpha(128);
      textColor = Colors.amberAccent;
    } else if (isFly) {
      cellColor = Colors.orange.withAlpha(64);
      cellBorder = Colors.orange.withAlpha(128);
      textColor = const Color(0xFFFFA726);
    } else {
      cellColor = Colors.white.withAlpha(13);
      cellBorder = Colors.white.withAlpha(31);
      textColor = Colors.white70;
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: cellBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Day Number
          Text(
            '$day',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                fontSize: 11),
          ),
          const SizedBox(height: 2),
          // Main Event
          if (mainEvent.isNotEmpty)
            Flexible(
              child: Text(
                mainEvent,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontSize: 9),
              ),
            ),
          // Bottom: Duty Time
          if (dutyTime.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4)),
              child: Text(
                dutyTime,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFFFFA726),
                    fontSize: 8,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
