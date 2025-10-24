import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/issue_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/issue_model.dart';
import '../../utils/app_colors.dart';
import 'issue_detail_screen.dart';

class MyIssuesScreen extends StatefulWidget {
  const MyIssuesScreen({super.key});

  @override
  State<MyIssuesScreen> createState() => _MyIssuesScreenState();
}

class _MyIssuesScreenState extends State<MyIssuesScreen> {
  String _selectedFilter = 'all';
  String _selectedSort = 'newest';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        Provider.of<IssueProvider>(context, listen: false)
            .loadUserIssues(authProvider.token!);
      }
    });
  }

  List<Issue> _getFilteredAndSortedIssues(List<Issue> issues) {
    List<Issue> filtered = issues;

    // Apply filter
    if (_selectedFilter != 'all') {
      filtered = issues
          .where((issue) =>
              issue.status.toUpperCase() == _selectedFilter.toUpperCase())
          .toList();
    }

    // Apply sort
    switch (_selectedSort) {
      case 'newest':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'oldest':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'priority':
        filtered.sort((a, b) => b.priority.compareTo(a.priority));
        break;
      case 'status':
        filtered.sort((a, b) => a.status.compareTo(b.status));
        break;
    }

    return filtered;
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
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
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
    final issueProvider = Provider.of<IssueProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          languageProvider.getText('My Issues', 'मेरी समस्याएं'),
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
            onPressed: () {
              if (authProvider.token != null) {
                issueProvider.loadUserIssues(authProvider.token!);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter and Sort Controls
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                // Filter Dropdown
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.getText('Filter', 'फिल्टर'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedFilter,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text(languageProvider.getText('All', 'सभी')),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text(
                                languageProvider.getText('Pending', 'लंबित')),
                          ),
                          DropdownMenuItem(
                            value: 'assigned',
                            child: Text(languageProvider.getText(
                                'Assigned', 'निर्दिष्ट')),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text(
                                languageProvider.getText('Completed', 'पूर्ण')),
                          ),
                          DropdownMenuItem(
                            value: 'verified',
                            child: Text(languageProvider.getText(
                                'Verified', 'सत्यापित')),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedFilter = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Sort Dropdown
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.getText('Sort', 'क्रम'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedSort,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'newest',
                            child: Text(
                                languageProvider.getText('Newest', 'नवीनतम')),
                          ),
                          DropdownMenuItem(
                            value: 'oldest',
                            child: Text(languageProvider.getText(
                                'Oldest', 'सबसे पुराना')),
                          ),
                          DropdownMenuItem(
                            value: 'priority',
                            child: Text(languageProvider.getText(
                                'Priority', 'प्राथमिकता')),
                          ),
                          DropdownMenuItem(
                            value: 'status',
                            child: Text(
                                languageProvider.getText('Status', 'स्थिति')),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedSort = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Issues List
          Expanded(
            child: Consumer<IssueProvider>(
              builder: (context, issueProvider, child) {
                if (issueProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (issueProvider.error != null) {
                  return Center(
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
                          languageProvider.getText('Failed to load issues',
                              'समस्याएं लोड करने में असफल'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          issueProvider.error!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (authProvider.token != null) {
                              issueProvider.loadUserIssues(authProvider.token!);
                            }
                          },
                          child: Text(
                              languageProvider.getText('Retry', 'पुनः प्रयास')),
                        ),
                      ],
                    ),
                  );
                }

                final filteredIssues =
                    _getFilteredAndSortedIssues(issueProvider.userIssues);

                if (filteredIssues.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          languageProvider.getText(
                              'No issues found', 'कोई समस्या नहीं मिली'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          languageProvider.getText(
                              'Try adjusting your filters or report a new issue',
                              'अपने फिल्टर को समायोजित करने का प्रयास करें या नई समस्या रिपोर्ट करें'),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    final authProvider =
                        Provider.of<AuthProvider>(context, listen: false);
                    if (authProvider.token != null) {
                      await issueProvider.loadUserIssues(authProvider.token!);
                    }
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filteredIssues.length,
                    itemBuilder: (context, index) {
                      final issue = filteredIssues[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    IssueDetailScreen(issue: issue),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        issue.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(issue.status)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getStatusIcon(issue.status),
                                            size: 14,
                                            color:
                                                _getStatusColor(issue.status),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _getStatusText(
                                                issue.status, languageProvider),
                                            style: TextStyle(
                                              color:
                                                  _getStatusColor(issue.status),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Description
                                Text(
                                  issue.description,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                const SizedBox(height: 12),

                                // Footer Row
                                Row(
                                  children: [
                                    // Category
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        issue.problemType,
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    // Priority
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getPriorityColor(issue.priority)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _formatPriority(issue.priority),
                                        style: TextStyle(
                                          color:
                                              _getPriorityColor(issue.priority),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),

                                    const Spacer(),

                                    // Date
                                    Text(
                                      _formatDate(issue.createdAt),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),

                                // Assigned To (if applicable)
                                if (issue.assignedTo != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '${languageProvider.getText('Assigned to', 'निर्दिष्ट किया गया')}: ${issue.assignedTo!.user.fullName} (${issue.assignedTo!.department.name})',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


