import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class HaryanaLogoSmall extends StatelessWidget {
  final double size;
  final Color? color;

  const HaryanaLogoSmall({
    super.key,
    this.size = 32,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
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
  }
}



