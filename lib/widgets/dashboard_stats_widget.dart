import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DashboardStatsWidget extends StatelessWidget {
  final String totalDonated;
  final int charitiesSupported;
  final int impactScore;
  final int totalDonations;

  const DashboardStatsWidget({
    super.key,
    required this.totalDonated,
    required this.charitiesSupported,
    required this.impactScore,
    required this.totalDonations,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatCard(
            icon: Icons.favorite,
            label: 'Total Donated',
            value: '$totalDonated ETH',
            description: '$totalDonations donations completed',
            borderColor: AppTheme.blue100,
            textColor: const Color(0xFF1E3A8A), // blue-900
            labelColor: const Color(0xFF1E40AF), // blue-800
            descColor: AppTheme.blue600,
            gradientColors: const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)], // blue-50 to blue-100/50
          ),
          const SizedBox(width: 16),
          _StatCard(
            icon: Icons.people,
            label: 'Charities Supported',
            value: charitiesSupported.toString(),
            description: 'Organizations helped',
            borderColor: AppTheme.green100,
            textColor: const Color(0xFF14532D), // green-900
            labelColor: const Color(0xFF166534), // green-800
            descColor: AppTheme.green600,
            gradientColors: const [Color(0xFFF0FDF4), Color(0xFFDCFCE7)], // green-50 to green-100/50
          ),
          const SizedBox(width: 16),
          _StatCard(
            icon: Icons.emoji_events,
            label: 'Community Score',
            value: impactScore.toString(),
            description: 'Your contribution level',
            borderColor: const Color(0xFFF3E8FF), // purple-100
            textColor: const Color(0xFF581C87), // purple-900
            labelColor: const Color(0xFF6B21A8), // purple-800
            descColor: const Color(0xFF9333EA), // purple-600
            gradientColors: const [Color(0xFFFAF5FF), Color(0xFFF3E8FF)], // purple-50 to purple-100/50
            showTrending: true,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String description;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;
  final Color descColor;
  final List<Color> gradientColors;
  final bool showTrending;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.description,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    required this.descColor,
    required this.gradientColors,
    this.showTrending = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 224, // w-56 = 224px
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                ),
                Icon(icon, color: descColor, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (showTrending) ...[  
                  Icon(Icons.trending_up, size: 12, color: descColor),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: descColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
