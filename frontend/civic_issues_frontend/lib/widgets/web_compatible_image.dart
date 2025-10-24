import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class WebCompatibleImage extends StatelessWidget {
  final File? file;
  final String? networkUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorBuilder;

  const WebCompatibleImage({
    super.key,
    this.file,
    this.networkUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // For web platform, we can't use Image.file
    if (kIsWeb) {
      // On web, we need to convert the file to a network URL or use a placeholder
      if (networkUrl != null) {
        return Image.network(
          networkUrl!,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: errorBuilder != null 
            ? (context, error, stackTrace) => errorBuilder!
            : (context, error, stackTrace) => Container(
                width: width,
                height: height,
                color: Colors.grey[300],
                child: const Icon(Icons.error, color: Colors.red),
              ),
        );
      } else {
        // Show placeholder for web when no network URL is available
        return Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.image, color: Colors.grey),
        );
      }
    } else {
      // For mobile platforms, use Image.file
      if (file != null) {
        return Image.file(
          file!,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: errorBuilder != null 
            ? (context, error, stackTrace) => errorBuilder!
            : (context, error, stackTrace) => Container(
                width: width,
                height: height,
                color: Colors.grey[300],
                child: const Icon(Icons.error, color: Colors.red),
              ),
        );
      } else {
        return Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.image, color: Colors.grey),
        );
      }
    }
  }
}




