import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import '../routes.dart';
import '../services/data_service.dart';

class KomisyonEntryScreen extends StatefulWidget {
  const KomisyonEntryScreen({super.key});

  @override
  State<KomisyonEntryScreen> createState() => _KomisyonEntryScreenState();
}

class _KomisyonEntryScreenState extends State<KomisyonEntryScreen> {
  DateTime selectedDate = DateTime.now();
  Map<String, dynamic> komisyonlar = {};
  final TextEditingController _amountController = TextEditingController();
  bool _isFivePeopleChecked = false; // State for the checkbox
  bool _isIcHatChecked = false; // State for the İç Hat checkbox

  @override
  void initState() {
    super.initState();
    loadKomisyonlar();
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _komisyonlarFile async {
    final path = await _localPath;
    return File('$path/komisyonlar.json');
  }

  Future<File> get _savedValuesFile async {
    final path = await _localPath;
    return File('$path/saved_values.json');
  }

  Future<void> loadKomisyonlar() async {
    try {
      final file = await _komisyonlarFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        setState(() {
          komisyonlar = json.decode(content);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Komisyonlar yüklenirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> saveKomisyonlar() async {
    try {
      final file = await _komisyonlarFile;
      await file.writeAsString(json.encode(komisyonlar));

      final totalKomisyon = getTotalKomisyon();

      // Update both saved_values.json and DataService
      try {
        // Update saved_values.json
        final savedValuesFile = await _savedValuesFile;
        Map<String, dynamic> data = {};
        if (await savedValuesFile.exists()) {
          final content = await savedValuesFile.readAsString();
          data = json.decode(content);
        }
        data['mevcut_komisyon'] = totalKomisyon;
        await savedValuesFile.writeAsString(json.encode(data));

        // Update DataService
        await DataService().saveCommission(totalKomisyon);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Değerler başarıyla kaydedildi'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Değerler kaydedilirken hata: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving komisyonlar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double getTotalKomisyon() {
    double total = 0;
    for (var entry in komisyonlar.values) {
      if (entry is Map && entry.containsKey('commission')) {
        total += (entry['commission'] as num).toDouble();
      }
    }
    return total;
  }

  // Updated to accept the checkbox state
  double calculateCommission(double amount, bool isFivePeople) {
    return amount * (isFivePeople ? 0.02 : 0.025); // 2% if checked, else 2.5%
  }

  void showAmountDialog(DateTime date) {
    // Reset checkbox state when dialog opens
    _isFivePeopleChecked = false;
    _amountController.clear(); // Clear previous amount

    showDialog(
      context: context,
      // Use StatefulBuilder to manage checkbox state within the dialog
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(
              'Komisyon Girişi - ${date.day}/${date.month}/${date.year}',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min, // Prevent column from expanding
              children: [
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                    signed: false,
                  ),
                  style: const TextStyle(color: Colors.black, fontSize: 18),
                  inputFormatters: [
                    // Allow both dot and comma as decimal separators
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      String text = newValue.text;
                      int dotCount = '.'.allMatches(text).length;
                      int commaCount = ','.allMatches(text).length;
                      if (dotCount + commaCount > 1) {
                        return oldValue;
                      }
                      if (!RegExp(r'^\d*([.,]?\d{0,2})?$').hasMatch(text)) {
                        return oldValue;
                      }
                      text = text.replaceAll(',', '.');
                      return TextEditingValue(
                        text: text,
                        selection: TextSelection.collapsed(offset: text.length),
                      );
                    }),
                  ],
                  decoration: InputDecoration(
                    hintText: _isIcHatChecked ? 'Amount in ₺' : 'Amount in €',
                    suffixText: _isIcHatChecked ? '₺' : '€',
                    helperText: 'Use . or , for decimals',
                  ),
                ),
                CheckboxListTile(
                  title: const Text("5 Kişi"),
                  value: _isFivePeopleChecked,
                  onChanged: (newValue) {
                    setStateDialog(() {
                      _isFivePeopleChecked = newValue!;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text("İç Hat"),
                  value: _isIcHatChecked,
                  onChanged: (newValue) {
                    setStateDialog(() {
                      _isIcHatChecked = newValue!;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () {
                  final amount = double.tryParse(
                    _amountController.text.replaceAll(',', '.'),
                  );
                  if (amount != null) {
                    final dateStr = date.toIso8601String().split('T')[0];
                    double commission;
                    // Always apply commission logic, but for İç Hat, treat as TL
                    commission = calculateCommission(
                      amount,
                      _isFivePeopleChecked,
                    );
                    komisyonlar[dateStr] = {
                      'amount': amount,
                      'commission': commission,
                      'isFivePeople': _isFivePeopleChecked,
                      'isIcHat': _isIcHatChecked,
                    };
                    saveKomisyonlar();
                    Navigator.pop(context);
                  }
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<String> get turkishMonths => [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromRGBO(21, 123, 163, 1.0),
                      Color.fromRGBO(146, 74, 26, 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(0, 0, 0, 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.orange[300]!.withAlpha(100),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.only(
                        top: 24.0,
                        bottom: 18.0,
                        left: 24.0,
                        right: 24.0,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color.fromRGBO(21, 123, 163, 1.0),
                            Color.fromRGBO(146, 74, 26, 0.9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(77),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.help_outline,
                            color: Colors.orange[300],
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Komisyon Girişi Yardımı',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📅 Takvim Kullanımı',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '• Ay değiştirmek için sol/sağ okları kullanın\n'
                              '• Sadece bugün ve geçmiş tarihlere komisyon girilebilir\n'
                              '• Turuncu renkli günler komisyon girilmiş günlerdir\n'
                              '• Mavi renk bugünü gösterir',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '💰 Komisyon Girişi',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• Miktar girin (Euro € veya Türk Lirası ₺)\n'
                              '• "5 Kişi" seçeneği: %2 komisyon (aksi halde %2.5)\n'
                              '• "İç Hat" seçeneği: Türk Lirası cinsinden işlem\n'
                              '• Ondalık ayracı için "." veya "," kullanabilirsiniz',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '⚙️ Komisyon Hesaplama',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• Normal: Miktar × %2.5\n'
                              '• 5 Kişi ile: Miktar × %2.0\n'
                              '• İç Hat: Türk Lirası olarak işlenir\n'
                              '• Dış Hat: Euro olarak işlenir',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '📊 Görüntüleme',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• Sağ üstteki grafik simgesine tıklayarak tabloyu görün\n'
                              '• Aylık toplamları ve detayları inceleyin\n'
                              '• Girişlerinizi düzenleyebilir veya silebilirsiniz',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Footer
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 16.0,
                        bottom: 24.0,
                        left: 24.0,
                        right: 24.0,
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFED6C02),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          'Anladım',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: Text(
          'Komisyon Girişi',
          style: TextStyle(
            color: Color(0xFFED6C02),
            fontSize: 24,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, size: 22, color: Colors.orange[300]),
            tooltip: 'Yardım',
            onPressed: _showHelpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            color: Colors.orange[300],
            onPressed: () =>
                Navigator.pushNamed(context, Routes.komisyonlarTable),
          ),
          IconButton(
            icon: Icon(Icons.home, size: 22, color: Colors.orange[300]),
            tooltip: 'Ana Sayfa',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(21, 123, 163, 1.0),
              Color.fromRGBO(146, 74, 26, 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          color: Colors.orange[300],
                          onPressed: () {
                            setState(() {
                              selectedDate = DateTime(
                                selectedDate.year,
                                selectedDate.month - 1,
                                selectedDate.day,
                              );
                            });
                          },
                        ),
                        Text(
                          '${turkishMonths[selectedDate.month - 1]} ${selectedDate.year}',
                          style: TextStyle(
                            color: Colors.orange[300],
                            fontSize: 20,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          color: Colors.orange[300],
                          onPressed: () {
                            setState(() {
                              selectedDate = DateTime(
                                selectedDate.year,
                                selectedDate.month + 1,
                                selectedDate.day,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            childAspectRatio: 1,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: 42, // 6 weeks * 7 days
                      itemBuilder: (context, index) {
                        final firstDayOfMonth = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          1,
                        );
                        final firstWeekday = firstDayOfMonth.weekday;
                        final day = index - firstWeekday + 1;

                        if (day < 1) return const SizedBox();

                        final date = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          day,
                        );
                        if (date.month != selectedDate.month) {
                          return const SizedBox();
                        }

                        final isToday =
                            DateTime.now().day == day &&
                            DateTime.now().month == selectedDate.month &&
                            DateTime.now().year == selectedDate.year;

                        final dateStr = date.toIso8601String().split('T')[0];
                        final hasCommission = komisyonlar.containsKey(dateStr);

                        return ElevatedButton(
                          onPressed: () {
                            if (date.isBefore(DateTime.now()) ||
                                (date.year == DateTime.now().year &&
                                    date.month == DateTime.now().month &&
                                    date.day == DateTime.now().day)) {
                              showAmountDialog(date);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasCommission
                                ? const Color(0xFFED6C02)
                                : isToday
                                ? Colors.blue
                                : Colors.grey[800],
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            day.toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
