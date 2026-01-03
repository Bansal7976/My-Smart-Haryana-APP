import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class HaryanaLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final String text;
  final Color? color;

  const HaryanaLogo({
    super.key,
    this.size = 80,
    this.showText = true,
    this.text = 'Smart Haryana',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size / 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size / 4),
            child: Image.asset(
              'assets/images/haryana_logo.jpg',
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to icon if image not found
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: color ?? AppColors.primary,
                    borderRadius: BorderRadius.circular(size / 4),
                  ),
                  child: Icon(
                    Icons.location_city,
                    size: size * 0.6,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: size * 0.2,
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
