import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _districtLeaderboard;
  Map<String, dynamic>? _stateLeaderboard;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.user?.role ?? 'client';
    // Super admin only has state tab, others have both
    _tabController = TabController(length: userRole == 'super_admin' ? 1 : 2, vsync: this);
    _loadLeaderboards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboards() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token == null) {
        throw Exception('Authentication required');
      }

      final userRole = authProvider.user?.role ?? 'client';
      
      // For super admin, only load state leaderboard (no district)
      if (userRole == 'super_admin') {
        final stateFuture = ApiService.getStateLeaderboard(authProvider.token!);
        final stateResult = await stateFuture;
        
        setState(() {
          _districtLeaderboard = null; // No district for super admin
          _stateLeaderboard = stateResult;
          _isLoading = false;
        });
      } else {
        // For client and admin, load both
        if (authProvider.user?.district == null) {
          throw Exception('District information required');
        }
        
        final districtFuture = ApiService.getDistrictLeaderboard(
          authProvider.token!,
          authProvider.user!.district!,
        );
        final stateFuture = ApiService.getStateLeaderboard(authProvider.token!);

        final results = await Future.wait([districtFuture, stateFuture]);

        setState(() {
          _districtLeaderboard = results[0];
          _stateLeaderboard = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.leaderboard,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageProvider.getText(
                      'Civic Leaderboard',
                      'नागरिक लीडरबोर्ड',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    languageProvider.getText(
                      'Top Contributors',
                      'शीर्ष योगदानकर्ता',
                    ),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: Provider.of<AuthProvider>(context, listen: false).user?.role == 'super_admin'
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(
                    text: languageProvider.getText('Haryana', 'हरियाणा'),
                    icon: const Icon(Icons.public, size: 18),
                  ),
                ],
              )
            : TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(
                    text: languageProvider.getText('My District', 'मेरा जिला'),
                    icon: const Icon(Icons.location_city, size: 18),
                  ),
                  Tab(
                    text: languageProvider.getText('Haryana', 'हरियाणा'),
                    icon: const Icon(Icons.public, size: 18),
                  ),
                ],
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorWidget()
          : Provider.of<AuthProvider>(context, listen: false).user?.role == 'super_admin'
              ? TabBarView(
                  controller: _tabController,
                  children: [_buildStateLeaderboard()],
                )
              : TabBarView(
                  controller: _tabController,
                  children: [_buildDistrictLeaderboard(), _buildStateLeaderboard()],
                ),
    );
  }

  Widget _buildErrorWidget() {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            languageProvider.getText(
              'Failed to load leaderboard',
              'लीडरबोर्ड लोड करने में असफल',
            ),
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadLeaderboards,
            child: Text(languageProvider.getText('Retry', 'पुनः प्रयास करें')),
          ),
        ],
      ),
    );
  }

  Widget _buildDistrictLeaderboard() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.user?.role ?? 'client';

    if (_districtLeaderboard == null) return const SizedBox();

    final leaderboard = _districtLeaderboard!['leaderboard'] as List;
    final currentUserRank = _districtLeaderboard!['current_user_rank'] as int;
    final currentUserPoints = _districtLeaderboard!['current_user_points'] as int;
    final district = _districtLeaderboard!['district'] as String;

    return RefreshIndicator(
      onRefresh: _loadLeaderboards,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User's current position card (only for clients)
            if (userRole == 'client')
              Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.secondary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.primaryGradient,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              languageProvider.getText(
                                'Your Position in $district',
                                '$district में आपकी स्थिति',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  languageProvider.getText('Rank: ', 'रैंक: '),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '#$currentUserRank',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$currentUserPoints ${languageProvider.getText('points', 'अंक')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Leaderboard title
            Text(
              languageProvider.getText(
                'Top Contributors in $district',
                '$district के शीर्ष योगदानकर्ता',
              ),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Leaderboard list
            ...leaderboard.asMap().entries.map((entry) {
              final index = entry.key;
              final user = entry.value;
              return _buildLeaderboardItem(user, index < 3);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStateLeaderboard() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.user?.role ?? 'client';

    if (_stateLeaderboard == null) return const SizedBox();

    final leaderboard = _stateLeaderboard!['leaderboard'] as List;
    final currentUserRank = _stateLeaderboard!['current_user_rank'] as int;
    final currentUserPoints = _stateLeaderboard!['current_user_points'] as int;

    return RefreshIndicator(
      onRefresh: _loadLeaderboards,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User's state position card (only for clients)
            if (userRole == 'client')
              Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.1),
                    AppColors.primary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.secondary, AppColors.primary],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.public,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              languageProvider.getText(
                                'Your Position in Haryana',
                                'हरियाणा में आपकी स्थिति',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  languageProvider.getText(
                                    'State Rank: ',
                                    'राज्य रैंक: ',
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '#$currentUserRank',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$currentUserPoints ${languageProvider.getText('points', 'अंक')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Leaderboard title
            Text(
              languageProvider.getText(
                'Top Contributors in Haryana',
                'हरियाणा के शीर्ष योगदानकर्ता',
              ),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Leaderboard list
            ...leaderboard.asMap().entries.map((entry) {
              final index = entry.key;
              final user = entry.value;
              return _buildLeaderboardItem(user, index < 3, showDistrict: true);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem(
    Map<String, dynamic> user,
    bool isTopThree, {
    bool showDistrict = false,
  }) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final rank = user['rank'] as int;
    final name = user['name'] as String;
    final points = user['points'] as int;
    final issuesReported = user['issues_reported'] as int;
    final issuesVerified = user['issues_verified'] as int;
    final isCurrentUser = user['is_current_user'] as bool? ?? false;
    final district = showDistrict ? user['district'] as String? : null;

    // Get rank styling
    Color rankColor = AppColors.textSecondary;
    IconData? rankIcon;
    Color? containerColor;

    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankIcon = Icons.emoji_events;
      containerColor = const Color(0xFFFFD700).withValues(alpha: 0.1);
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankIcon = Icons.emoji_events;
      containerColor = const Color(0xFFC0C0C0).withValues(alpha: 0.1);
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankIcon = Icons.emoji_events;
      containerColor = const Color(0xFFCD7F32).withValues(alpha: 0.1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withValues(alpha: 0.1)
            : containerColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border.withValues(alpha: 0.3),
          width: isCurrentUser ? 2 : 1,
        ),
        boxShadow: isTopThree
            ? [
                BoxShadow(
                  color: rankColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: rankIcon != null
                  ? Icon(rankIcon, color: rankColor, size: 20)
                  : Text(
                      '#$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: rankColor,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCurrentUser
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          languageProvider.getText('You', 'आप'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (showDistrict && district != null) ...[
                  Text(
                    district,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$points ${languageProvider.getText('pts', 'अंक')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$issuesReported ${languageProvider.getText('reported', 'रिपोर्ट')}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$issuesVerified ${languageProvider.getText('verified', 'सत्यापित')}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
