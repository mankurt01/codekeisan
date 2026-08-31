import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/ics_parser_service.dart';
import '../models/schedule_day.dart';
import '../models/pdf_result.dart';
import '../services/data_service.dart';
import '../widgets/neumorphic_card.dart';
import '../screens/welcome_screen.dart' hide NeumorphicCard;
import 'roster_calendar_screen.dart';

class PdfUploadScreen extends StatefulWidget {
  const PdfUploadScreen({super.key});

  @override
  State<PdfUploadScreen> createState() => _PdfUploadScreenState();
}

class _PdfUploadScreenState extends State<PdfUploadScreen>
    with TickerProviderStateMixin {
  final IcsParserService _icsParserService = IcsParserService();
  bool _isLoading = false;
  Map<String, dynamic>? _analysisResult;
  late AnimationController _uploadAnimationController;
  late AnimationController _resultAnimationController;

  @override
  void initState() {
    super.initState();
    _uploadAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _resultAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _uploadAnimationController.dispose();
    _resultAnimationController.dispose();
    super.dispose();
  }

  // PDF test and parsing methods removed

  Future<void> _pickAndAnalyzeIcs() async {
    try {
      debugPrint('Starting file picker...');
      
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['ics'],
      );

      debugPrint('File picker result: $file');
      
      if (file != null) {
        debugPrint('File selected: ${file.name}');
        
        setState(() {
          _isLoading = true;
          _analysisResult = null;
        });

        _uploadAnimationController.forward();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Processing: ${file.name}',
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
              ),
              backgroundColor: const Color(0xFF157BA3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        final fileBytes = await file.readAsBytes();
        debugPrint('File bytes available: ${fileBytes.length} bytes');

        // Keep the raw ICS text so the Roster Calendar screen can re-parse
        // the roster (hotel/transport details) directly from the source file.
        String rawIcsText = '';
        try {
          rawIcsText = utf8.decode(fileBytes, allowMalformed: true);
        } catch (_) {
          rawIcsText = '';
        }
        List<ScheduleDay> schedule = await _icsParserService.parseIcs(fileBytes);
        
        debugPrint('Parsing completed: ${schedule.length} days');
        
        // Roster ownership check: the first imported ICS binds its RELCALID to
        // this device; imports carrying a different id are rejected.
        final ownsRoster = await _icsParserService.verifyRosterOwnership();
        if (!ownsRoster) {
          debugPrint('[DEBUG] Roster ownership check FAILED '
              '(file RELCALID=${_icsParserService.lastRelcalId})');
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _analysisResult = null;
          });
          _uploadAnimationController.reset();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Roster size ait değil. Sadece kendi rosterınızla işlem yapabilirsiniz!',
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
              ),
              backgroundColor: const Color(0xFFD32F2F),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }
        
         // Convert to analysis result format
        final analysisResult = await _convertScheduleToAnalysis(schedule);
        
        // Sanitize analysisResult to make it JSON-encodable for history storage.
        // fullSchedule/dailyDuties are DateTime-keyed maps (not JSON-encodable),
        // so rebuild them as plain lists under calendarSchedule/calendarDailyDuties
        // which _openRosterCalendar() in roster_history_screen.dart reads back.
        final sanitizedData = Map<String, dynamic>.from(analysisResult);
        sanitizedData.remove('fullSchedule');
        sanitizedData.remove('dailyDuties');
        sanitizedData.remove('firstDate');

        final fullSch = analysisResult['fullSchedule']
            as Map<DateTime, ScheduleDay>?;
        final dutyMap =
            analysisResult['dailyDuties'] as Map<DateTime, String>?;
        sanitizedData['calendarSchedule'] = <Map<String, dynamic>>[
          for (final e in (fullSch ?? const <DateTime, ScheduleDay>{}).entries)
            {
              'date': e.key.toIso8601String(),
              'dayOfWeek': e.value.dayOfWeek,
              'events': List<String>.from(e.value.events),
            },
        ];
        sanitizedData['calendarDailyDuties'] = <Map<String, dynamic>>[
          for (final e in (dutyMap ?? const <DateTime, String>{}).entries)
            {'date': e.key.toIso8601String(), 'duty': e.value},
        ];

        // Save to roster history
        final pdfResult = PdfResult(
          fileName: file.name,
          date: DateTime.now(),
          data: sanitizedData,
          rawText: rawIcsText.isEmpty ? null : rawIcsText,
        );
        await DataService().saveRosterToHistory(pdfResult);
        
        setState(() {
          _analysisResult = analysisResult;
          _isLoading = false;
        });

        _uploadAnimationController.reset();
        _resultAnimationController.forward();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Analysis completed! Found ${schedule.length} schedule days',
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
              ),
              backgroundColor: const Color(0xFF924A1A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error in _pickAndAnalyzeIcs: $e');
      debugPrint('Stack trace: $stackTrace');
      
      setState(() {
        _isLoading = false;
      });
      _uploadAnimationController.reset();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: const Color(0xFFFF5722),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Removed duplicate _convertScheduleToAnalysis


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
        ),
        title: ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [
                Color(0xFFED6C02),
                Color(0xFFFFA726),
                Color(0xFFED6C02),
              ],
              stops: [0.0, 0.5, 1.0],
              tileMode: TileMode.mirror,
            ).createShader(bounds);
          },
          child: const Text(
            'ROSTER YÜKLE',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Color(0xFF924A1A),
                  blurRadius: 4,
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const ParallaxBackgroundShapes(),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromRGBO(21, 123, 163, 0.9),
                  Color.fromRGBO(146, 74, 26, 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Upload section
                    NeumorphicCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            _buildUploadIcon(),
                            const SizedBox(height: 16),
                            Text(
                              'Roster Analizi (PDF & ICS)',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
                            const SizedBox(height: 8),
                            Text(
                              'Roster PDF veya ICS dosyanızı yükleyin ve otomatik olarak uçuş saatleri, görev süreleri ve diğer verileri analiz edin.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ).animate().fadeIn(delay: 400.ms),
                            const SizedBox(height: 24),
                            _buildActionButtons(),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.8, 0.8)),
                    
                    const SizedBox(height: 16),
                    
                    // Results section
                    if (_isLoading)
                      _buildLoadingSection()
                    else if (_analysisResult != null)
                      Expanded(child: _buildResultsSection()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadIcon() {
    return AnimatedBuilder(
      animation: _uploadAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _isLoading ? 1.0 + (_uploadAnimationController.value * 0.1) : 1.0,
          child: Transform.rotate(
            angle: _isLoading ? _uploadAnimationController.value * 2 * 3.14159 : 0,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFED6C02), Color(0xFFFFA726)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFED6C02).withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _isLoading ? Icons.sync : Icons.upload_file,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildPrimaryButton(
          'ICS Dosyası Seç',
          Icons.file_upload,
          _isLoading ? null : _pickAndAnalyzeIcs,
          const Color(0xFFED6C02),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String text, IconData icon, VoidCallback? onPressed, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 8,
          shadowColor: color.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.3);
  }

  Widget _buildLoadingSection() {
    return NeumorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFED6C02)),
              strokeWidth: 3,
            ).animate(onPlay: (controller) => controller.repeat()).rotate(duration: 2.seconds),
            const SizedBox(height: 24),
            Text(
              'Dosya Analiz Ediliyor...',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ).animate(onPlay: (controller) => controller.repeat()).fadeIn(duration: 1.seconds),
            const SizedBox(height: 8),
            const Text(
              'İçerik çıkarılıyor ve analiz ediliyor...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8));
  }

  // Removed duplicate _buildResultsSection


  Widget _buildResultRow(String label, String value, IconData icon, int delayMs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFED6C02), Color(0xFFFFA726)],
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFA726),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(controller: _resultAnimationController).fadeIn(delay: Duration(milliseconds: delayMs)).slideX(begin: -0.3);
  }

  /// Convert ScheduleDay list to analysis result format for UI display
  Future<Map<String, dynamic>> _convertScheduleToAnalysis(List<ScheduleDay> schedule) async {
    // Fetch the crew's selected home base for layover determination
    final homeBase = await DataService().getBaseSelection() ?? 'AYT';
    
    if (schedule.isEmpty) {
      return {
        'totalFlightTime': 'N/A',
        'totalDutyTime': 'N/A',
        'nightHours': 'N/A',
        'rosterPeriod': 'N/A',
        'layoverCount': 0,
        'internationalLayoverCount': 0,
        'domesticLayoverCount': 0,
        'flightCounts': {'3': 0, '4': 0, '5': 0},
        'offDays': [],
        'fullSchedule': <DateTime, ScheduleDay>{}, 
      };
    }

    // Calculate accurate total duty time using the parser service
    // Use ICS parser's duty time calculation
    final accurateTotalDutyTime = _icsParserService.calculateTotalDutyTime(schedule);
    
    // Sort schedule by date
    schedule.sort((a, b) => a.date.compareTo(b.date));

    // Calculate daily duty times map
    // Key: Date, Value: Duration String
    final dailyDuties = <DateTime, String>{};
    for (var day in schedule) {
        // Need to calculate duty for this specific day using similar logic to calculateTotalDutyTime
        // but isolated to just this day's events.
        
        // However, calculateTotalDutyTime expects a full list.
        // Let's do a quick calculation here or reuse a service method if available.
        // Since we don't have a public per-day method, we can implement a simple one here or extract it.
        // For visual simplicity, let's parse "Report" and "Release" times in the day's events.
        
        String? reportTime;
        String? releaseTime;
        
        for (var event in day.events) {
           if (event.contains('Report')) {
              final match = RegExp(r'(\d{1,2}:\d{2})').firstMatch(event);
              if (match != null) reportTime = match.group(1);
           }
           if (event.contains('Release')) {
              final match = RegExp(r'(\d{1,2}:\d{2})').firstMatch(event);
              if (match != null) releaseTime = match.group(1);
           }
        }
        
        // DEBUG: trace daily report/release extraction
        debugPrint('[DEBUG] _convertScheduleToAnalysis: day=${day.date} events=${day.events} '
            'reportTime=$reportTime releaseTime=$releaseTime');
        
        if (reportTime != null && releaseTime != null) {
            // Calc diff
            try {
               final start = _timeToMinutes(reportTime);
               final end = _timeToMinutes(releaseTime);
               int diff = end - start;
               if (diff < 0) diff += 24 * 60; // Date crossover
               
               final h = diff ~/ 60;
               final m = diff % 60;
               final dutyStr = '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}';
               dailyDuties[day.date] = dutyStr;
               debugPrint('[DEBUG] _convertScheduleToAnalysis: day=${day.date} '
                   'report=$reportTime release=$releaseTime diff=${diff}min => $dutyStr');
            } catch (e) {
               dailyDuties[day.date] = ''; 
               debugPrint('[DEBUG] _convertScheduleToAnalysis: day=${day.date} ERROR $e');
            }
        } else {
             dailyDuties[day.date] = '';
             debugPrint('[DEBUG] _convertScheduleToAnalysis: day=${day.date} MISSING report/release '
                 '(report=$reportTime release=$releaseTime)');
        }

        debugPrint('[DEBUG] _convertScheduleToAnalysis: day=${day.date} dailyDuties=${dailyDuties[day.date]}');
    }
    
    // Create Date -> ScheduleDay map for easy lookup
    final scheduleMap = {for (var item in schedule) item.date: item};

    // ... (Existing stats calculation) ...
    // Count OFF days
    final offDays = schedule.where((day) =>
      day.events.any((event) => event.toUpperCase().contains('OFF'))).toList();
    
    // Count flight days
    final flightDays = schedule.where((day) =>
      day.events.any((event) => event.contains('XQ') || event.contains('TK'))).toList();
      
    final dutyDays = schedule.where((day) =>
      day.events.any((event) => event.contains('Report') || event.contains('Release'))).toList();
      
    final standbyDays = schedule.where((day) =>
      day.events.any((event) => event.contains('SB'))).toList();

    // Determine layover count using combined rules:
    //   - Airport cross-reference (does the pairing end at home base?)
    //   - Time-based rules (report time + post-duty release time)
    //   - Continuity (a day off in between doesn't reset)
    //   - Domestic vs international classification (using turkishAirportCodes)
    final layoverResult = _icsParserService.computeLayoverCount(schedule, homeBase);

    // Determine roster period
    final firstDate = schedule.first.date;
    // ... rest of header logic ...
     final monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    // The roster period is named after the calendar month that holds the
    // majority of the schedule days. Even when the actual duty days spill over
    // from the previous month or into the next one (e.g. 31 Jul - 30 Aug), the
    // period is normalized to the full first-to-last day of that month so the
    // naming stays stable regardless of the exact first/last duty date.
    final Map<String, int> monthCounts = {};
    for (final day in schedule) {
      final key = '${day.date.year}-${day.date.month}';
      monthCounts[key] = (monthCounts[key] ?? 0) + 1;
    }
    final dominantKey = monthCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    final dominantParts = dominantKey.split('-');
    final dominantYear = int.parse(dominantParts[0]);
    final dominantMonth = int.parse(dominantParts[1]);
    final daysInMonth = DateTime(dominantYear, dominantMonth + 1, 0).day;

    final rosterPeriod = '01'
        '${monthNames[dominantMonth]}'
        '${dominantYear.toString().substring(2)}-'
        '${daysInMonth.toString().padLeft(2, '0')}'
        '${monthNames[dominantMonth]}'
        '${dominantYear.toString().substring(2)}';
        
    int count3 = 0;
    int count4 = 0;
    int count5 = 0;
    
    for (final day in schedule) {
      final flightsOnDay = day.events.where((event) => 
        event.contains('XQ') || event.contains('TK')
      ).length;
      
      if (flightsOnDay == 3) {
        count3++;
      } else if (flightsOnDay == 4) {
        count4++;
      } else if (flightsOnDay >= 5) {
        count5++;
      }
    }
        
    // Calculate actual total flight (block) time by summing flight leg intervals
    // Flight events look like: "XQ570 02:53 ~ 06:44 AYT-CPH"
    // Deadhead legs (e.g. "XQ7647 12:44 ~ 14:04 GZT-AYT DEADHEAD") are excluded.
    int totalFlightMinutes = 0;
    for (final day in schedule) {
      for (final event in day.events) {
        // Skip deadhead legs
        if (event.contains('DEADHEAD') || event.contains(' DH ')) continue;
        // Match flight legs: airline + number + HH:MM ~ HH:MM + airports
        final match = RegExp(
          r'([A-Z]{2}\d+)\s+(\d{2}:\d{2})\s*~\s*(\d{2}:\d{2})\s+[A-Z]{3}-[A-Z]{3}',
        ).firstMatch(event);
        if (match != null) {
          final dep = _timeToMinutes(match.group(2)!);
          final arr = _timeToMinutes(match.group(3)!);
          int diff = arr - dep;
          if (diff < 0) diff += 24 * 60;
          totalFlightMinutes += diff;
          debugPrint('[DEBUG] _convertScheduleToAnalysis: flight="$event" '
              'block=${diff}min');
        }
      }
    }
    final flightH = totalFlightMinutes ~/ 60;
    final flightM = totalFlightMinutes % 60;
    final actualFlightTime =
        '${flightH.toString().padLeft(2, '0')}:${flightM.toString().padLeft(2, '0')}';
    debugPrint('[DEBUG] _convertScheduleToAnalysis: totalFlightMinutes=$totalFlightMinutes '
        '=> $actualFlightTime');

    // Calculate total night minutes: overlap of each DUTY PERIOD
    // [report, release] with the 22:00–03:00 UTC night window. Night time
    // includes report and release times — i.e. it is measured over the whole
    // duty interval, not just flight block times. The window wraps midnight,
    // so each duty day can touch two instances of it:
    //   W1 = [1320, 1620) -> 22:00 this day .. 03:00 next day
    //   W2 = [-120, 180)  -> 22:00 prev day .. 03:00 this day
    //
    // Standby days follow the same rule as duty time: only 25% of the
    // standby window's night overlap counts.
    int totalNightMinutes = 0;
    for (final day in schedule) {
      final isStandbyDay = day.events.any((e) => e.contains('SB'));
      int dayNightMinutes = 0;

      if (isStandbyDay) {
        // SBY: sum night overlap of every standby window, then credit 25%
        // — mirroring calculateTotalDutyTime's standby handling.
        int standbyWindowNight = 0;
        for (final event in day.events) {
          final m = RegExp(r'(\d{2}:\d{2})\s*[-~]\s*(\d{2}:\d{2})')
              .firstMatch(event);
          if (m == null) continue;
          final start = _timeToMinutes(m.group(1)!);
          var end = _timeToMinutes(m.group(2)!);
          if (end < start) end += 24 * 60; // window crossed midnight

          int sbyOverlapWith(int winStart, int winEnd) {
            final s = start > winStart ? start : winStart;
            final e = end < winEnd ? end : winEnd;
            return s < e ? e - s : 0;
          }

          standbyWindowNight += sbyOverlapWith(22 * 60, 27 * 60); // W1
          standbyWindowNight += sbyOverlapWith(-2 * 60, 3 * 60); // W2
        }
        dayNightMinutes = (standbyWindowNight * 0.25).round();
        debugPrint('[DEBUG] _convertScheduleToAnalysis: NIGHT day=${day.date} '
            'STANDBY window-night=$standbyWindowNight '
            'credit(25%)=${dayNightMinutes}min');
      } else {
        String? reportTime;
        String? releaseTime;
        for (final event in day.events) {
          if (event.contains('Report') || event.contains('Check-in')) {
            final m = RegExp(r'(\d{1,2}:\d{2})').firstMatch(event);
            if (m != null) reportTime = m.group(1);
          }
          if (event.contains('Release')) {
            final m = RegExp(r'(\d{1,2}:\d{2})').firstMatch(event);
            if (m != null) releaseTime = m.group(1);
          }
        }
        if (reportTime == null || releaseTime == null) continue;

        final repMins = _timeToMinutes(reportTime);
        final relMins = _timeToMinutes(releaseTime);
        // Unwrap: release after midnight => interval extends past 24:00
        final relUnwrapped =
            (relMins < repMins) ? relMins + 24 * 60 : relMins;

        int dutyOverlapWith(int winStart, int winEnd) {
          final s = repMins > winStart ? repMins : winStart;
          final e = relUnwrapped < winEnd ? relUnwrapped : winEnd;
          return s < e ? e - s : 0;
        }

        dayNightMinutes =
            dutyOverlapWith(22 * 60, 27 * 60) + // W1: tonight
            dutyOverlapWith(-2 * 60, 3 * 60); // W2: early morning
        debugPrint('[DEBUG] _convertScheduleToAnalysis: NIGHT day=${day.date} '
            'report=$reportTime release=$releaseTime '
            'overlap=${dayNightMinutes}min');
      }

      totalNightMinutes += dayNightMinutes;
    }
    final nightH = totalNightMinutes ~/ 60;
    final nightM = totalNightMinutes % 60;
    final actualNightHours =
        '${nightH.toString().padLeft(2, '0')}:${nightM.toString().padLeft(2, '0')}';
    debugPrint('[DEBUG] _convertScheduleToAnalysis: totalNightMinutes=$totalNightMinutes '
        '=> $actualNightHours');

    return {
      'totalFlightTime': actualFlightTime,
      'totalDutyTime': accurateTotalDutyTime,
      'nightHours': actualNightHours,
      'rosterPeriod': rosterPeriod,
      'layoverCount': (layoverResult['total'] as double).round(),
      'internationalLayoverCount': layoverResult['international'] as int,
      'domesticLayoverCount': layoverResult['domestic'] as int,
      'flightCounts': {
        '3': count3,
        '4': count4,
        '5': count5,
        'Flight Days': flightDays.length,
        'Standby Days': standbyDays.length,
        'Total Duty Days': dutyDays.length,
      },
      'offDays': offDays.map((day) => {
        'type': 'OFF',
        'description': '${day.dayOfWeek} ${day.date.day}/${day.date.month}',
        'date': day.date.toIso8601String(),
      }).toList(),
      'fullSchedule': scheduleMap,
      'dailyDuties': dailyDuties,
      'firstDate': firstDate,
    };
  }
  
  int _timeToMinutes(String time) {
      final parts = time.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
  
  Widget _buildCalendarView() {
      if (_analysisResult == null) return const SizedBox();
      final fullSchedule = _analysisResult!['fullSchedule'] as Map<DateTime, ScheduleDay>;
      final dailyDuties = _analysisResult!['dailyDuties'] as Map<DateTime, String>;
      final firstDate = _analysisResult!['firstDate'] as DateTime;
      
      // Determine month to show (from first event)
      // Usually rosters are monthly.
      final daysInMonth = DateUtils.getDaysInMonth(firstDate.year, firstDate.month);
      // We want to start from the 1st of that month
      final monthStart = DateTime(firstDate.year, firstDate.month, 1);
      final monthStartedOn = monthStart.weekday; // 1 = Mon, 7 = Sun
      
      // Calculate adjusted start day for grid (Monday start)
      // If starts on Tuesday (2), we need 1 empty slot before it.
      // Grid uses 0-index? No, plain list.
      
      final totalSlots = daysInMonth + (monthStartedOn - 1);
      
      return Column(
          children: [
              // Calendar Header (Month Year)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                      '${_getMonthName(firstDate.month)} ${firstDate.year}',
                      style: const TextStyle(
                          fontFamily: 'Poppins', 
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.white
                      ),
                  ),
              ),
              // Monthly Summary Strip
              _buildMonthlySummary(fullSchedule, firstDate),
              const SizedBox(height: 8),
              // Day Names Header
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['Pts', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'].map((d) => 
                      Text(d, style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 12))
                  ).toList(),
              ),
              const SizedBox(height: 8),
              // Grid
              GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.6, // Taller cells for duties
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                  ),
                  itemCount: totalSlots,
                  itemBuilder: (context, index) {
                      if (index < monthStartedOn - 1) return const SizedBox(); // Empty leading slot
                      
                      final dayNum = index - (monthStartedOn - 1) + 1;
                      final currentDate = DateTime(firstDate.year, firstDate.month, dayNum);
                      
                      // Check if we have data for this day
                      // We need to match precise DateTime. The Map keys might have different times?
                      // The map keys from `parsePdf` usually have 00:00 time.
                      // Let's iterate or ensure key is clean.
                      // Our `ScheduleDay` dates are usually created with `DateTime(y,m,d)` so 00:00.
                      
                      // Find matching entry
                      ScheduleDay? dayData;
                      // Look up safely
                      for(final k in fullSchedule.keys) {
                          if (k.year == currentDate.year && k.month == currentDate.month && k.day == currentDate.day) {
                              dayData = fullSchedule[k];
                              break;
                          }
                      }
                      
                      final dutyTime = dailyDuties[dayData?.date] ?? '';
                      
                      return _buildCalendarDayCell(dayNum, dayData, dutyTime);
                  },
              ),
          ],
      );
  }
  
  /// Builds a summary strip above the calendar showing the counts of
  /// FLY / STANDBY / OFF days and total duty hours for the viewed month.
  Widget _buildMonthlySummary(Map<DateTime, ScheduleDay> fullSchedule, DateTime firstDate) {
      int flyDays = 0, standbyDays = 0, offDays = 0;
      int totalDutyMinutes = 0;
      
      for (final day in fullSchedule.values) {
          // Only count days belonging to the viewed month
          if (day.date.year != firstDate.year || day.date.month != firstDate.month) continue;
          
          final events = day.events;
          final isOff = events.any((e) => e.contains('OFF'));
          final isStandby = events.any((e) => e.contains('SB'));
          final isFly = events.any((e) =>
              (e.contains('XQ') || e.contains('TK') || e.contains('~')) &&
              !isOff && !isStandby);
          
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
              final start = _timeToMinutes(reportTime);
              final end = _timeToMinutes(releaseTime);
              int diff = end - start;
              if (diff < 0) diff += 24 * 60;
              totalDutyMinutes += diff;
          }
      }
      
      final dutyH = totalDutyMinutes ~/ 60;
      final dutyM = totalDutyMinutes % 60;
      final dutyStr = '${dutyH.toString().padLeft(2, '0')}:${dutyM.toString().padLeft(2, '0')}';
      
      Widget chip(Color color, String label, String value) {
          return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
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
      
      return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
              chip(Colors.orange, 'Uçuş', '$flyDays'),
              chip(Colors.amber, 'SBY', '$standbyDays'),
              chip(Colors.green, 'İzin', '$offDays'),
              chip(Colors.lightBlue, 'Görev', dutyStr),
          ],
      );
  }
  
  Widget _buildCalendarDayCell(int day, ScheduleDay? data, String dutyTime) {
      // Determine the type of day for color coding:
      //   OFF     -> green tint
      //   STANDBY -> amber tint
      //   FLY/duty-> orange tint
      //   empty   -> white/neutral
      bool isOff = false;
      bool isStandby = false;
      bool isFly = false;
      String mainEvent = '';
      
      if (data != null) {
          // OFF days take priority
          isOff = data.events.any((e) => e.contains('OFF'));
          // Standby days (SB1/SB2/SB3)
          isStandby = data.events.any((e) => e.contains('SB'));
          // FLY / duty days (XQ/TK flight legs or Report/Release)
          isFly = data.events.any((e) =>
              (e.contains('XQ') || e.contains('TK') || e.contains('~')) &&
              !isOff && !isStandby);
          
          if (isOff) {
              mainEvent = 'OFF';
          } else if (isStandby) {
              // Use the standby line itself (e.g. "SB3 AYT 00:00 ~ 10:00 AYT")
              final sbEvent = data.events.firstWhere(
                  (e) => e.contains('SB'),
                  orElse: () => 'SBY'
              );
              mainEvent = sbEvent.split(' ').take(2).join(' ');
          } else {
               // Prioritize flight/duty info
               final firstRelevant = data.events.firstWhere(
                   (e) => !e.contains('Report') && !e.contains('Release') && !e.startsWith('~') && !e.startsWith('📅'), 
                   orElse: () => data.events.isNotEmpty ? data.events.first : ''
               );
               // Clean up text for small cell
               mainEvent = firstRelevant.split(' ').take(2).join(' '); // "XQ123 AYT"
          }
      }
      
      // Day color coding
      Color cellColor, cellBorder, textColor;
      if (isOff) {
          cellColor = Colors.green.withValues(alpha: 0.25);
          cellBorder = Colors.green.withValues(alpha: 0.5);
          textColor = Colors.lightGreenAccent;
      } else if (isStandby) {
          cellColor = Colors.amber.withValues(alpha: 0.2);
          cellBorder = Colors.amber.withValues(alpha: 0.5);
          textColor = Colors.amberAccent;
      } else if (isFly) {
          cellColor = Colors.orange.withValues(alpha: 0.2);
          cellBorder = Colors.orange.withValues(alpha: 0.6);
          textColor = Colors.orangeAccent;
      } else {
          cellColor = const Color.fromRGBO(255, 255, 255, 0.1);
          cellBorder = Colors.white12;
          textColor = Colors.white70;
      }
      
      return Container(
          decoration: BoxDecoration(
              color: cellColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cellBorder),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  // Top: Day Number
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          '$day',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                  ),
                  // Middle: Event Summary
                  if (data != null)
                    Expanded(
                        child: Center(
                            child: Text(
                                mainEvent,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: textColor,
                                    fontSize: 10
                                ),
                            ),
                        ),
                    ),
                  // Bottom: Duty Time
                  if (dutyTime.isNotEmpty)
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(4)
                        ),
                        child: Text(
                            dutyTime,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFFFA726), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                    ),
              ],
          ),
      );
  }
  
  String _getMonthName(int month) {
      const names = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
      if (month < 1 || month > 12) return '';
      return names[month - 1];
  }

  Widget _buildResultsSection() {
    return NeumorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(12.0), // Reduced padding for more space
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: const Color(0xFFED6C02),
                  size: 24,
                ).animate(controller: _resultAnimationController).rotate(duration: 800.ms),
                const SizedBox(width: 12),
                Text(
                  'Roster Takvimi',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ).animate(controller: _resultAnimationController).fadeIn().slideX(begin: -0.3),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.open_in_new, color: Color(0xFFED6C02)),
                  tooltip: 'Tam Takvim Ekranına Git',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RosterCalendarScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                  child: Column(
                      children: [
                          _buildCalendarView(),
                          const SizedBox(height: 20),
                          const Divider(color: Colors.white24),
                          // Keep existing stats below if needed, or remove?
                          // User asked for "pdf result ACTS AS A CALENDAR".
                          // Maybe stats are secondary now. Let's keep them compact.
                          _buildResultRow('Toplam Görev', _analysisResult!['totalDutyTime'] ?? 'N/A', Icons.access_time, 100),
                          _buildResultRow('Toplam Uçuş', _analysisResult!['totalFlightTime'] ?? 'N/A', Icons.flight_takeoff, 200),
                      ],
                  ),
              ),
            ),
          ],
        ),
      ),
    ).animate(controller: _resultAnimationController).fadeIn(delay: 200.ms).slideY(begin: 0.3);
  }
}
