import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/charity.dart';
import '../theme/app_theme.dart';
import '../utils/formatting_utils.dart';

class CharityCardWidget extends StatelessWidget {
  final Charity charity;
  final VoidCallback onTap;

  const CharityCardWidget({
    super.key,
    required this.charity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasGoal = charity.goal > 0;
    final progressValue = hasGoal
        ? (charity.raised / charity.goal).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final progressLabel = hasGoal
        ? '${formatEth(charity.raised)}/${formatEth(charity.goal)} ETH'
        : '${formatEth(charity.raised)} ETH raised';
    final footerLabel = hasGoal
        ? '${charity.progress.toStringAsFixed(0)}% funded'
        : 'Goal not set';

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.slate200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: charity.image,
                  height: 64, // h-16 = 64px
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 64,
                    color: AppTheme.slate100,
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 64,
                    color: AppTheme.slate100,
                    child: const Icon(Icons.image_not_supported, size: 24),
                  ),
                ),
                if (charity.verified)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.green600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '✓',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 32, // min-h-[1.5rem] with 2 lines
                    child: Text(
                      charity.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate800,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Progress info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Progress',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.slate600,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          progressLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.slate800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Progress bar - h-1 = 4px
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: AppTheme.slate200,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppTheme.blue600),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    footerLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.slate600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
