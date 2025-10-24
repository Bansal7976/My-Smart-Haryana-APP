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

    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          // You can implement image viewer here
          _showImageDialog(context, fileUrl ?? '');
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
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
                  const Text(
                    'Tap to view',
                    style: TextStyle(
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

    // Construct full URL if relative path
    final String fullUrl;
    if (fileUrl.startsWith('http://') || fileUrl.startsWith('https://')) {
      fullUrl = fileUrl;
    } else {
      // Assume it's a relative path like "uploads/filename.jpg"
      const baseUrl = 'http://192.168.5.19:8000';
      fullUrl = fileUrl.startsWith('/') ? '$baseUrl$fileUrl' : '$baseUrl/$fileUrl';
    }

    // For web compatibility, we'll use Image.network
    if (kIsWeb) {
      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
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
      // For mobile, use network image
      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
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

  void _showImageDialog(BuildContext context, String imageUrl) {
    // Construct full URL for viewing
    String fullUrl;
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      fullUrl = imageUrl;
    } else {
      const baseUrl = 'http://192.168.5.19:8000';
      fullUrl = imageUrl.startsWith('/') ? '$baseUrl$imageUrl' : '$baseUrl/$imageUrl';
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            fullUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              padding: const EdgeInsets.all(20),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 48),
                  SizedBox(height: 8),
                  Text('Failed to load image'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


