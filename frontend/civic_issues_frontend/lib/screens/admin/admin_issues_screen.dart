import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/issue_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/issue_model.dart';
import '../../utils/app_colors.dart';
import 'admin_issue_detail_screen.dart';

class AdminIssuesScreen extends StatefulWidget {
  const AdminIssuesScreen({super.key});

  @override
  State<AdminIssuesScreen> createState() => _AdminIssuesScreenState();
}

class _AdminIssuesScreenState extends State<AdminIssuesScreen> {
  String _selectedFilter = 'all';
  String _selectedSort = 'newest';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        Provider.of<IssueProvider>(context, listen: false)
            .loadAllProblems(authProvider.token!);
      }
    });
  }

  List<Issue> _getFilteredAndSortedIssues(List<Issue> issues) {
    List<Issue> filtered = issues;

    // Apply filter
    if (_selectedFilter != 'all') {
      filtered = issues
          .where((issue) => issue.status.toLowerCase() == _selectedFilter)
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final issueProvider = Provider.of<IssueProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          languageProvider.getText('All Issues', 'सभी समस्याएं'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.adminColor,
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
                issueProvider.loadAllProblems(authProvider.token!);
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
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedFilter,
                    decoration: InputDecoration(
                      labelText: languageProvider.getText('Filter', 'फिल्टर'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'all',
                          child: Text(languageProvider.getText('All', 'सभी'))),
                      DropdownMenuItem(
                          value: 'pending',
                          child: Text(
                              languageProvider.getText('Pending', 'लंबित'))),
                      DropdownMenuItem(
                          value: 'assigned',
                          child: Text(languageProvider.getText(
                              'Assigned', 'निर्दिष्ट'))),
                      DropdownMenuItem(
                          value: 'completed',
                          child: Text(
                              languageProvider.getText('Completed', 'पूर्ण'))),
                      DropdownMenuItem(
                          value: 'verified',
                          child: Text(languageProvider.getText(
                              'Verified', 'सत्यापित'))),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedFilter = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSort,
                    decoration: InputDecoration(
                      labelText: languageProvider.getText('Sort', 'सॉर्ट'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'newest',
                          child: Text(
                              languageProvider.getText('Newest', 'नवीनतम'))),
                      DropdownMenuItem(
                          value: 'oldest',
                          child: Text(
                              languageProvider.getText('Oldest', 'पुराना'))),
                      DropdownMenuItem(
                          value: 'priority',
                          child: Text(languageProvider.getText(
                              'Priority', 'प्राथमिकता'))),
                      DropdownMenuItem(
                          value: 'status',
                          child: Text(
                              languageProvider.getText('Status', 'स्थिति'))),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSort = value!;
                      });
                    },
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
                          languageProvider.getText('Error loading issues',
                              'समस्याएं लोड करने में त्रुटि'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
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
                              issueProvider
                                  .loadAllProblems(authProvider.token!);
                            }
                          },
                          child: Text(
                              languageProvider.getText('Retry', 'पुनः प्रयास')),
                        ),
                      ],
                    ),
                  );
                }

                final issues = issueProvider.allProblems;
                if (issues.isEmpty) {
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
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          languageProvider.getText(
                              'Issues will appear here when reported',
                              'रिपोर्ट होने पर समस्याएं यहां दिखाई देंगी'),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final filteredIssues = _getFilteredAndSortedIssues(issues);

                return RefreshIndicator(
                  onRefresh: () async {
                    if (authProvider.token != null) {
                      await issueProvider.loadAllProblems(authProvider.token!);
                    }
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filteredIssues.length,
                    itemBuilder: (context, index) {
                      final issue = filteredIssues[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(issue.status)
                                .withValues(alpha: 0.1),
                            child: Icon(
                              _getStatusIcon(issue.status),
                              color: _getStatusColor(issue.status),
                            ),
                          ),
                          title: Text(
                            issue.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(issue.description),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      issue.location ?? (issue.latitude != null && issue.longitude != null 
                                          ? '${issue.latitude!.toStringAsFixed(4)}, ${issue.longitude!.toStringAsFixed(4)}'
                                          : 'Location not available'),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.category,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      issue.problemType,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
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
                                    child: Text(
                                      _getStatusText(
                                          issue.status, languageProvider),
                                      style: TextStyle(
                                        color: _getStatusColor(issue.status),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.priority_high,
                                color: issue.priority >= 0.8
                                    ? AppColors.error
                                    : issue.priority >= 0.5
                                        ? AppColors.warning
                                        : AppColors.success,
                                size: 20,
                              ),
                              Text(
                                issue.priority >= 0.8
                                    ? 'High'
                                    : issue.priority >= 0.5
                                        ? 'Med'
                                        : 'Low',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: issue.priority >= 0.8
                                      ? AppColors.error
                                      : issue.priority >= 0.5
                                          ? AppColors.warning
                                          : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            // Navigate to admin issue details screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminIssueDetailScreen(issue: issue),
                              ),
                            );
                          },
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


