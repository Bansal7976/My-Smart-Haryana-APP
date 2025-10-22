import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_colors.dart';

class ImageGallery extends StatelessWidget {
  final List<Map<String, dynamic>> mediaFiles;
  final String title;

  const ImageGallery({
    super.key,
    required this.mediaFiles,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (mediaFiles.isEmpty)
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      color: AppColors.textSecondary,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No images available',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: mediaFiles.length,
              itemBuilder: (context, index) {
                final media = mediaFiles[index];
                return _buildImageItem(media);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildImageItem(Map<String, dynamic> media) {
    final fileUrl = media['file_url'] as String?;
    final mediaType = media['media_type'] as String?;

    return GestureDetector(
      onTap: () {
        // You can implement image viewer here
        _showImageDialog(fileUrl ?? '');
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: _buildImageWidget(fileUrl),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mediaType ?? 'Unknown',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to view',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
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

  Widget _buildImageWidget(String? fileUrl) {
    if (fileUrl == null || fileUrl.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: const Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 32,
        ),
      );
    }

    // For web compatibility, we'll use Image.network
    if (kIsWeb) {
      return Image.network(
        fileUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[300],
          child: const Icon(
            Icons.error,
            color: Colors.red,
            size: 32,
          ),
        ),
      );
    } else {
      // For mobile, try to create a File from the URL
      // This is a simplified approach - in a real app you'd want to download and cache images
      return Image.network(
        fileUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[300],
          child: const Icon(
            Icons.error,
            color: Colors.red,
            size: 32,
          ),
        ),
      );
    }
  }

  void _showImageDialog(String imageUrl) {
    // This would typically show a full-screen image viewer
    // For now, we'll just show a placeholder
    // TODO: Implement full-screen image viewer
  }
}

