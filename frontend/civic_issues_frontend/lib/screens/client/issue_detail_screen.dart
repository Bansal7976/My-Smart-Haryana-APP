import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/issue_provider.dart';
import '../../models/issue_model.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_button.dart';
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
      
      final detailedIssue = await issueProvider.getIssueDetails(widget.issue.id.toString(), authProvider.token!);
      
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
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        languageProvider.getText(
                          'Failed to load issue details',
                          'समस्या विवरण लोड करने में असफल'
                        ),
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
                                      color: _getStatusColor(issue.status).withValues(alpha: 0.1),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getStatusText(issue.status, languageProvider),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: _getStatusColor(issue.status),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          languageProvider.getText(
                                            'Current Status',
                                            'वर्तमान स्थिति'
                                          ),
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
                                      _formatPriority(issue.priority),
                                      _getPriorityColor(issue.priority),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildInfoItem(
                                      languageProvider.getText('Category', 'श्रेणी'),
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
                          languageProvider.getText('Issue Information', 'समस्या की जानकारी'),
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
                              issue.location ?? 'Location not available',
                            ),
                            if (issue.latitude != null && issue.longitude != null)
                              _buildInfoRow(
                                languageProvider.getText('Coordinates', 'निर्देशांक'),
                                '${issue.latitude!.toStringAsFixed(6)}, ${issue.longitude!.toStringAsFixed(6)}',
                              ),
                            _buildInfoRow(
                              languageProvider.getText('Created', 'बनाया गया'),
                              _formatDate(issue.createdAt),
                            ),
                            if (issue.updatedAt != null)
                              _buildInfoRow(
                                languageProvider.getText('Last Updated', 'अंतिम अपडेट'),
                                _formatDate(issue.updatedAt!),
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Assignment Information
                        if (issue.assignedTo != null)
                          _buildSection(
                            languageProvider.getText('Assignment Information', 'निर्देशन जानकारी'),
                            [
                              _buildInfoRow(
                                languageProvider.getText('Assigned To', 'निर्दिष्ट किया गया'),
                                '${issue.assignedTo!.user.fullName} (${issue.assignedTo!.department.name})',
                              ),
                            ],
                          ),

                        const SizedBox(height: 20),

                        // Media Files
                        if (issue.mediaFiles.isNotEmpty)
                          ImageGallery(
                            mediaFiles: issue.mediaFiles.map((media) => {
                              'file_url': media.fileUrl,
                              'media_type': media.mediaType,
                            }).toList(),
                            title: languageProvider.getText('Attachments', 'संलग्नक'),
                          ),

                        const SizedBox(height: 20),

                        // Actions
                        if (issue.status.toLowerCase() == 'completed')
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

  Widget _buildActionSection(LanguageProvider languageProvider, Issue issue) {
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
              'Verify Completion',
              'पूर्णता सत्यापित करें'
            ),
            onPressed: () {
              _showVerificationDialog(languageProvider, issue);
            },
            backgroundColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  void _showVerificationDialog(LanguageProvider languageProvider, Issue issue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.getText(
          'Verify Completion',
          'पूर्णता सत्यापित करें'
        )),
        content: Text(languageProvider.getText(
          'Are you satisfied with the work done? This will mark the issue as verified.',
          'क्या आप किए गए काम से संतुष्ट हैं? यह समस्या को सत्यापित के रूप में चिह्नित करेगा।'
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(languageProvider.getText('Cancel', 'रद्द करें')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _verifyIssue(issue);
            },
            child: Text(languageProvider.getText('Verify', 'सत्यापित करें')),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyIssue(Issue issue) async {
    try {
      // This would call the backend API to verify the issue
      // For now, we'll just show a success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false)
                .getText('Issue verified successfully!', 'समस्या सफलतापूर्वक सत्यापित!')),
            backgroundColor: AppColors.success,
          ),
        );
        await _refreshIssue();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${Provider.of<LanguageProvider>(context, listen: false)
                .getText('Failed to verify issue', 'समस्या सत्यापित करने में असफल')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}