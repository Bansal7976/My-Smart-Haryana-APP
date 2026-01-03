import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/issue_provider.dart';
import '../../services/api_service.dart';
import '../../models/issue_model.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/image_gallery.dart';

class AdminIssueDetailScreen extends StatefulWidget {
  final Issue issue;

  const AdminIssueDetailScreen({super.key, required this.issue});

  @override
  State<AdminIssueDetailScreen> createState() => _AdminIssueDetailScreenState();
}

class _AdminIssueDetailScreenState extends State<AdminIssueDetailScreen> {
  Issue? _detailedIssue;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _availableWorkers = [];

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

      // Load available workers if issue is assigned
      if (_detailedIssue?.assignedTo != null) {
        await _loadAvailableWorkers();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAvailableWorkers() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token == null) return;

      final workers = await ApiService.getWorkersList(authProvider.token!);
      
      // Filter workers: same district and same department as currently assigned worker
      final currentDepartmentId = _detailedIssue?.assignedTo?.department.id;
      final adminDistrict = authProvider.user?.district;

      debugPrint('Current department ID: $currentDepartmentId');
      debugPrint('Admin district: $adminDistrict');
      debugPrint('Total workers fetched: ${workers.length}');

      setState(() {
        _availableWorkers = workers.where((worker) {
          // Backend returns nested structure: {id, user: {}, department: {}, daily_task_count}
          final workerUser = worker['user'] as Map<String, dynamic>?;
          final workerDept = worker['department'] as Map<String, dynamic>?;
          
          if (workerUser == null || workerDept == null) {
            debugPrint('Worker has null user or department: $worker');
            return false;
          }

          final workerDistrict = workerUser['district'];
          final workerDeptId = workerDept['id'];
          final isActive = workerUser['is_active'] ?? true;
          final workerProfileId = worker['id'];
          final currentWorkerProfileId = _detailedIssue?.assignedTo?.id;

          debugPrint('Worker: ${workerUser['full_name']}, District: $workerDistrict, Dept ID: $workerDeptId, Active: $isActive, Profile ID: $workerProfileId, Current: $currentWorkerProfileId');

          // Exclude currently assigned worker
          final isNotCurrentWorker = workerProfileId != currentWorkerProfileId;
          final matchesDistrict = workerDistrict == adminDistrict;
          final matchesDepartment = workerDeptId == currentDepartmentId;
          
          debugPrint('  -> Matches: District=$matchesDistrict, Dept=$matchesDepartment, NotCurrent=$isNotCurrentWorker');

          return matchesDistrict &&
                 matchesDepartment &&
                 isActive == true &&
                 isNotCurrentWorker;
        }).toList();

        debugPrint('Filtered workers count: ${_availableWorkers.length}');
      });
    } catch (e) {
      debugPrint('Error loading workers: $e');
    }
  }

  Future<void> _showReassignDialog() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    if (_availableWorkers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(languageProvider.getText(
            'No other workers available in this department',
            'इस विभाग में कोई अन्य कर्मचारी उपलब्ध नहीं है'
          )),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.swap_horiz, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                languageProvider.getText('Reassign Issue', 'समस्या पुनः सौंपें'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                languageProvider.getText(
                  'Select a worker to reassign this issue:',
                  'इस समस्या को पुनः सौंपने के लिए एक कर्मचारी चुनें:'
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableWorkers.length,
                  itemBuilder: (context, index) {
                    final worker = _availableWorkers[index];
                    final workerUser = worker['user'] as Map<String, dynamic>;
                    final workerProfile = worker;
                    
                    // Compare worker profile ID (not user ID) with assigned worker profile ID
                    final isCurrentWorker = workerProfile['id'] == _detailedIssue?.assignedTo?.id;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCurrentWorker 
                          ? AppColors.success.withValues(alpha: 0.2)
                          : AppColors.primary.withValues(alpha: 0.1),
                        child: Icon(
                          isCurrentWorker ? Icons.check : Icons.person,
                          color: isCurrentWorker ? AppColors.success : AppColors.primary,
                        ),
                      ),
                      title: Text(
                        workerUser['full_name'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: isCurrentWorker ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        isCurrentWorker 
                          ? languageProvider.getText('Currently Assigned', 'वर्तमान में सौंपा गया')
                          : workerUser['email'] ?? '',
                        style: TextStyle(
                          color: isCurrentWorker ? AppColors.success : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      enabled: !isCurrentWorker,
                      onTap: isCurrentWorker ? null : () {
                        Navigator.of(dialogContext).pop();
                        _reassignIssue(workerProfile['id'], workerUser['full_name']);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(languageProvider.getText('Cancel', 'रद्द करें')),
          ),
        ],
      ),
    );
  }

  Future<void> _reassignIssue(int newWorkerId, String workerName) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      if (authProvider.token == null) {
        throw Exception('No authentication token');
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await ApiService.reassignIssue(
        authProvider.token!,
        widget.issue.id,
        newWorkerId,
      );

      if (!mounted) return;
      
      // Close loading dialog
      Navigator.of(context).pop();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(languageProvider.getText(
            'Issue reassigned to $workerName successfully!',
            'समस्या $workerName को सफलतापूर्वक पुनः सौंपी गई!'
          )),
          backgroundColor: AppColors.success,
        ),
      );

      // Reload issue details
      await _loadIssueDetails();
    } catch (e) {
      if (!mounted) return;
      
      // Close loading dialog if open
      Navigator.of(context).pop();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${languageProvider.getText('Failed to reassign', 'पुनः सौंपने में विफल')}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
            onPressed: _loadIssueDetails,
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
                      const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        languageProvider.getText('Failed to load issue details', 'समस्या विवरण लोड करने में विफल'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        text: languageProvider.getText('Retry', 'पुनः प्रयास'),
                        onPressed: _loadIssueDetails,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card
                      _buildStatusCard(issue, languageProvider),
                      const SizedBox(height: 20),

                      // Issue Information
                      _buildInfoSection(
                        languageProvider.getText('Issue Information', 'समस्या की जानकारी'),
                        [
                          _buildInfoRow(languageProvider.getText('Title', 'शीर्षक'), issue.title),
                          _buildInfoRow(languageProvider.getText('Description', 'विवरण'), issue.description),
                          _buildInfoRow(languageProvider.getText('Reported By', 'रिपोर्ट किया गया'), issue.submittedBy.fullName),
                          _buildInfoRow(languageProvider.getText('Location', 'स्थान'), issue.location ?? 'N/A'),
                          _buildInfoRow(languageProvider.getText('Created', 'बनाया गया'), _formatDate(issue.createdAt)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Reporter Information Card
                      _buildReporterSection(issue, languageProvider),
                      const SizedBox(height: 20),

                      // Assignment Information with Reassign Button
                      if (issue.assignedTo != null) ...[
                        _buildAssignmentSection(issue, languageProvider),
                        const SizedBox(height: 20),
                      ],

                      // Media Files
                      if (issue.mediaFiles.isNotEmpty)
                        ImageGallery(
                          mediaFiles: issue.mediaFiles
                              .map((media) => {
                                    'file_url': media.fileUrl,
                                    'media_type': media.mediaType,
                                  })
                              .toList(),
                          title: languageProvider.getText('Attachments', 'संलग्नक'),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusCard(Issue issue, LanguageProvider languageProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
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
                  languageProvider.getText('Current Status', 'वर्तमान स्थिति'),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
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
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentSection(Issue issue, LanguageProvider languageProvider) {
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
                languageProvider.getText('Assignment Information', 'निर्देशन जानकारी'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              if (issue.status.toLowerCase() == 'assigned')
                IconButton(
                  icon: const Icon(Icons.swap_horiz, color: AppColors.primary),
                  onPressed: _showReassignDialog,
                  tooltip: languageProvider.getText('Reassign', 'पुनः सौंपें'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            languageProvider.getText('Assigned To', 'निर्दिष्ट किया गया'),
            issue.assignedTo!.user.fullName,
          ),
          _buildInfoRow(
            languageProvider.getText('Department', 'विभाग'),
            issue.assignedTo!.department.name,
          ),
          if (issue.status.toLowerCase() == 'completed' || issue.status.toLowerCase() == 'verified')
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        languageProvider.getText(
                          'Work completed by ${issue.assignedTo!.user.fullName}',
                          '${issue.assignedTo!.user.fullName} द्वारा कार्य पूर्ण किया गया'
                        ),
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (issue.status.toLowerCase() == 'assigned')
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: CustomButton(
                text: languageProvider.getText('Reassign to Another Worker', 'दूसरे कर्मचारी को पुनः सौंपें'),
                onPressed: _showReassignDialog,
                backgroundColor: AppColors.warning,
              ),
            )
          else if (issue.status.toLowerCase() == 'completed' || issue.status.toLowerCase() == 'verified')
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        languageProvider.getText(
                          'Cannot reassign completed or verified issues',
                          'पूर्ण या सत्यापित समस्याओं को पुनः नहीं सौंपा जा सकता'
                        ),
                        style: const TextStyle(
                          color: AppColors.info,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReporterSection(Issue issue, LanguageProvider languageProvider) {
    // Only show delete option for PENDING and ASSIGNED issues
    final canDelete = issue.status.toLowerCase() == 'pending' || issue.status.toLowerCase() == 'assigned';
    
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
                languageProvider.getText('Reporter Information', 'रिपोर्टर की जानकारी'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: AppColors.error),
                  onPressed: () => _showDeleteDialog(issue, languageProvider),
                  tooltip: languageProvider.getText('Delete Issue', 'समस्या हटाएं'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.submittedBy.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      languageProvider.getText('Issue Reporter', 'समस्या रिपोर्टर'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Show different content based on whether deletion is allowed
          if (canDelete) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      languageProvider.getText(
                        'If this issue is fake or inappropriate, you can delete it. This will reduce the reporter\'s civic points.',
                        'यदि यह समस्या नकली या अनुचित है, तो आप इसे हटा सकते हैं। इससे रिपोर्टर के नागरिक अंक कम हो जाएंगे।'
                      ),
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _showDeleteDialog(issue, languageProvider),
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              label: Text(
                languageProvider.getText('Delete as Fake/Inappropriate', 'नकली/अनुचित के रूप में हटाएं'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ] else ...[
            // Show info message for completed/verified issues
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      languageProvider.getText(
                        'Completed and verified issues cannot be deleted. Only pending or assigned issues can be removed if they are inappropriate.',
                        'पूर्ण और सत्यापित समस्याओं को हटाया नहीं जा सकता। केवल लंबित या निर्दिष्ट समस्याओं को हटाया जा सकता है यदि वे अनुचित हैं।'
                      ),
                      style: const TextStyle(
                        color: AppColors.info,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
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

  Future<void> _showDeleteDialog(Issue issue, LanguageProvider languageProvider) async {
    // Double-check status before showing dialog
    if (issue.status.toLowerCase() != 'pending' && issue.status.toLowerCase() != 'assigned') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(languageProvider.getText(
            'Cannot delete completed or verified issues',
            'पूर्ण या सत्यापित समस्याओं को हटाया नहीं जा सकता'
          )),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    final TextEditingController reasonController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(20),
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                languageProvider.getText('Delete Issue', 'समस्या हटाएं'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageProvider.getText(
                    'Are you sure you want to delete this issue as fake/inappropriate?',
                    'क्या आप वाकई इस समस्या को नकली/अनुचित के रूप में हटाना चाहते हैं?'
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.getText('This action will:', 'यह कार्रवाई करेगी:'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• ${languageProvider.getText('Delete the issue permanently', 'समस्या को स्थायी रूप से हटा देगी')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        '• ${languageProvider.getText('Reduce reporter\'s civic points by 10', 'रिपोर्टर के नागरिक अंक 10 से कम कर देगी')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        '• ${languageProvider.getText('Send notification to reporter', 'रिपोर्टर को सूचना भेजेगी')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  languageProvider.getText('Reason for deletion:', 'हटाने का कारण:'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: languageProvider.getText(
                      'Enter reason why this issue is being deleted...',
                      'इस समस्या को हटाने का कारण दर्ज करें...'
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(languageProvider.getText('Cancel', 'रद्द करें')),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(languageProvider.getText(
                      'Please enter a reason for deletion',
                      'कृपया हटाने का कारण दर्ज करें'
                    )),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              Navigator.of(dialogContext).pop();
              _deleteIssue(issue.id, reasonController.text.trim(), languageProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(languageProvider.getText('Delete Issue', 'समस्या हटाएं')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteIssue(int issueId, String reason, LanguageProvider languageProvider) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      if (authProvider.token == null) {
        throw Exception('No authentication token');
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await ApiService.deleteFakeIssue(
        authProvider.token!,
        issueId,
        reason,
      );

      if (!mounted) return;
      
      // Close loading dialog
      Navigator.of(context).pop();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(languageProvider.getText(
            'Issue deleted successfully. Reporter has been notified.',
            'समस्या सफलतापूर्वक हटा दी गई। रिपोर्टर को सूचित कर दिया गया है।'
          )),
          backgroundColor: AppColors.success,
        ),
      );

      // Go back to issues list
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      
      // Close loading dialog if open
      Navigator.of(context).pop();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${languageProvider.getText('Failed to delete issue', 'समस्या हटाने में विफल')}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
