import 'package:flutter/material.dart';
import '../utils/date_utils.dart' as app_date_utils;

class SalaryBreakdownCard extends StatelessWidget {
  final Map<String, double> components;
  final double totalEuro;
  final bool isSCCM;
  final Map<String, dynamic> baseSalaryData;
  final double dutyHours;
  final double nightHours;
  final Map<String, int> legCounts;
  final int layoverCount;
  final int offDutyCounts;
  final String? rosterPeriod;

  const SalaryBreakdownCard({
    super.key,
    required this.components,
    required this.totalEuro,
    required this.isSCCM,
    required this.baseSalaryData,
    required this.dutyHours,
    required this.nightHours,
    required this.legCounts,
    required this.layoverCount,
    required this.offDutyCounts,
    this.rosterPeriod,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            color: const Color(0xFF1F1D2B),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildBreakdownList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4500), Color(0xFFFF8C00)], // Orange Red to Dark Orange
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withAlpha((0.3 * 255).toInt()),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rosterPeriod != null && rosterPeriod!.isNotEmpty) ...[
            Text(
              '📅 Roster Dönemi: $rosterPeriod',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '💰 Ödeme Ayı: ${app_date_utils.DateUtils.getPaymentMonth(rosterPeriod)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Maaş Özeti',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '€${totalEuro.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '₺${components['total_tl']?.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownList() {
    final List<Map<String, dynamic>> breakdownItems = [
      {'label': 'Base Maaş', 'amount': components['base_pay'] ?? 0, 'color': const Color(0xFF00BFFF)}, // Deep Sky Blue
      {'label': 'Uçuş Tazminatı', 'amount': (components['duty_pay'] ?? 0) + (components['overtime_pay'] ?? 0), 'color': const Color(0xFFFFD700)}, // Gold
      {'label': 'Gece Uçuşları', 'amount': components['night_hours_pay'] ?? 0, 'color': const Color(0xFF9400D3)}, // Dark Violet
      {'label': 'Yatı Görevleri', 'amount': (components['international_overnight_pay'] ?? 0) + (components['domestic_overnight_pay'] ?? 0), 'color': const Color(0xFFFF4500)}, // Orange Red
      {'label': 'Komisyon', 'amount': components['commission'] ?? 0, 'color': const Color(0xFFFF1493)}, // Deep Pink
      {'label': 'İç Hat Komisyon', 'amount': components['ic_hat_komisyon'] ?? 0, 'color': const Color(0xFF228B22)}, // Forest Green
      {'label': 'Sektör Ödemeleri', 'amount': (components['leg3_pay'] ?? 0) + (components['leg4_pay'] ?? 0) + (components['leg5_pay'] ?? 0), 'color': const Color(0xFFFFA500)}, // Orange
      {'label': 'Off Duty', 'amount': components['off_duty_pay'] ?? 0, 'color': const Color(0xFF32CD32)}, // Lime Green
      {'label': '6. Gün', 'amount': components['sixth_day_pay'] ?? 0, 'color': const Color(0xFF4169E1)}, // Royal Blue

    ];

    // Format the detailed breakdown text
    final StringBuffer buffer = StringBuffer();
    
    
    // Base components section
    buffer.writeln('📊 Temel Bileşenler');
    buffer.writeln('────────────────────');
    buffer.writeln('💰 Taban Maaş: €${components['base_pay']?.toStringAsFixed(2)}');
    buffer.writeln('💵 Komisyon: €${components['commission']?.toStringAsFixed(2)}');
    if ((components['ic_hat_komisyon'] ?? 0) > 0) {
      buffer.writeln('🏠 İç Hat Komisyon: ${components['ic_hat_komisyon']?.toStringAsFixed(2)} ₺');
    }
    buffer.writeln('');
    
    // Calculate regular and overtime hours
    final regularHours = dutyHours.clamp(0, 100);
    final overtimeHours = dutyHours > 100 ? dutyHours - 100 : 0;
    
    // Flight hours breakdown with overtime
    buffer.writeln('✈️ Uçuş Süreleri Detayı');
    buffer.writeln('────────────────────');
    buffer.writeln('⏱️ Normal Görev: ${regularHours.toStringAsFixed(1)} saat');
    buffer.writeln('   └─ Ücret: €${components['duty_pay']?.toStringAsFixed(2)}');
    
    if (overtimeHours > 0) {
      buffer.writeln('⚡ Fazla Mesai: ${overtimeHours.toStringAsFixed(1)} saat');
      buffer.writeln('   └─ Ücret: €${components['overtime_pay']?.toStringAsFixed(2)}');
    }
    buffer.writeln('🌙 Gece Uçuşu: ${nightHours.toStringAsFixed(1)} saat');
    buffer.writeln('   └─ Ücret: €${components['night_hours_pay']?.toStringAsFixed(2)}\n');
    
    // Sector payments
    buffer.writeln('🛫 Sektör Ödemeleri');
    buffer.writeln('────────────────────');
    buffer.writeln('3️⃣ Sektör (${legCounts['leg3']} uçuş): €${components['leg3_pay']?.toStringAsFixed(2)}');
    buffer.writeln('4️⃣ Sektör (${legCounts['leg4']} uçuş): €${components['leg4_pay']?.toStringAsFixed(2)}');
    buffer.writeln('5️⃣ Sektör (${legCounts['leg5']} uçuş): €${components['leg5_pay']?.toStringAsFixed(2)}\n');
    
    // Additional payments
    buffer.writeln('📅 Ek Ödemeler');
    buffer.writeln('────────────────────');
    buffer.writeln('🏠 Off to Duty ($offDutyCounts gün): €${components['off_duty_pay']?.toStringAsFixed(2)}');
    buffer.writeln('6️⃣ 6. Gün Ödemesi: €${components['sixth_day_pay']?.toStringAsFixed(2)}');
    buffer.writeln('🏨 Konaklama Ödemeleri:');
    buffer.writeln('   ├─ Yurtiçi (${components['domestic_overnight_count']?.toInt()} gece): €${components['domestic_overnight_pay']?.toStringAsFixed(2)}');
    buffer.writeln('   └─ Yurtdışı (${components['international_overnight_count']?.toInt()} gece): €${components['international_overnight_pay']?.toStringAsFixed(2)}\n');
    
    
    // Total summary
    buffer.writeln('💶 Toplam Özet');
    buffer.writeln('════════════════════');
    buffer.writeln('💰 Toplam (EUR): €${components['total_euro']?.toStringAsFixed(2)}');
    buffer.writeln('💵 Toplam (TL): ${components['total_tl']?.toStringAsFixed(2)} ₺');
    buffer.writeln('💱 Euro Kuru: ${components['euro_rate']?.toStringAsFixed(2)} ₺');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...breakdownItems.map((item) {
          Widget baseItem = _buildBreakdownItem(
            item['label'],
            item['amount'],
            item['color'],
          );

          if (item['details'] != null) {
            final details = item['details'] as List<Map<String, dynamic>>;
            return Column(
              children: [
                baseItem,
                ...details.map((detail) => Padding(
                  padding: const EdgeInsets.only(left: 20, top: 4),
                  child: _buildBreakdownItem(
                    detail['label'],
                    detail['amount'],
                    item['color'].withValues(alpha: 0.7),
                  ),
                )),
              ],
            );
          }

          return baseItem;
        }),
        
        // Second part: detailed text breakdown
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color.fromARGB(255, 30, 84, 121), Color.fromARGB(255, 7, 163, 137)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
           
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.2 * 255).toInt()),
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Text(
              buffer.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownItem(String label, double amount, Color color) {
    // Special handling for İç Hat Komisyon - display in TL
    final isIcHatKomisyon = label == 'İç Hat Komisyon';
    final currencySymbol = isIcHatKomisyon ? '₺' : '€';
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).toInt()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha((0.3 * 255).toInt())),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          Text(
            '$currencySymbol${amount.toStringAsFixed(2)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
