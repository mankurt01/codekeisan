import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/data_service.dart';
import '../constants/salary_rates.dart';

class BaseSalaryServiceScreen extends StatefulWidget {
  const BaseSalaryServiceScreen({super.key});

  @override
  State<BaseSalaryServiceScreen> createState() =>
      _BaseSalaryServiceScreenState();
}

class _BaseSalaryServiceScreenState extends State<BaseSalaryServiceScreen> {
  String? _role;
  String? _selectedBase;
  String? _yearsOfService;
  String? _employmentType;
  String? _partTimeType;
  double _calculatedBaseSalary = 0.0;

  final DataService _dataService = DataService();

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    try {
      final savedRole = await _dataService.getRoleSelection();
      final savedBase = await _dataService.getBaseSelection();
      final baseSalaryData = await _dataService.getBaseSalaryData();
      
      if (mounted) {
        setState(() {
          _role = savedRole;
          _selectedBase = savedBase;
          if (baseSalaryData != null) {
            _yearsOfService = baseSalaryData['yearsOfService'] as String?;
            _employmentType = baseSalaryData['employmentType'] as String?;
            _partTimeType = baseSalaryData['partTimeType'] as String?;
          }
          _calculatedBaseSalary = _calculateBaseSalary();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıtlı pozisyon yüklenirken hata: $e')),
        );
      }
    }
  }

  double _calculateBaseSalary() {
    if (_role == null || _yearsOfService == null || _employmentType == null) {
      return 0.0;
    }

    // Get base salary map based on role
    final baseSalaryMap = _role == 'CCM'
        ? SalaryRates.ccmBaseSalary
        : SalaryRates.sccmBaseSalary;

    // Get base value for years of service
    double baseSalary = baseSalaryMap[_yearsOfService] ?? 0.0;

    // Apply part-time adjustment if needed
    if (_employmentType == 'Part Time' && _partTimeType != null) {
      switch (_partTimeType) {
        case '20-10':
          baseSalary *= 0.667; // 2/3 calculation for 20-10
          break;
        case '23-7':
          baseSalary *= 0.767; // 23/30 calculation for 23-7
          break;
        case '15-15':
          baseSalary *= 0.5; // 1/2 calculation for 15-15
          break;
      }
    }

    // Round to 2 decimal places for consistency
    return double.parse(baseSalary.toStringAsFixed(2));
  }

  Future<void> _saveBaseSalary() async {
    try {
      if (_selectedBase == null) {
        throw Exception('Lütfen base seçiniz');
      }

      if (_calculatedBaseSalary <= 0) {
        throw Exception('Base salary must be greater than 0');
      }
      
      // Save base selection
      await _dataService.saveBaseSelection(_selectedBase!);

      // Load existing values first
      final currentData = await _dataService.getBaseSalaryData();

      // Create updated data map
      final updatedData = {
        'baseSalary': _calculatedBaseSalary,
        'role': _role,
        'yearsOfService': _yearsOfService,
        'employmentType': _employmentType,
        'euroRate': currentData?['euroRate'] ?? 0.0,
        'sixthDay': currentData?['sixthDay'] ?? 0,
        'internationalOvernight': currentData?['internationalOvernight'] ?? 0,
        'duzeltme': (currentData?['duzeltme'] as num?)?.toDouble() ?? 0.0,
      };

      // Save all data in one operation
      await _dataService.saveBaseSalaryData(
        baseSalary: _calculatedBaseSalary,
        euroRate: updatedData['euroRate'] as double,
        sixthDay: updatedData['sixthDay'] as int,
        internationalOvernight: updatedData['internationalOvernight'] as int,
        duzeltme: updatedData['duzeltme'] as double,
        employmentType: _employmentType,
        partTimeType: _partTimeType,
        yearsOfService: _yearsOfService,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Base Maaş başarıyla kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, {
          'salary': _calculatedBaseSalary,
          'role': _role,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Base maaş kaydedilirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
                              'Base Maaş Belirleme Yardımı',
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
                              '👔 Pozisyon Seçimi',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'İlk olarak pozisyonunuzu seçin:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• CCM (Cabin Crew Member): Kabin görevlisi\n'
                              '• SCCM (Senior Cabin Crew Member): Kıdemli kabin görevlisi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '📅 Deneyim Süresi',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Seçtiğiniz pozisyonda kaç yıldır çalıştığınızı belirtin:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• CCM: 0-2, 2-4, 4-6, 6-8, 8+ yıl seçenekleri\n'
                              '• SCCM: 0-2, 2-4, 4-6, 6-8, 8-12, 12+ yıl seçenekleri\n'
                              '• Her deneyim aralığının farklı maaş katsayısı vardır',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '⏰ Çalışma Türü',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• Full Time: Tam zamanlı çalışma (ek katsayı yok)\n'
                              '• Part Time: Yarı zamanlı çalışma (maaş düşürülür)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '📊 Part Time Türleri',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• 20-10: Ayda 20 gün çalışma, 10 gün izin (×⅔)\n'
                              '• 23-7: Ayda 23 gün çalışma, 7 gün izin (×0.767)\n'
                              '• 15-15: Ayda 15 gün çalışma, 15 gün izin (×½)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '💰 Hesaplama',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• Tüm seçimler yapıldıktan sonra maaş otomatik hesaplanır\n'
                              '• Güncel THY maaş katsayıları kullanılır\n'
                              '• "Tamamla" butonuna tıklayarak kaydedin\n'
                              '• Hesaplanan maaş ana hesaplama ekranına aktarılır',
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
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromRGBO(21, 123, 163, 1.0),
              Color.fromRGBO(146, 64, 26, 1.0),
            ],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            centerTitle: false,
            title: const Text(
              'Base Maaş Belirleme',
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
                icon: Icon(Icons.home, size: 22, color: Colors.orange[300]),
                tooltip: 'Ana Sayfa',
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/',(route) => false);
                },
              ),
            ],
          ),
          body: SafeArea(
            maintainBottomViewPadding: true,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          color: Colors.white.withAlpha(25),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Base Seçimi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSelectionButton(
                                        'AYT',
                                        _selectedBase == 'AYT',
                                        () => setState(() => _selectedBase = 'AYT'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSelectionButton(
                                        'ADB',
                                        _selectedBase == 'ADB',
                                        () => setState(() => _selectedBase = 'ADB'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSelectionButton(
                                        'ESB',
                                        _selectedBase == 'ESB',
                                        () => setState(() => _selectedBase = 'ESB'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          color: Colors.white.withAlpha(25),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pozisyon Seçimi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSelectionButton(
                                        'CCM',
                                        _role == 'CCM',
                                        () async {
                                          setState(() {
                                            _role = 'CCM';
                                            _yearsOfService =
                                                null; // Reset when changing role
                                            _calculatedBaseSalary =
                                                _calculateBaseSalary();
                                          });
                                          await _dataService.saveRoleSelection(
                                            'CCM',
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSelectionButton(
                                        'SCCM',
                                        _role == 'SCCM',
                                        () async {
                                          setState(() {
                                            _role = 'SCCM';
                                            _yearsOfService =
                                                null; // Reset when changing role
                                            _calculatedBaseSalary =
                                                _calculateBaseSalary();
                                          });
                                          await _dataService.saveRoleSelection(
                                            'SCCM',
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
                        const SizedBox(height: 16),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          color: Colors.white.withAlpha(25),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pozisyonda Çalışma Süresi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (_role == 'CCM') ...[
                                      _buildSelectionButton(
                                        '0-2',
                                        _yearsOfService == '0-2',
                                        () => setState(() {
                                          _yearsOfService = '0-2';
                                          _calculatedBaseSalary =
                                              _calculateBaseSalary();
                                        }),
                                      ),
                                      _buildSelectionButton(
                                        '2-4',
                                        _yearsOfService == '2-4',
                                        () => setState(() {
                                          _yearsOfService = '2-4';
                                          _calculatedBaseSalary =
                                              _calculateBaseSalary();
                                        }),
                                      ),
                                      _buildSelectionButton(
                                        '4-6',
                                        _yearsOfService == '4-6',
                                        () => setState(() {
                                          _yearsOfService = '4-6';
                                          _calculatedBaseSalary =
                                              _calculateBaseSalary();
                                        }),
                                      ),
                                      _buildSelectionButton(
                                        '6-8',
                                        _yearsOfService == '6-8',
                                        () => setState(() {
                                          _yearsOfService = '6-8';
                                          _calculatedBaseSalary =
                                              _calculateBaseSalary();
                                        }),
                                      ),
                                      _buildSelectionButton(
                                        '8+',
                                        _yearsOfService == '8+',
                                        () => setState(() {
                                          _yearsOfService = '8+';
                                          _calculatedBaseSalary =
                                              _calculateBaseSalary();
                                        }),
                                      ),
                                    ] else if (_role == 'SCCM') ...[
                                      _buildSelectionButton(
                                        '0-2',
                                        _yearsOfService == '0-2',
                                        () => setState(() {
                                          _yearsOfService = '0-2';
                                          _calculatedBaseSalary =
                                              _calculateBaseSalary();
                                        }),
                                      ),
                                      _buildSelectionButton(
                                        '2-4',
                                        _yearsOfService == '2-4',
                                        () => setState(() {
                                          _yearsOfService = '2-4';
                                          _calculatedBaseSalary =
                                              _calculateBaseSalary();
                                        }),
                                      ),
                                      _buildSelectionButton(
                                        '4-6',
                                        _yearsOfService == '4-6',
                                        () => setState(() {
                                          _yearsOfService = '4-6';
                                          _calculatedBaseSalary =
                                              _calculateBaseSalary();
                                        }),
                                      ),
                                      _buildSelectionButton(
                                        '6-8',
                                        _yearsOfService == '6-8',
                                        () => setState(() {
                                          _yearsOfService = '6-8';
                                          _calculatedBaseSalary =
                                              _calculateBaseSalary();
                                        }),
                                      ),
                                      _buildSelectionButton(
                                        '8-12',
                                        _yearsOfService == '8-12',
                                        () => setState(() {
                                          _yearsOfService = '8-12';
                                          _calculatedBaseSalary =
                                              _calculateBaseSalary();
                                        }),
                                      ),
                                      _buildSelectionButton(
                                        '12+',
                                        _yearsOfService == '12+',
                                        () => setState(() {
                                          _yearsOfService = '12+';
                                          _calculatedBaseSalary =
                                              _calculateBaseSalary();
                                        }),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          color: Colors.white.withAlpha(25),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Çalışma Türü',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSelectionButton(
                                        'Full Time',
                                        _employmentType == 'Full Time',
                                        () => setState(() {
                                          _employmentType = 'Full Time';
                                          _partTimeType = null; // Reset part-time type when switching to full-time
                                          _calculatedBaseSalary =
                                              _calculateBaseSalary();
                                        }),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSelectionButton(
                                        'Part Time',
                                        _employmentType == 'Part Time',
                                        () => setState(() {
                                          _employmentType = 'Part Time';
                                          _calculatedBaseSalary =
                                              _calculateBaseSalary();
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Part-time type selection (only shown when Part Time is selected)
                        if (_employmentType == 'Part Time') ...[
                          const SizedBox(height: 16),
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            color: Colors.white.withAlpha(25),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Part Time Türü',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildSelectionButton(
                                        '20-10',
                                        _partTimeType == '20-10',
                                        () => setState(() {
                                          _partTimeType = '20-10';
                                          _calculatedBaseSalary =
                                              _calculateBaseSalary();
                                        }),
                                      ),
                                      _buildSelectionButton(
                                        '23-7',
                                        _partTimeType == '23-7',
                                        () => setState(() {
                                          _partTimeType = '23-7';
                                          _calculatedBaseSalary =
                                              _calculateBaseSalary();
                                        }),
                                      ),
                                      _buildSelectionButton(
                                        '15-15',
                                        _partTimeType == '15-15',
                                        () => setState(() {
                                          _partTimeType = '15-15';
                                          _calculatedBaseSalary =
                                              _calculateBaseSalary();
                                        }),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          color: Colors.white.withAlpha(25),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Text(
                                  'Base Maaşınız',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '€${_calculatedBaseSalary.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _role != null &&
                                  _yearsOfService != null &&
                                  _employmentType != null &&
                                  (_employmentType == 'Full Time' || 
                                   (_employmentType == 'Part Time' && _partTimeType != null))
                              ? _saveBaseSalary
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Tamamla',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }

  Widget _buildSelectionButton(
    String text,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          constraints: const BoxConstraints(minWidth: 80, minHeight: 36),
          decoration: BoxDecoration(
            color: isSelected ? Colors.orange : Colors.white.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withAlpha(204),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
