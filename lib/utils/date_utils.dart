class DateUtils {
  static const Map<String, int> monthMap = {
    'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
    'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
  };

  static const List<String> monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> monthNamesTurkish = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  /// Calculate the payment month from roster period
  /// Roster period format: "16APR24" or similar
  /// Payment month is the month after the roster period month
  static String getPaymentMonth(String? rosterPeriod, {bool turkish = true}) {
    if (rosterPeriod == null || rosterPeriod.isEmpty) {
      return turkish ? 'Bilinmiyor' : 'Unknown';
    }

    // Parse roster period using regex to extract month
    final RegExp regExp = RegExp(r'(\d{2})([A-Za-z]{3})(\d{2})', caseSensitive: false);
    final match = regExp.firstMatch(rosterPeriod);
    
    if (match == null) {
      return turkish ? 'Bilinmiyor' : 'Unknown';
    }

    final monthAbbr = match.group(2)!.toUpperCase();
    final year = 2000 + int.parse(match.group(3)!);
    
    final rosterMonth = monthMap[monthAbbr];
    if (rosterMonth == null) {
      return turkish ? 'Bilinmiyor' : 'Unknown';
    }

    // Payment month is the next month
    int paymentMonth = rosterMonth + 1;
    int paymentYear = year;
    
    // Handle year rollover (December -> January)
    if (paymentMonth > 12) {
      paymentMonth = 1;
      paymentYear++;
    }

    final monthNames = turkish ? monthNamesTurkish : DateUtils.monthNames;
    return '${monthNames[paymentMonth - 1]} $paymentYear';
  }

  /// Format roster period and payment month together
  static String formatRosterWithPayment(String? rosterPeriod, {bool turkish = true}) {
    if (rosterPeriod == null || rosterPeriod.isEmpty) {
      return turkish ? 'Dönem: Bilinmiyor' : 'Period: Unknown';
    }

    final paymentMonth = getPaymentMonth(rosterPeriod, turkish: turkish);
    final rosterLabel = turkish ? 'Dönem' : 'Roster';
    final paymentLabel = turkish ? 'Ödeme' : 'Payment';
    
    return '$rosterLabel: $rosterPeriod | $paymentLabel: $paymentMonth';
  }
}
