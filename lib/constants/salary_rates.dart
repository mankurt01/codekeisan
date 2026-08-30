class SalaryRates {
  // Fixed rates that are the same for both SCCM and CCM
  static const double domesticOvernightRate = 30.0;
  static const double internationalOvernightRate = 50.0;

  // Base salary rates for CCM based on years of experience
  static const Map<String, double> ccmBaseSalary = {
    '0-2': 530.0,
    '2-4': 600.0,
    '4-6': 680.0,
    '6-8': 750.0,
    '8+': 830.0,
  };

  // Base salary rates for SCCM based on years of experience
  static const Map<String, double> sccmBaseSalary = {
    '0-2': 830.0,
    '2-4': 920.0,
    '4-6': 1000.0,
    '6-8': 1100.0,
    '8-12': 1200.0,
    '12+': 1280.0,
  };

  static const Map<String, double> sccmRates = {
    'duty': 5.5,
    'overtime': 9.9,
    'leg3': 11.88,
    'leg4': 23.76,
    'leg5': 35.54,
    'sixthDay': 59.4,
    'offDuty': 150.0,
    'nightHour': 29.70,
  };

  static const Map<String, double> ccmRates = {
    'duty': 2.75,
    'overtime': 7.15,
    'leg3': 8.32,
    'leg4': 16.64,
    'leg5': 24.96,
    'sixthDay': 35.54,
    'offDuty': 100.0,
    'nightHour': 17.82,
  };
}
