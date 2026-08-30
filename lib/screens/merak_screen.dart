import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/merak_calculation_service.dart';
import '../services/data_service.dart';

class MerakScreen extends StatefulWidget {
  const MerakScreen({super.key});

  static const routeName = '/merak';

  @override
  State<MerakScreen> createState() => _MerakScreenState();
}

class _MerakScreenState extends State<MerakScreen> {
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _dutyController = TextEditingController();
  final TextEditingController _nightHoursController = TextEditingController();
  final TextEditingController _commissionController = TextEditingController();
  final TextEditingController _domesticLayoversController =
      TextEditingController();
  final TextEditingController _internationalLayoversController =
      TextEditingController();

  final DataService _dataService = DataService();
  final math.Random _random = math.Random();

  double _baseSalary = 0.0;
  double _euroRate = 0.0;
  bool _isSCCM = false;
  bool _writingDuty = false;
  bool _userProvidedDuty = false;
  bool _dutyByCalculator = false;
  bool _resetting = false;

  // Custom keypad state (replaces the system keyboard on this screen).
  TextEditingController? _activeController;
  bool _activeDecimal = false;
  final Map<TextEditingController, GlobalKey> _fieldKeys = {};

  MerakCalculationResult? _result;
  bool _reverseMode = false;

  // Maximum caps for the input fields
  static const double _dutyCap = 180.0;
  static const double _nightCap = 40.0;
  static const double _domesticCap = 15.0;
  static const double _internationalCap = 5.0;
  static const double _commissionCap = 400.0;

  @override
  void initState() {
    super.initState();
    _salaryController.addListener(_onSalaryChanged);
    _dutyController.addListener(_onDutyChanged);
    _nightHoursController.addListener(_onNightChanged);
    _commissionController.addListener(_onCommissionChanged);
    _domesticLayoversController.addListener(_onDomesticChanged);
    _internationalLayoversController.addListener(_onInternationalChanged);
    _loadSavedData();
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _dutyController.dispose();
    _nightHoursController.dispose();
    _commissionController.dispose();
    _domesticLayoversController.dispose();
    _internationalLayoversController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    double base = 0.0;
    double euroRate = 0.0;
    bool sccm = false;
    try {
      final baseData = await _dataService.getBaseSalaryData();
      final role = await _dataService.getRoleSelection();
      base = (baseData?['baseSalary'] as num?)?.toDouble() ?? 0.0;
      euroRate = (baseData?['euroRate'] as num?)?.toDouble() ?? 0.0;
      sccm = role == 'SCCM';
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _baseSalary = base;
      _euroRate = euroRate;
      _isSCCM = sccm;
    });
    _calculate();
  }

  void _onSalaryChanged() {
    if (_resetting) return;
    _calculate();
  }

  void _onNightChanged() {
    if (_resetting) return;
    _clamp(_nightHoursController, _nightCap, isDecimal: true);
    _calculate();
  }

  void _onDomesticChanged() {
    if (_resetting) return;
    _clamp(_domesticLayoversController, _domesticCap);
    _calculate();
  }

  void _onInternationalChanged() {
    if (_resetting) return;
    _clamp(_internationalLayoversController, _internationalCap);
    _calculate();
  }

  void _onCommissionChanged() {
    if (_resetting) return;
    _clamp(_commissionController, _commissionCap, isDecimal: true);
    _calculate();
  }

  void _onDutyChanged() {
    if (_resetting) return;
    if (_writingDuty) {
      _writingDuty = false;
      return;
    }
    final hasText = _dutyController.text.trim().isNotEmpty;
    _userProvidedDuty = hasText;
    if (hasText) {
      // User took ownership of the duty value.
      _dutyByCalculator = false;
    }
    _clamp(_dutyController, _dutyCap, isDecimal: true);
    _calculate();
  }

  /// Clears every input field and resets the calculation state.
  void _resetFields() {
    // Suppress listener-driven recalculation while clearing so the forward
    // calculation cannot re-fill the duty field mid-reset.
    _resetting = true;
    _salaryController.clear();
    _dutyController.clear();
    _nightHoursController.clear();
    _commissionController.clear();
    _domesticLayoversController.clear();
    _internationalLayoversController.clear();
    _resetting = false;
    setState(() {
      _userProvidedDuty = false;
      _dutyByCalculator = false;
      _reverseMode = false;
      _result = null;
      _activeController = null;
      _activeDecimal = false;
    });
  }

  bool get _hasAnyInput =>
      _salaryController.text.trim().isNotEmpty ||
      _dutyController.text.trim().isNotEmpty ||
      _nightHoursController.text.trim().isNotEmpty ||
      _commissionController.text.trim().isNotEmpty ||
      _domesticLayoversController.text.trim().isNotEmpty ||
      _internationalLayoversController.text.trim().isNotEmpty;

  /// Parses a numeric input tolerating ',' as a decimal separator
  /// (Turkish keyboards insert ',' instead of '.').
  double? _parseDecimal(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  void _clamp(
    TextEditingController controller,
    double max, {
    bool isDecimal = false,
  }) {
    final text = controller.text;
    if (text.isEmpty) return;
    final value = _parseDecimal(text);
    if (value == null || value <= max) return;
    // For decimal fields clamp to 2 decimals; for integer caps use 1 decimal
    // (e.g. "180.0") so the displayed value stays consistent.
    final corrected = max.toStringAsFixed(isDecimal ? 2 : 1);
    controller.text = corrected;
  }

  void _calculate() {
    final targetSalary = _parseDecimal(_salaryController.text);

    if (_baseSalary <= 0) {
      setState(() {
        _result = null;
        _reverseMode = false;
      });
      return;
    }

    final nightHours = _parseDecimal(_nightHoursController.text) ?? 0.0;
    final commission = _parseDecimal(_commissionController.text) ?? 0.0;
    final domesticLayovers =
        _parseDecimal(_domesticLayoversController.text) ?? 0.0;
    final internationalLayovers =
        _parseDecimal(_internationalLayoversController.text) ?? 0.0;
    final dutyText = _dutyController.text.trim();
    final dutyHours = dutyText.isNotEmpty ? _parseDecimal(dutyText) : null;

    // Reverse counting: a duty time drives the salary. Duty has priority
    // above the other fields and can never fall back to zero/blank — the
    // calculator always provides it (user-typed duty always wins;
    // calculator-provided duty is used when no target salary is set).
    final canReverse = dutyHours != null && dutyHours > 0;
    final hasTarget = targetSalary != null && targetSalary > 0;
    final reverseFromUser = _userProvidedDuty && canReverse;
    final reverseFromCalculator = _dutyByCalculator && canReverse && !hasTarget;

    if (reverseFromUser || reverseFromCalculator) {
      final result = MerakCalculationService.calculateForDuty(
        targetSalaryEuro: targetSalary ?? 0.0,
        baseSalary: _baseSalary,
        isSCCM: _isSCCM,
        dutyHours: dutyHours,
        nightHours: nightHours,
        commission: commission,
        domesticLayovers: domesticLayovers,
        internationalLayovers: internationalLayovers,
      );
      setState(() {
        _result = result;
        _reverseMode = true;
      });
      return;
    }

    // Forward counting: need a target salary to compute required duty hours
    if (!hasTarget) {
      setState(() {
        _result = null;
        _reverseMode = false;
      });
      return;
    }

    // Duty absorbs the difference to reach the target salary
    final result = MerakCalculationService.calculateRequiredDutyHours(
      targetSalaryEuro: targetSalary,
      baseSalary: _baseSalary,
      isSCCM: _isSCCM,
      nightHours: nightHours,
      commission: commission,
      domesticLayovers: domesticLayovers,
      internationalLayovers: internationalLayovers,
    );
    _dutyByCalculator = true;
    _writeDuty(result.requiredDutyHours);
    setState(() {
      _result = result;
      _reverseMode = false;
    });
  }

  void _writeDuty(double hours) {
    final text = hours.toStringAsFixed(1);
    if (_dutyController.text == text) return;
    _writingDuty = true;
    _dutyController.text = text;
  }

  void _feelingLucky() {
    // Randomize the blank auxiliary fields first (user-entered values are
    // constants). Duty is decided last — it has priority above the others.
    if (_nightHoursController.text.trim().isEmpty) {
      _nightHoursController.text = _random
          .nextInt(_nightCap.toInt() + 1)
          .toString();
    }
    if (_commissionController.text.trim().isEmpty) {
      _commissionController.text = _random
          .nextInt(_commissionCap.toInt() + 1)
          .toString();
    }
    if (_domesticLayoversController.text.trim().isEmpty) {
      _domesticLayoversController.text = _random
          .nextInt(_domesticCap.toInt() + 1)
          .toString();
    }
    if (_internationalLayoversController.text.trim().isEmpty) {
      _internationalLayoversController.text = _random
          .nextInt(_internationalCap.toInt() + 1)
          .toString();
    }

    // Duty time is provided by the calculator and can never be assumed
    // zero/blank. If it is already filled (user value, or the forward
    // calculation filled it while the fields above were randomized), keep it.
    if (_dutyController.text.trim().isNotEmpty) return;

    final target = _parseDecimal(_salaryController.text);
    if (target != null && target > 0) {
      // Target salary present: let the forward calculation provide the duty
      // time that reaches the target (covers the case where no other field
      // changed above, so no listener fired).
      _calculate();
    } else {
      // No target salary: the calculator picks a random duty time within the
      // cap (1..180h, never zero) and shows the salary it yields.
      _writeDuty((1 + _random.nextInt(_dutyCap.toInt())).toDouble());
      _dutyByCalculator = true;
      _calculate();
    }
  }

  // --- Custom keypad (replaces the system keyboard) ---

  void _openKeypad(TextEditingController controller, {required bool decimal}) {
    setState(() {
      _activeController = controller;
      _activeDecimal = decimal;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureActiveFieldVisible();
    });
  }

  void _closeKeypad() {
    if (_activeController == null) return;
    setState(() {
      _activeController = null;
      _activeDecimal = false;
    });
  }

  /// Scrolls the active field above the keypad if it would be covered.
  void _ensureActiveFieldVisible() {
    final controller = _activeController;
    if (controller == null) return;
    final fieldContext = _fieldKeys[controller]?.currentContext;
    if (fieldContext == null) return;
    final box = fieldContext.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final screenHeight = MediaQuery.of(context).size.height;
    final keypadTop = screenHeight - screenHeight / 5;
    final fieldBottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    if (fieldBottom > keypadTop - 12) {
      Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    }
  }

  bool _isValidKeypadEntry(String text) {
    if (_activeDecimal) {
      // Same rule as the typed-input formatter: one separator, 2 decimals.
      return RegExp(r'^\d*(\.\d{0,2})?$').hasMatch(text);
    }
    return RegExp(r'^\d*$').hasMatch(text);
  }

  void _appendText(String insertion) {
    final controller = _activeController;
    if (controller == null) return;
    final newText = controller.text + insertion;
    if (!_isValidKeypadEntry(newText)) {
      HapticFeedback.heavyImpact();
      return;
    }
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  void _onBackspace() {
    final controller = _activeController;
    if (controller == null || controller.text.isEmpty) return;
    final newText = controller.text.substring(0, controller.text.length - 1);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  void _onClearActive() {
    _activeController?.clear();
  }

  Widget _buildField({
    required String label,
    required String hint,
    String? prefix,
    String? suffix,
    String? caption,
    required TextEditingController controller,
    required bool decimal,
    bool bold = false,
  }) {
    final isActive = _activeController == controller;
    final fieldKey = _fieldKeys.putIfAbsent(controller, () => GlobalKey());
    return Column(
      key: fieldKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(
            caption,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          showCursor: false,
          enableInteractiveSelection: false,
          onTap: () => _openKeypad(controller, decimal: decimal),
          keyboardType: decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          inputFormatters: [
            decimal
                // Turkish keyboards only offer a comma as the decimal
                // separator — accept both '.' and ',' and normalize the
                // text to '.' so parsing works (same approach as
                // komisyon_entry_screen.dart).
                ? TextInputFormatter.withFunction((oldValue, newValue) {
                    final text = newValue.text;
                    final separatorCount =
                        '.'.allMatches(text).length +
                        ','.allMatches(text).length;
                    if (separatorCount > 1) return oldValue;
                    if (!RegExp(r'^\d*([.,]?\d{0,2})?$').hasMatch(text)) {
                      return oldValue;
                    }
                    final normalized = text.replaceAll(',', '.');
                    // ',' -> '.' is a 1:1 replacement, so the selection
                    // offsets stay valid and the cursor keeps its position.
                    return TextEditingValue(
                      text: normalized,
                      selection: newValue.selection,
                    );
                  })
                : FilteringTextInputFormatter.digitsOnly,
          ],
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: bold ? 18 : 16,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white38,
            ),
            prefixText: prefix,
            prefixStyle: const TextStyle(
              fontFamily: 'Poppins',
              color: Color(0xFFFFA726),
            ),
            suffixText: suffix,
            suffixStyle: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white70,
            ),
            filled: true,
            fillColor: const Color.fromRGBO(255, 255, 255, 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isActive
                    ? const Color(0xFFFFA726)
                    : const Color.fromRGBO(255, 255, 255, 0.2),
                width: isActive ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFFA726), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final keypadHeight = MediaQuery.of(context).size.height / 5;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [Color(0xFFED6C02), Color(0xFFFFA726), Color(0xFFED6C02)],
              stops: [0.0, 0.5, 1.0],
              tileMode: TileMode.mirror,
            ).createShader(bounds);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: 'MERAK'.split('').map((char) {
              return Text(
                    char,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Color(0xFF924A1A),
                          blurRadius: 4,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(
                    duration: 3.seconds,
                    delay: 1.seconds,
                    color: const Color(0xFFFFA726),
                  )
                  .scaleXY(
                    begin: 0.8,
                    end: 1.2,
                    duration: 2.seconds,
                    curve: Curves.easeInOut,
                    delay: Duration(milliseconds: 'MERAK'.indexOf(char) * 100),
                  );
            }).toList(),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _titleCard(),
                    const SizedBox(height: 16),
                    _baseCard(),
                    const SizedBox(height: 16),
                    _inputCard(),
                    const SizedBox(height: 16),
                    _detailCard(),
                    const SizedBox(height: 16),
                    if (_result != null) _resultCard(),
                    const SizedBox(height: 16),
                    _resetButton(),
                    SizedBox(
                      height: _activeController != null
                          ? keypadHeight + 24
                          : 100,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_activeController != null) ...[
            // Invisible scrim: tapping outside the keypad closes it.
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeKeypad,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: _NumericKeypad(
                  decimal: _activeDecimal,
                  onDigit: _appendText,
                  onBackspace: _onBackspace,
                  onClear: _onClearActive,
                  onDone: _closeKeypad,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _titleCard() {
    return NeumorphicCard(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Icon(Icons.calculate, color: Color(0xFFED6C02), size: 32),
                const SizedBox(height: 12),
                const Text(
                  'Maaş Hedef Hesaplayıcı',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hedeflediğiniz maaşı girin, size hangi görev saatine ihtiyacınız olduğunu söyleyelim!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
          curve: Curves.easeOut,
        );
  }

  Widget _baseCard() {
    final roleLabel = _isSCCM ? 'SCCM' : 'CCM';
    return NeumorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            const Icon(
              Icons.workspace_premium,
              color: Color(0xFFFFA726),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Base Salary (Kayıtlı)',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '€${_baseSalary.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFFFFA726),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_euroRate > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Euro Kuru: $_euroRate ₺',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              roleLabel,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _inputCard() {
    return NeumorphicCard(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildField(
                  label: 'Hedef Maaş (€)',
                  hint: '0',
                  prefix: '€ ',
                  controller: _salaryController,
                  decimal: true,
                  bold: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _baseSalary > 0 ? _feelingLucky : null,
                    icon: const Icon(Icons.casino, color: Colors.white),
                    label: const Text('Feeling Lucky'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFED6C02),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
          curve: Curves.easeOut,
          delay: 100.ms,
        );
  }

  Widget _resetButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _hasAnyInput ? _resetFields : null,
        icon: const Icon(Icons.restart_alt, color: Color(0xFFFFA726)),
        label: const Text(
          'Sıfırla',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFED6C02), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  Widget _detailCard() {
    return NeumorphicCard(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Detaylar',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: 'Görev Saati (saat)',
                  hint: '0',
                  suffix: 'saat',
                  caption:
                      'Maks. 180 — boşsa hesaplayıcı doldurur (hedef maaşa göre veya Feeling Lucky ile rastgele)',
                  controller: _dutyController,
                  decimal: true,
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: 'Gece Saati (Aylık)',
                  hint: '0',
                  suffix: 'saat',
                  caption: 'Maks. 40',
                  controller: _nightHoursController,
                  decimal: true,
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: 'İç Hat Yatı',
                  hint: '0',
                  suffix: 'gece',
                  caption: 'Maks. 15',
                  controller: _domesticLayoversController,
                  decimal: false,
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: 'Dış Hat Yatı',
                  hint: '0',
                  suffix: 'gece',
                  caption: 'Maks. 5',
                  controller: _internationalLayoversController,
                  decimal: false,
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: 'Komisyon (€)',
                  hint: '0',
                  prefix: '€ ',
                  caption: 'Maks. 300',
                  controller: _commissionController,
                  decimal: true,
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 200.ms)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
          curve: Curves.easeOut,
          delay: 200.ms,
        );
  }

  Widget _resultCard() {
    return NeumorphicCard(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Icon(
                  _reverseMode ? Icons.payments : Icons.access_time,
                  color: const Color(0xFFED6C02),
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  _reverseMode ? 'Hesaplanan Maaş' : 'Gerekli Görev Saati',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _reverseMode
                      ? '€${_result!.breakdown['total']!.toStringAsFixed(0)}'
                      : '${_result!.requiredDutyHours.toStringAsFixed(1)} saat',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFFFA726),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Maaş Dağılımı',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBreakdownRow(
                  'Temel Maaş',
                  _result!.breakdown['baseSalary']!,
                ),
                _buildBreakdownRow(
                  'Görev Saati',
                  _result!.breakdown['dutyPay']!,
                ),
                if (_result!.breakdown['overtimePay']! > 0)
                  _buildBreakdownRow(
                    'Mesai',
                    _result!.breakdown['overtimePay']!,
                  ),
                _buildBreakdownRow(
                  'Gece Saati',
                  _result!.breakdown['nightPay']!,
                ),
                if (_result!.breakdown['layoverPay']! > 0)
                  _buildBreakdownRow(
                    'Layover',
                    _result!.breakdown['layoverPay']!,
                  ),
                _buildBreakdownRow(
                  'Komisyon',
                  _result!.breakdown['commission']!,
                ),
                const Divider(color: Colors.white24),
                _buildBreakdownRow(
                  'TOPLAM',
                  _result!.breakdown['total']!,
                  isTotal: true,
                ),
                if (_euroRate > 0) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '₺${(_result!.breakdown['total']! * _euroRate).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFFFFA726),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 300.ms)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
          curve: Curves.easeOut,
          delay: 300.ms,
        );
  }

  Widget _buildBreakdownRow(
    String label,
    double value, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: isTotal ? const Color(0xFFFFA726) : Colors.white,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '€${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: isTotal ? const Color(0xFFFFA726) : Colors.white70,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class ParallaxBackgroundShapes extends StatefulWidget {
  const ParallaxBackgroundShapes({super.key});

  @override
  State<ParallaxBackgroundShapes> createState() =>
      _ParallaxBackgroundShapesState();
}

class _ParallaxBackgroundShapesState extends State<ParallaxBackgroundShapes>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.depth == 0) {
          setState(() {
            _scrollOffset = scrollInfo.metrics.pixels;
          });
        }
        return false;
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: ParallaxShapesPainter(_controller.value, _scrollOffset),
            child: Container(),
          );
        },
      ),
    );
  }
}

class ParallaxShapesPainter extends CustomPainter {
  final double animationValue;
  final double scrollOffset;

  ParallaxShapesPainter(this.animationValue, this.scrollOffset);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.05)
      ..style = PaintingStyle.fill;

    final parallaxFactor = 0.1;

    for (var i = 0; i < 5; i++) {
      final parallaxOffset = scrollOffset * parallaxFactor * (i * 0.2 + 0.5);

      final offset = Offset(
        size.width * (0.2 + 0.15 * i),
        size.height * (0.3 + 0.1 * i) - parallaxOffset,
      );

      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate((animationValue + i) * 2 * math.pi);

      if (i % 3 == 0) {
        canvas.drawCircle(Offset.zero, 40, paint);
      } else if (i % 3 == 1) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 60, height: 60),
          paint,
        );
      } else {
        final path = Path();
        const size = 40.0;
        path.moveTo(0, -size);
        path.lineTo(size, size);
        path.lineTo(-size, size);
        path.close();
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ParallaxShapesPainter oldDelegate) =>
      animationValue != oldDelegate.animationValue ||
      scrollOffset != oldDelegate.scrollOffset;
}

class NeumorphicCard extends StatelessWidget {
  final Widget child;

  const NeumorphicCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(42, 45, 62, 0.3),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.4),
            offset: Offset(5, 5),
            blurRadius: 12,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Color.fromRGBO(255, 255, 255, 0.15),
            offset: Offset(-5, -5),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.1),
          width: 1.5,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(255, 255, 255, 0.15),
            Color.fromRGBO(255, 255, 255, 0.05),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }
}

/// In-app numeric keypad that replaces the system keyboard on this screen.
/// Exactly 1/5 of the screen height, translucent (frosted glass) style.
class _NumericKeypad extends StatelessWidget {
  const _NumericKeypad({
    required this.decimal,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onDone,
  });

  final bool decimal;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    // Exactly 1/5 of the screen height.
    final height = MediaQuery.of(context).size.height / 5;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: height,
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            // Translucent glass background — 85% transparent (alpha 0.15).
            color: Color.fromRGBO(10, 25, 41, 0.15),
            border: Border(
              top: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.25)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _digitRow('1', '2', '3'),
                    _digitRow('4', '5', '6'),
                    _digitRow('7', '8', '9'),
                    _bottomRow(),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    _actionKey(
                      icon: Icons.backspace_outlined,
                      color: const Color.fromRGBO(255, 255, 255, 0.10),
                      onTap: onBackspace,
                      onLongPress: onClear,
                    ),
                    _actionKey(
                      icon: Icons.close,
                      color: const Color.fromRGBO(239, 83, 80, 0.35),
                      onTap: onClear,
                    ),
                    _actionKey(
                      icon: Icons.check_rounded,
                      color: const Color.fromRGBO(237, 108, 2, 0.55),
                      onTap: onDone,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _digitRow(String a, String b, String c) {
    return Expanded(
      child: Row(children: [_digitKey(a), _digitKey(b), _digitKey(c)]),
    );
  }

  Widget _bottomRow() {
    return Expanded(
      child: Row(
        children: [
          if (decimal) _digitKey('.') else _disabledKey(),
          _digitKey('0'),
          _digitKey('00'),
        ],
      ),
    );
  }

  Widget _digitKey(String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: const Color.fromRGBO(255, 255, 255, 0.10),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.selectionClick();
              onDigit(label);
            },
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _disabledKey() {
    return const Expanded(
      child: Padding(padding: EdgeInsets.all(3), child: SizedBox.expand()),
    );
  }

  Widget _actionKey({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            onLongPress: onLongPress,
            child: Center(child: Icon(icon, color: Colors.white, size: 22)),
          ),
        ),
      ),
    );
  }
}
