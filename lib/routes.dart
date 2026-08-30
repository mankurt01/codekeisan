import 'package:flutter/material.dart';
import 'screens/pdf_upload_screen.dart';
import 'screens/roster_calendar_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/roster_history_screen.dart';
import 'screens/komisyonlar_screen.dart';
import 'screens/gecmis_maaslar_screen.dart';
import 'screens/gecmis_screen.dart';
import 'screens/base_maas_screen.dart';
import 'screens/help_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/duty_time_calculator_screen.dart';
import 'screens/new_sign_in_screen.dart';
import 'screens/disclaimer_screen.dart';
import 'screens/shgm_ftl_screen.dart';
import 'screens/komisyon_entry_screen.dart';
import 'screens/komisyonlar_table_screen.dart';
import 'screens/tum_komisyonlar_screen.dart';
import 'screens/merak_screen.dart';
import 'services/result_screen.dart';

class Routes {
  static const String welcome = '/';
  static const String pdfUpload = '/pdf-upload';
  static const String rosterTakvimi = '/roster-takvimi';
  static const String rosterHistory = '/roster-history';
  static const String gecmis = '/gecmis';
  static const String komisyonlar = '/komisyonlar';
  static const String gecmisMaaslar = '/gecmis-maaslar';
  static const String baseMaas = '/base-maas';
  static const String help = '/help';
  static const String statistics = '/statistics';
  static const String dutyTimeCalculator = '/duty-time-calculator';
  static const String signIn = '/sign-in';
  static const String result = '/result';
  static const String komisyonEntry = '/komisyon-entry';
  static const String komisyonlarTable = '/komisyonlar-table';
  static const String tumKomisyonlar = '/tum-komisyonlar';
  static const String disclaimer = '/disclaimer';
  static const String bypassWelcome = '/bypass-welcome';
  static const String shgmFtl = '/shgmFtl';
  static const String merak = '/merak';

  static final routes = <String, WidgetBuilder>{
    welcome: (context) => const WelcomeScreen(),
    pdfUpload: (context) => const PdfUploadScreen(),
    rosterTakvimi: (context) => const RosterCalendarScreen(),
    rosterHistory: (context) => const RosterHistoryScreen(),
    gecmis: (context) => const GecmisScreen(),
    komisyonlar: (context) => const KomisyonlarScreen(),
    gecmisMaaslar: (context) => const GecmisMaaslarScreen(),
    baseMaas: (context) => const BaseMaasScreen(),
    help: (context) => const HelpScreen(),
    statistics: (context) => const StatisticsScreen(),
    dutyTimeCalculator: (context) => const DutyTimeCalculatorScreen(),
    signIn: (context) => const NewSignInScreen(),
    komisyonEntry: (context) => const KomisyonEntryScreen(),
    komisyonlarTable: (context) => const KomisyonlarTableScreen(),
    tumKomisyonlar: (context) => const TumKomisyonlarScreen(),
    disclaimer: (context) => const DisclaimerScreen(),
    shgmFtl: (context) => const ShgmFtlScreen(),
    merak: (context) => const MerakScreen(),
    result: (context) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      return ResultScreen(
        isSCCM: args['isSCCM'] as bool,
        dutyHours: args['dutyHours'] as double,
        nightHours: args['nightHours'] as double,
        legCounts: args['legCounts'] as Map<String, int>,
        commission: args['commission'] as double,
        layoverCount: args['layoverCount'] as int,
        offDutyCounts: args['offDutyCounts'] as int,
        sixthDay: args['sixthDay'] as int? ?? 0,
        internationalOvernight: args['internationalOvernight'] as int? ?? 0,
        rosterPeriod: args['rosterPeriod'] as String?,
        offDays: args['offDays'] as List<Map<String, dynamic>>? ?? const [],
      );
    },
    // Keep placeholder for bypassWelcome if it is not used/defined
    bypassWelcome: (context) => Scaffold(appBar: AppBar(title: const Text('Bypass Welcome')), body: const Center(child: Text('Bypass Welcome Screen'))),
  };
}
