import 'package:flutter/material.dart';
import 'neumorphic_card.dart';

class LegalityInfoDialog extends StatelessWidget {
  const LegalityInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: NeumorphicCard(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFFED6C02),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'FTL Rules Reference',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 3,
                width: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFED6C02),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection(
                        'Minimum Rest Period',
                        'SHT-FTL ORO.FTL.235(a)',
                        '• Home Base: 12 hours minimum\n'
                        '• Away from Base: 10 hours minimum\n'
                        '• Must include 8 hours sleep opportunity',
                      ),
                      const SizedBox(height: 16),
                      _buildInfoSection(
                        '±2 Hour Time Frame',
                        'Company Rule 2.g',
                        '• Changes within ±2h: No agreement needed\n'
                        '• Changes >2h: Mutual agreement required\n'
                        '• Applies to flight departure times',
                      ),
                      const SizedBox(height: 16),
                      _buildInfoSection(
                        'Assignment Notice',
                        'Company Rule 2.h',
                        '• Minimum 12h between notification and duty\n'
                        '• Ensures adequate rest and preparation\n'
                        '• Exception: After crew pickup',
                      ),
                      const SizedBox(height: 16),
                      _buildInfoSection(
                        'Standby (SBY)',
                        'SHT-FTL CS FTL.1.225(b)',
                        '• Maximum 16 hours duration\n'
                        '• FDP reduced if standby >6h\n'
                        '• Combined standby + FDP ≤16h',
                      ),
                      const SizedBox(height: 16),
                      _buildInfoSection(
                        'Reserve (RZV)',
                        'SHT-FTL IR ORO.FTL.230',
                        '• Minimum 10h notice before duty\n'
                        '• Must include 8h undisturbed period\n'
                        '• 25% counted as duty time',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFED6C02),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, String reference, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reference,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Color(0xFFFFA726),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Usage example: Add info button to header
// In _buildHeader() method, add:
/*
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Row(
      children: [
        const Icon(...),
        const Text(...),
      ],
    ),
    IconButton(
      icon: const Icon(
        Icons.info_outline,
        color: Color(0xFFED6C02),
        size: 28,
      ),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => const LegalityInfoDialog(),
        );
      },
    ),
  ],
)
*/