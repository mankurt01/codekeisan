class PdfResult {
  final String fileName;
  final DateTime date;
  final Map<String, dynamic> data;
  final String? rawText; // Raw ICS text kept for re-parsing (Roster Calendar)

  PdfResult({
    required this.fileName,
    required this.date,
    required this.data,
    this.rawText,
  });

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'date': date.toIso8601String(),
      'data': data,
      'rawText': rawText,
    };
  }

  factory PdfResult.fromJson(Map<String, dynamic> json) {
    return PdfResult(
      fileName: json['fileName'] as String,
      date: DateTime.parse(json['date'] as String),
      data: json['data'] as Map<String, dynamic>,
      rawText: json['rawText'] as String?,
    );
  }
}