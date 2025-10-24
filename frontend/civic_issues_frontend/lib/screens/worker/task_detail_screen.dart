import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../../providers/language_provider.dart';
import '../../providers/issue_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/issue_model.dart';
import '../../utils/app_colors.dart';
import '../../widgets/web_compatible_image.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/image_viewer.dart';

class TaskDetailScreen extends StatefulWidget {
  final Issue task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  File? _proofImage;
  bool _isSubmitting = false;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.pending;
      case 'assigned':
        return AppColors.inProgress;
      case 'completed':
        return AppColors.success;
      case 'verified':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'assigned':
        return Icons.assignment_ind;
      case 'completed':
        return Icons.check_circle;
      case 'verified':
        return Icons.verified;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status, LanguageProvider languageProvider) {
    switch (status.toLowerCase()) {
      case 'pending':
        return languageProvider.getText('Pending', 'लंबित');
      case 'assigned':
        return languageProvider.getText('Assigned', 'निर्दिष्ट');
      case 'completed':
        return languageProvider.getText('Completed', 'पूर्ण');
      case 'verified':
        return languageProvider.getText('Verified', 'सत्यापित');
      case 'rejected':
        return languageProvider.getText('Rejected', 'अस्वीकृत');
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatPriority(double priority) {
    if (priority >= 0.8) return 'High';
    if (priority >= 0.5) return 'Medium';
    return 'Low';
  }

  Color _getPriorityColor(double priority) {
    if (priority >= 0.8) return AppColors.error;
    if (priority >= 0.5) return AppColors.warning;
    return AppColors.success;
  }

  Future<void> _pickProofImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _proofImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _submitCompletion() async {
    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false)
              .getText('Please take a proof photo', 'कृपया प्रमाण फोटो लें')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 🔒 STEP 1: Get Current GPS Location
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(languageProvider.getText(
              'Getting your current location...',
              'आपका वर्तमान स्थान प्राप्त किया जा रहा है...')),
          duration: const Duration(seconds: 2),
        ),
      );

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception(languageProvider.getText(
              'Location permission denied. GPS verification is required to complete tasks.',
              'स्थान अनुमति अस्वीकृत। कार्य पूरा करने के लिए GPS सत्यापन आवश्यक है।'));
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(languageProvider.getText(
            'Location permissions are permanently denied. Please enable in settings.',
            'स्थान अनुमतियां स्थायी रूप से अस्वीकृत हैं। कृपया सेटिंग में सक्षम करें।'));
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // 🔒 STEP 2: Submit with GPS verification
      final issueProvider = Provider.of<IssueProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.token == null) {
        throw Exception('No authentication token available');
      }

      final success = await issueProvider.completeTask(
        widget.task.id.toString(),
        _proofImage!,
        position.latitude,
        position.longitude,
        authProvider.token!,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(languageProvider.getText(
                  'Task completed successfully! ✅',
                  'कार्य सफलतापूर्वक पूरा! ✅')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          // GPS verification error will be in issueProvider.error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(issueProvider.error ??
                  languageProvider.getText(
                      'Failed to complete task', 'कार्य पूरा करने में असफल')),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Provider.of<LanguageProvider>(context, listen: false)
            .getText('Error', 'त्रुटि')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(Provider.of<LanguageProvider>(context, listen: false)
                .getText('OK', 'ठीक है')),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(LanguageProvider languageProvider, Issue task) {
    final feedback = task.feedback.first;
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.feedback,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  languageProvider.getText('Citizen Feedback', 'नागरिक प्रतिक्रिया'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          // Rating
          Row(
            children: [
              Text(
                languageProvider.getText('Rating:', 'रेटिंग:'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < feedback.rating ? Icons.star : Icons.star_border,
                    color: AppColors.warning,
                    size: 24,
                  );
                }),
              ),
              const SizedBox(width: 8),
              Text(
                '${feedback.rating}/5',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Comment
          if (feedback.comment.isNotEmpty) ...[
            Text(
              languageProvider.getText('Comment:', 'टिप्पणी:'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                feedback.comment,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
          
          // Sentiment (if available)
          if (feedback.sentiment != null && feedback.sentiment!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: feedback.sentiment!.toLowerCase() == 'positive'
                    ? AppColors.success.withValues(alpha: 0.1)
                    : feedback.sentiment!.toLowerCase() == 'negative'
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    feedback.sentiment!.toLowerCase() == 'positive'
                        ? Icons.sentiment_satisfied
                        : feedback.sentiment!.toLowerCase() == 'negative'
                            ? Icons.sentiment_dissatisfied
                            : Icons.sentiment_neutral,
                    size: 16,
                    color: feedback.sentiment!.toLowerCase() == 'positive'
                        ? AppColors.success
                        : feedback.sentiment!.toLowerCase() == 'negative'
                            ? AppColors.error
                            : AppColors.info,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    languageProvider.getText(
                      feedback.sentiment!,
                      feedback.sentiment!,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: feedback.sentiment!.toLowerCase() == 'positive'
                          ? AppColors.success
                          : feedback.sentiment!.toLowerCase() == 'negative'
                              ? AppColors.error
                              : AppColors.info,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final task = widget.task;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          languageProvider.getText('Task Details', 'कार्य विवरण'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.workerColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
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
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getStatusColor(task.status)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getStatusIcon(task.status),
                          color: _getStatusColor(task.status),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getStatusText(task.status, languageProvider),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(task.status),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              languageProvider.getText(
                                  'Current Status', 'वर्तमान स्थिति'),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          languageProvider.getText('Priority', 'प्राथमिकता'),
                          _formatPriority(task.priority),
                          _getPriorityColor(task.priority),
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          languageProvider.getText('Category', 'श्रेणी'),
                          task.problemType,
                          AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Task Information
            _buildSection(
              languageProvider.getText('Task Information', 'कार्य जानकारी'),
              [
                _buildInfoRow(
                  languageProvider.getText('Title', 'शीर्षक'),
                  task.title,
                ),
                _buildInfoRow(
                  languageProvider.getText('Description', 'विवरण'),
                  task.description,
                ),
                _buildInfoRow(
                  languageProvider.getText('Location', 'स्थान'),
                  task.location ?? 'Location not available',
                ),
                if (task.latitude != null && task.longitude != null)
                  _buildInfoRow(
                    languageProvider.getText('Coordinates', 'निर्देशांक'),
                    '${task.latitude!.toStringAsFixed(6)}, ${task.longitude!.toStringAsFixed(6)}',
                  ),
                _buildInfoRow(
                  languageProvider.getText('Assigned', 'निर्दिष्ट'),
                  _formatDate(task.createdAt),
                ),
                if (task.updatedAt != null)
                  _buildInfoRow(
                    languageProvider.getText('Last Updated', 'अंतिम अपडेट'),
                    _formatDate(task.updatedAt!),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // Media Files
            if (task.mediaFiles.isNotEmpty)
              ImageGallery(
                mediaFiles: task.mediaFiles
                    .map((media) => {
                          'file_url': media.fileUrl,
                          'media_type': media.mediaType,
                        })
                    .toList(),
                title: languageProvider.getText(
                    'Reference Images', 'संदर्भ छवियां'),
              ),

            const SizedBox(height: 20),

            // Feedback Section - Show if task has feedback (for completed/verified tasks)
            if (task.feedback.isNotEmpty)
              _buildFeedbackSection(languageProvider, task),

            const SizedBox(height: 20),

            // Completion Section
            if (task.status.toLowerCase() == 'assigned')
              _buildCompletionSection(languageProvider),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
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
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionSection(LanguageProvider languageProvider) {
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
            languageProvider.getText('Complete Task', 'कार्य पूरा करें'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    languageProvider.getText(
                        '⚠️ GPS Verification Required: You must be at the problem location (within 500 meters) to complete this task.',
                        '⚠️ GPS सत्यापन आवश्यक: इस कार्य को पूरा करने के लिए आपको समस्या स्थान पर (500 मीटर के भीतर) होना चाहिए।'),
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            languageProvider.getText('Take a photo as proof of completion:',
                'पूर्णता के प्रमाण के रूप में एक फोटो लें:'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 16),

          // Proof Image Preview
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: _proofImage != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: WebCompatibleImage(
                          file: _proofImage!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _proofImage = null;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.camera_alt,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          languageProvider.getText(
                              'No proof photo', 'कोई प्रमाण फोटो नहीं'),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 16),

          // Take Photo Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickProofImage,
              icon: const Icon(Icons.camera_alt),
              label: Text(
                languageProvider.getText('Take Proof Photo', 'प्रमाण फोटो लें'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.workerColor,
                side: const BorderSide(color: AppColors.workerColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Submit Button
          CustomButton(
            text: languageProvider.getText(
                'Mark as Completed', 'पूर्ण के रूप में चिह्नित करें'),
            onPressed: _isSubmitting ? null : _submitCompletion,
            isLoading: _isSubmitting,
            backgroundColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}


