import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/issue_provider.dart';
import '../../services/api_service.dart';
import '../../models/issue_model.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/image_viewer.dart';

class IssueDetailScreen extends StatefulWidget {
  final Issue issue;

  const IssueDetailScreen({super.key, required this.issue});

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  Issue? _detailedIssue;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIssueDetails();
  }

  Future<void> _loadIssueDetails() async {
    try {
      final issueProvider = Provider.of<IssueProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.token == null) {
        throw Exception('No authentication token available');
      }

      final detailedIssue = await issueProvider.getIssueDetails(
          widget.issue.id.toString(), authProvider.token!);

      setState(() {
        _detailedIssue = detailedIssue ?? widget.issue;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshIssue() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _loadIssueDetails();
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return AppColors.pending;
      case 'ASSIGNED':
        return AppColors.inProgress;
      case 'COMPLETED':
        return AppColors.success;
      case 'VERIFIED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Icons.schedule;
      case 'ASSIGNED':
        return Icons.assignment_ind;
      case 'COMPLETED':
        return Icons.check_circle;
      case 'VERIFIED':
        return Icons.verified;
      case 'REJECTED':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status, LanguageProvider languageProvider) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return languageProvider.getText('Pending', 'लंबित');
      case 'ASSIGNED':
        return languageProvider.getText('Assigned', 'निर्दिष्ट');
      case 'COMPLETED':
        return languageProvider.getText('Completed', 'पूर्ण');
      case 'VERIFIED':
        return languageProvider.getText('Verified', 'सत्यापित');
      case 'REJECTED':
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

  Future<void> _showEditDialog(Issue issue, LanguageProvider languageProvider) async {
    final titleController = TextEditingController(text: issue.title);
    final descriptionController = TextEditingController(text: issue.description);

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                languageProvider.getText('Edit Issue', 'समस्या संपादित करें'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: titleController,
                label: languageProvider.getText('Title', 'शीर्षक'),
                hint: languageProvider.getText('Enter issue title', 'समस्या शीर्षक दर्ज करें'),
                prefixIcon: Icons.title,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: descriptionController,
                label: languageProvider.getText('Description', 'विवरण'),
                hint: languageProvider.getText('Enter issue description', 'समस्या विवरण दर्ज करें'),
                prefixIcon: Icons.description,
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(languageProvider.getText('Cancel', 'रद्द करें')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _updateIssue(
                issue.id,
                titleController.text,
                descriptionController.text,
                languageProvider,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(languageProvider.getText('Update', 'अपडेट करें')),
          ),
        ],
      ),
    );
  }

  Future<void> _updateIssue(
    int issueId,
    String title,
    String description,
    LanguageProvider languageProvider,
  ) async {
    if (title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(languageProvider.getText(
            'Title cannot be empty',
            'शीर्षक खाली नहीं हो सकता'
          )),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await ApiService.updateIssue(
        authProvider.token!,
        issueId,
        title,
        description,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(languageProvider.getText(
            'Issue updated successfully!',
            'समस्या सफलतापूर्वक अपडेट की गई!'
          )),
          backgroundColor: AppColors.success,
        ),
      );

      await _refreshIssue();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${languageProvider.getText('Failed to update', 'अपडेट करने में विफल')}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmation(Issue issue, LanguageProvider languageProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                languageProvider.getText('Delete Issue?', 'समस्या हटाएं?'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              languageProvider.getText(
                'Are you sure you want to delete this issue? This action cannot be undone.',
                'क्या आप वाकई इस समस्या को हटाना चाहते हैं? यह क्रिया पूर्ववत नहीं की जा सकती।'
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      languageProvider.getText(
                        '⚠️ 10 civic points will be deducted',
                        '⚠️ 10 नागरिक अंक काटे जाएंगे'
                      ),
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(languageProvider.getText('Cancel', 'रद्द करें')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(languageProvider.getText('Delete', 'हटाएं')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteIssue(issue.id, languageProvider);
    }
  }

  Future<void> _deleteIssue(int issueId, LanguageProvider languageProvider) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await ApiService.deleteIssue(authProvider.token!, issueId);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading
      Navigator.of(context).pop(); // Close detail screen

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(languageProvider.getText(
            'Issue deleted successfully! 10 civic points deducted.',
            'समस्या सफलतापूर्वक हटा दी गई! 10 नागरिक अंक काटे गए।'
          )),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${languageProvider.getText('Failed to delete', 'हटाने में विफल')}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final issue = _detailedIssue ?? widget.issue;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          languageProvider.getText('Issue Details', 'समस्या विवरण'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Show edit and delete buttons only for PENDING or ASSIGNED status
          if (issue.status.toLowerCase() == 'pending' || issue.status.toLowerCase() == 'assigned') ...[
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => _showEditDialog(issue, languageProvider),
              tooltip: languageProvider.getText('Edit Issue', 'समस्या संपादित करें'),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: () => _showDeleteConfirmation(issue, languageProvider),
              tooltip: languageProvider.getText('Delete Issue', 'समस्या हटाएं'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshIssue,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        languageProvider.getText('Failed to load issue details',
                            'समस्या विवरण लोड करने में असफल'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        text: languageProvider.getText('Retry', 'पुनः प्रयास'),
                        onPressed: _refreshIssue,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshIssue,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                                      color: _getStatusColor(issue.status)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _getStatusIcon(issue.status),
                                      color: _getStatusColor(issue.status),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getStatusText(
                                              issue.status, languageProvider),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                _getStatusColor(issue.status),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          languageProvider.getText(
                                              'Current Status',
                                              'वर्तमान स्थिति'),
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
                                      languageProvider.getText(
                                          'Priority', 'प्राथमिकता'),
                                      _formatPriority(issue.priority),
                                      _getPriorityColor(issue.priority),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildInfoItem(
                                      languageProvider.getText(
                                          'Category', 'श्रेणी'),
                                      issue.problemType,
                                      AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Issue Information
                        _buildSection(
                          languageProvider.getText(
                              'Issue Information', 'समस्या की जानकारी'),
                          [
                            _buildInfoRow(
                              languageProvider.getText('Title', 'शीर्षक'),
                              issue.title,
                            ),
                            _buildInfoRow(
                              languageProvider.getText('Description', 'विवरण'),
                              issue.description,
                            ),
                            _buildInfoRow(
                              languageProvider.getText('Location', 'स्थान'),
                              issue.location ?? (issue.latitude != null && issue.longitude != null 
                                  ? '${issue.latitude!.toStringAsFixed(6)}, ${issue.longitude!.toStringAsFixed(6)}'
                                  : 'Location not available'),
                            ),
                            if (issue.latitude != null &&
                                issue.longitude != null)
                              _buildInfoRow(
                                languageProvider.getText(
                                    'Coordinates', 'निर्देशांक'),
                                '${issue.latitude!.toStringAsFixed(6)}, ${issue.longitude!.toStringAsFixed(6)}',
                              ),
                            _buildInfoRow(
                              languageProvider.getText('Created', 'बनाया गया'),
                              _formatDate(issue.createdAt),
                            ),
                            if (issue.updatedAt != null)
                              _buildInfoRow(
                                languageProvider.getText(
                                    'Last Updated', 'अंतिम अपडेट'),
                                _formatDate(issue.updatedAt!),
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Assignment Information
                        if (issue.assignedTo != null)
                          _buildSection(
                            languageProvider.getText(
                                'Assignment Information', 'निर्देशन जानकारी'),
                            [
                              _buildInfoRow(
                                languageProvider.getText(
                                    'Assigned To', 'निर्दिष्ट किया गया'),
                                '${issue.assignedTo!.user.fullName} (${issue.assignedTo!.department.name})',
                              ),
                            ],
                          ),

                        const SizedBox(height: 20),

                        // Media Files
                        if (issue.mediaFiles.isNotEmpty)
                          ImageGallery(
                            mediaFiles: issue.mediaFiles
                                .map((media) => {
                                      'file_url': media.fileUrl,
                                      'media_type': media.mediaType,
                                    })
                                .toList(),
                            title: languageProvider.getText(
                                'Attachments', 'संलग्नक'),
                          ),

                        const SizedBox(height: 20),

                        // Feedback Section
                        if (issue.feedback.isNotEmpty)
                          _buildFeedbackSection(languageProvider, issue),

                        // Actions
                        if (issue.status.toLowerCase() == 'completed' && issue.feedback.isEmpty)
                          _buildActionSection(languageProvider, issue),

                        const SizedBox(height: 20),
                      ],
                    ),
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

  Widget _buildFeedbackSection(LanguageProvider languageProvider, Issue issue) {
    final feedback = issue.feedback.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                languageProvider.getText('Your Feedback', 'आपकी प्रतिक्रिया'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    color: AppColors.primary,
                    onPressed: () => _showEditFeedbackDialog(languageProvider, issue, feedback),
                    tooltip: languageProvider.getText('Edit', 'संपादित करें'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    color: AppColors.error,
                    onPressed: () => _deleteFeedback(languageProvider, feedback.id),
                    tooltip: languageProvider.getText('Delete', 'हटाएं'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                languageProvider.getText('Rating:', 'रेटिंग:'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < feedback.rating ? Icons.star : Icons.star_border,
                    color: AppColors.warning,
                    size: 20,
                  );
                }),
              ),
              const SizedBox(width: 8),
              Text(
                '${feedback.rating}/5',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (feedback.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              languageProvider.getText('Comment:', 'टिप्पणी:'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              feedback.comment,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ],
          if (feedback.sentiment != null && feedback.sentiment!.isNotEmpty) ...[
            const SizedBox(height: 12),
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

  void _showEditFeedbackDialog(LanguageProvider languageProvider, Issue issue, dynamic feedback) {
    int rating = feedback.rating;
    final commentController = TextEditingController(text: feedback.comment);
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: StatefulBuilder(
                builder: (context, setDialogState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.getText('Edit Feedback', 'फीडबैक संपादित करें'),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Rating
                    Text(
                      languageProvider.getText('Rating', 'रेटिंग'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              rating = index + 1;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: Icon(
                              index < rating ? Icons.star : Icons.star_border,
                              color: AppColors.warning,
                              size: 32,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    
                    // Comment
                    CustomTextField(
                      controller: commentController,
                      label: languageProvider.getText('Comment', 'टिप्पणी'),
                      hint: languageProvider.getText(
                        'Share your experience...',
                        'अपना अनुभव साझा करें...'
                      ),
                      maxLines: 4,
                      prefixIcon: Icons.comment,
                    ),
                    const SizedBox(height: 24),
                    
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.border, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              languageProvider.getText('Cancel', 'रद्द करें'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              _updateFeedback(
                                feedback.id,
                                rating,
                                commentController.text,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              languageProvider.getText('Update', 'अपडेट करें'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateFeedback(int feedbackId, int rating, String comment) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final issueProvider = Provider.of<IssueProvider>(context, listen: false);

    try {
      if (authProvider.token == null) {
        throw Exception('No authentication token');
      }

      await ApiService.updateFeedback(
        authProvider.token!,
        feedbackId,
        {
          'comment': comment.isEmpty ? 'Work completed satisfactorily' : comment,
          'rating': rating,
        },
      );

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(languageProvider.getText(
              'Feedback updated successfully!',
              'फीडबैक सफलतापूर्वक अपडेट किया गया!')),
          backgroundColor: AppColors.success,
        ),
      );

      // Reload issues
      await issueProvider.loadUserIssues(authProvider.token!);
      if (mounted) {
        Navigator.of(context).pop(); // Go back to refresh the detail screen
      }
    } catch (e) {
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
              '${languageProvider.getText('Failed to update feedback', 'फीडबैक अपडेट करने में विफल')}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteFeedback(LanguageProvider languageProvider, int feedbackId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.getText('Confirm Delete', 'हटाने की पुष्टि करें')),
        content: Text(
          languageProvider.getText(
            'Are you sure you want to delete this feedback?',
            'क्या आप वाकई इस फीडबैक को हटाना चाहते हैं?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(languageProvider.getText('Cancel', 'रद्द करें')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(languageProvider.getText('Delete', 'हटाएं')),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final issueProvider = Provider.of<IssueProvider>(context, listen: false);

    try {
      if (authProvider.token == null) {
        throw Exception('No authentication token');
      }

      await ApiService.deleteFeedback(authProvider.token!, feedbackId);

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(languageProvider.getText(
              'Feedback deleted successfully',
              'फीडबैक सफलतापूर्वक हटाया गया')),
          backgroundColor: AppColors.success,
        ),
      );

      // Reload issues
      await issueProvider.loadUserIssues(authProvider.token!);
      if (mounted) {
        Navigator.of(context).pop(); // Go back to refresh the detail screen
      }
    } catch (e) {
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
              '${languageProvider.getText('Failed to delete feedback', 'फीडबैक हटाने में विफल')}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildActionSection(LanguageProvider languageProvider, Issue issue) {
    // Only show the button if status is 'completed' (not verified yet)
    if (issue.status.toLowerCase() != 'completed') {
      return const SizedBox.shrink();
    }
    
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
            languageProvider.getText('Actions', 'कार्य'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: languageProvider.getText(
                'Submit Feedback & Verify', 'फीडबैक दें और सत्यापित करें'),
            onPressed: () {
              _showFeedbackDialog(languageProvider, issue);
            },
            backgroundColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(LanguageProvider languageProvider, Issue issue) {
    int rating = 5;
    final commentController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 5,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Header with Icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.success, AppColors.success.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.rate_review,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.getText('Submit Feedback', 'फीडबैक दें'),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            languageProvider.getText('Rate the completed work', 'पूर्ण कार्य को रेट करें'),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary.withValues(alpha: 0.8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),
                
                // Rating Question
                Text(
                  languageProvider.getText(
                    'How satisfied are you with the work?',
                    'आप काम से कितने संतुष्ट हैं?',
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Star Rating with Animation
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                rating = index + 1;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: Icon(
                                index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: index < rating ? AppColors.warning : AppColors.textSecondary.withValues(alpha: 0.4),
                                size: 40,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$rating ${languageProvider.getText("out of", "में से")} 5 ⭐',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Comment TextField
                TextField(
                  controller: commentController,
                  decoration: InputDecoration(
                    labelText: languageProvider.getText(
                      'Your Comments (Optional)',
                      'आपकी टिप्पणियाँ (वैकल्पिक)',
                    ),
                    labelStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    hintText: languageProvider.getText(
                      'Share your experience...',
                      'अपना अनुभव साझा करें...',
                    ),
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  maxLines: 3,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          languageProvider.getText('Cancel', 'रद्द करें'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _submitFeedbackAndVerify(
                            issue,
                            rating,
                            commentController.text,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          shadowColor: AppColors.success.withValues(alpha: 0.4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                languageProvider.getText('Submit & Verify', 'सबमिट करें'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitFeedbackAndVerify(
      Issue issue, int rating, String comment) async {
    // Capture context references BEFORE any async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      if (authProvider.token == null) {
        throw Exception('No authentication token');
      }

      // Step 1: Submit feedback first
      await ApiService.submitFeedback(
        authProvider.token!,
        issue.id.toString(),
        {
          'comment': comment.isEmpty ? 'Work completed satisfactorily' : comment,
          'rating': rating,
        },
      );

      // Step 2: Try to verify issue (only if not already verified)
      if (issue.status.toLowerCase() == 'completed') {
        try {
          await ApiService.verifyIssueCompletion(
            authProvider.token!,
            issue.id.toString(),
          );
          
          if (!mounted) return;
          
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(languageProvider.getText(
                  'Feedback submitted and issue verified!',
                  'फीडबैक सबमिट किया गया और समस्या सत्यापित!')),
              backgroundColor: AppColors.success,
            ),
          );
        } catch (verifyError) {
          // If verification fails (already verified), just show feedback success
          if (!mounted) return;
          
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(languageProvider.getText(
                  'Feedback submitted successfully!',
                  'फीडबैक सफलतापूर्वक सबमिट किया गया!')),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        // Issue is already verified, just show feedback success
        if (!mounted) return;
        
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(languageProvider.getText(
                'Feedback submitted successfully!',
                'फीडबैक सफलतापूर्वक सबमिट किया गया!')),
            backgroundColor: AppColors.success,
          ),
        );
      }
      
      await _refreshIssue();
    } catch (e) {
      if (!mounted) return;
      
      // Extract meaningful error message
      String errorMessage = e.toString();
      if (errorMessage.contains('Exception:')) {
        errorMessage = errorMessage.replaceAll('Exception:', '').trim();
      }
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
              '${languageProvider.getText('Failed to submit feedback', 'फीडबैक सबमिट करने में विफल')}: $errorMessage'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

