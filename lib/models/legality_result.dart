class LegalityCheck {
  final String rule;
  final String status; // 'pass', 'fail', 'warning'
  final String message;
  final String reference;

  LegalityCheck({
    required this.rule,
    required this.status,
    required this.message,
    required this.reference,
  });
}

class LegalityResult {
  final bool isLegal;
  final String type; // 'success', 'error', 'warning'
  final String summary;
  final List<LegalityCheck> checks;

  LegalityResult({
    required this.isLegal,
    required this.type,
    required this.summary,
    required this.checks,
  });
}