import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;

class ApiService {
  // For mobile: Replace 192.168.1.100 with YOUR computer's IP address from ipconfig
  // For web: Use http://127.0.0.1:8000
  static const String baseUrl =
      'http://192.168.233.247:8000'; // CHANGE THIS IP!

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
  static Map<String, String> _getAuthHeaders(String token) => {
        ..._headers,
        'Authorization': 'Bearer $token',
      };

  // Authentication APIs
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Get user profile after successful login
        final userProfile = await getUserProfile(data['access_token']);
        return {
          ...data,
          'user': userProfile,
        };
      } else if (response.statusCode == 401) {
        throw Exception('Invalid email or password. Please try again.');
      } else if (response.statusCode == 403) {
        throw Exception('Account is inactive. Please contact admin.');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error. Please try again later.');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ??
            'Login failed. Please check your credentials.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      // If it's already our custom exception, re-throw it
      if (e.toString().contains('Invalid email') ||
          e.toString().contains('Account is inactive') ||
          e.toString().contains('Server error')) {
        rethrow;
      }
      // Network or other errors
      throw Exception(
          'Unable to connect. Please check your internet connection.');
    }
  }

  static Future<Map<String, dynamic>> register(
      Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'full_name': userData['fullName'],
          'email': userData['email'],
          'password': userData['password'],
          'district': userData['district'],
          'pincode': userData['pincode'],
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Registration failed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Register error: $e');
      }
      throw Exception('Registration failed: $e');
    }
  }

  static Future<Map<String, dynamic>> getUserProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch profile: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get profile error: $e');
      }
      throw Exception('Failed to fetch profile: $e');
    }
  }

  // Issue APIs
  static Future<Map<String, dynamic>> createIssue(
    String token,
    String title,
    String description,
    String problemType,
    String district,
    double latitude,
    double longitude,
    File imageFile,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/users/issues'),
      );

      // Add headers
      request.headers.addAll(_getAuthHeaders(token));

      // Add form fields
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['problem_type'] = problemType;
      request.fields['district'] = district;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      // Add image file (now mandatory)
      if (kIsWeb) {
        // For web, use a completely different approach
        try {
          // Generate a safe filename for web
          final filename = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

          // For Flutter web, we need to handle files very carefully
          // Try to read as bytes first
          final bytes = await imageFile.readAsBytes();

          // Create multipart file with minimal parameters for web compatibility
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: filename,
            ),
          );
        } catch (e) {
          // If readAsBytes fails, try a different approach
          try {
            // Create a simple multipart file without content type
            final filename =
                'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

            // Try to get bytes using a different method
            final bytes = await imageFile.readAsBytes();

            // Create multipart file with just the essential parameters
            request.files.add(
              http.MultipartFile.fromBytes(
                'file',
                bytes,
                filename: filename,
              ),
            );
          } catch (e2) {
            // Final fallback - try without any optional parameters
            try {
              final filename =
                  'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final bytes = await imageFile.readAsBytes();

              // Minimal multipart file creation
              final multipartFile = http.MultipartFile.fromBytes(
                'file',
                bytes,
                filename: filename,
              );
              request.files.add(multipartFile);
            } catch (e3) {
              // If all else fails, provide a helpful error message
              throw Exception(
                  'Unable to process the selected image for web upload. Please try: 1) Selecting a different image, 2) Using a smaller image file, or 3) Refreshing the page and trying again.');
            }
          }
        }
      } else {
        // For mobile/desktop, use the file path
        request.files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 409) {
        // Handle duplicate issue (409 Conflict)
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['detail'] ?? 'This problem already exists');
        } catch (e) {
          // If JSON parsing fails, use the raw response or default message
          throw Exception('This problem already exists');
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['detail'] ?? 'Failed to create issue');
        } catch (e) {
          throw Exception('Failed to create issue: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Create issue error: $e');
      }
      // Re-throw the original error message, don't wrap it
      if (e.toString().contains('This problem already exists')) {
        rethrow;
      }
      throw Exception('Failed to create issue: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getUserIssues(String token) async {
    try {
      final response = await http
          .get(
        Uri.parse('$baseUrl/users/issues'),
        headers: _getAuthHeaders(token),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout - check your internet connection');
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> issues = jsonDecode(response.body);
        return issues.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch issues: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get user issues error: $e');
      }
      throw Exception('Failed to fetch issues: $e');
    }
  }

  static Future<Map<String, dynamic>> getIssueDetails(
      String token, String issueId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/issues/$issueId'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to fetch issue details: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get issue details error: $e');
      }
      throw Exception('Failed to fetch issue details: $e');
    }
  }

  // Worker APIs
  static Future<List<Map<String, dynamic>>> getAssignedTasks(
      String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/worker/tasks'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> tasks = jsonDecode(response.body);
        return tasks.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
            'Failed to fetch assigned tasks: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get assigned tasks error: $e');
      }
      throw Exception('Failed to fetch assigned tasks: $e');
    }
  }

  static Future<Map<String, dynamic>> completeTask(
    String token,
    String taskId,
    File proofImage,
    double latitude,
    double longitude,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/worker/tasks/$taskId/complete'),
      );

      // Add headers
      request.headers.addAll(_getAuthHeaders(token));

      // Add GPS location as form fields (REQUIRED for verification)
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      // Add proof image
      if (kIsWeb) {
        // For web, use simplified approach
        try {
          final bytes = await proofImage.readAsBytes();
          final filename = 'proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
          request.files.add(
            http.MultipartFile.fromBytes(
              'proof_file',
              bytes,
              filename: filename,
            ),
          );
        } catch (e) {
          // Fallback approach for web
          try {
            final filename =
                'proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final bytes = await proofImage.readAsBytes();

            request.files.add(
              http.MultipartFile.fromBytes(
                'proof_file',
                bytes,
                filename: filename,
              ),
            );
          } catch (e2) {
            // Last resort
            try {
              final filename =
                  'proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final bytes = await proofImage.readAsBytes();

              final multipartFile = http.MultipartFile.fromBytes(
                'proof_file',
                bytes,
                filename: filename,
              );
              request.files.add(multipartFile);
            } catch (e3) {
              throw Exception(
                  'Unable to process the proof image for web upload. Please try selecting a different image.');
            }
          }
        }
      } else {
        // For mobile/desktop, use the file path
        request.files.add(
          await http.MultipartFile.fromPath('proof_file', proofImage.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        // GPS verification errors will show distance details
        throw Exception(error['detail'] ?? 'Failed to complete task');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Complete task error: $e');
      }
      throw Exception('Failed to complete task: $e');
    }
  }

  static Future<Map<String, dynamic>> getWorkerStats(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/worker/me/stats'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch worker stats: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get worker stats error: $e');
      }
      throw Exception('Failed to fetch worker stats: $e');
    }
  }

  // Admin APIs
  static Future<Map<String, dynamic>> getAdminStats(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/analytics/stats'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch admin stats: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get admin stats error: $e');
      }
      throw Exception('Failed to fetch admin stats: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllProblems(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/problems'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> problems = jsonDecode(response.body);
        return problems.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch all problems: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get all problems error: $e');
      }
      throw Exception('Failed to fetch all problems: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllWorkers(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/workers'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> workers = jsonDecode(response.body);
        return workers.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch workers: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get workers error: $e');
      }
      throw Exception('Failed to fetch workers: $e');
    }
  }

  static Future<Map<String, dynamic>> createWorker(
    String token,
    Map<String, dynamic> workerData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/workers'),
        headers: _getAuthHeaders(token),
        body: jsonEncode(workerData),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to create worker');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Create worker error: $e');
      }
      throw Exception('Failed to create worker: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllDepartments(
      String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/departments'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> departments = jsonDecode(response.body);
        return departments.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch departments: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get departments error: $e');
      }
      throw Exception('Failed to fetch departments: $e');
    }
  }

  static Future<Map<String, dynamic>> createDepartment(
    String token,
    String name,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/departments'),
        headers: _getAuthHeaders(token),
        body: jsonEncode({'name': name}),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to create department');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Create department error: $e');
      }
      throw Exception('Failed to create department: $e');
    }
  }

  // Super Admin APIs
  static Future<List<Map<String, dynamic>>> getAllAdmins(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/super-admin/admins'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> admins = jsonDecode(response.body);
        return admins.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch admins: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get admins error: $e');
      }
      throw Exception('Failed to fetch admins: $e');
    }
  }

  /// Create a new admin user
  static Future<Map<String, dynamic>> createAdmin(
    String token, {
    required String fullName,
    required String email,
    required String password,
    required String district,
    String? pincode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/super-admin/create-admin'),
        headers: _getAuthHeaders(token),
        body: jsonEncode({
          'full_name': fullName,
          'email': email,
          'password': password,
          'district': district,
          'pincode': pincode,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to create admin');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Create admin error: $e');
      }
      throw Exception('Failed to create admin: $e');
    }
  }

  // Dashboard Statistics APIs
  static Future<Map<String, dynamic>> getClientDashboardStats(
      String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/dashboard/my-district'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to fetch dashboard stats: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get dashboard stats error: $e');
      }
      throw Exception('Failed to fetch dashboard stats: $e');
    }
  }

  static Future<Map<String, dynamic>> getClientDistrictDetails(
      String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/dashboard/my-district/details'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to fetch district details: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get district details error: $e');
      }
      throw Exception('Failed to fetch district details: $e');
    }
  }

  static Future<Map<String, dynamic>> getHaryanaStats(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/dashboard/haryana-overview'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to fetch Haryana stats: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get Haryana stats error: $e');
      }
      throw Exception('Failed to fetch Haryana stats: $e');
    }
  }

  // Issue Actions
  static Future<Map<String, dynamic>> verifyIssueCompletion(
      String token, String issueId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/issues/$issueId/verify'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to verify issue completion');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Verify issue completion error: $e');
      }
      throw Exception('Failed to verify issue completion: $e');
    }
  }

  static Future<Map<String, dynamic>> submitFeedback(
    String token,
    String issueId,
    Map<String, dynamic> feedbackData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/issues/$issueId/feedback'),
        headers: _getAuthHeaders(token),
        body: jsonEncode(feedbackData),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to submit feedback');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Submit feedback error: $e');
      }
      throw Exception('Failed to submit feedback: $e');
    }
  }

  // AI Chatbot API
  static Future<Map<String, dynamic>> chatWithBot(
    String token,
    String message, {
    String? sessionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chatbot/chat'),
        headers: _getAuthHeaders(token),
        body: jsonEncode({
          'message': message,
          'session_id': sessionId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to chat with bot: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Chat with bot error: $e');
      }
      throw Exception('Failed to chat with bot: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getChatSessions(
      String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chatbot/sessions'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> sessions = jsonDecode(response.body);
        return sessions.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
            'Failed to fetch chat sessions: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get chat sessions error: $e');
      }
      throw Exception('Failed to fetch chat sessions: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getChatHistory(
    String token,
    String sessionId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chatbot/history/$sessionId'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> history = jsonDecode(response.body);
        return history.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch chat history: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get chat history error: $e');
      }
      throw Exception('Failed to fetch chat history: $e');
    }
  }

  // Voice-to-Text APIs
  static Future<Map<String, dynamic>> convertVoiceToText(
    String token,
    File audioFile, {
    String language = 'en-IN',
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/users/voice-to-text'),
      );

      // Add headers
      request.headers.addAll(_getAuthHeaders(token));

      // Add language
      request.fields['language'] = language;

      // Add audio file with explicit content type
      if (kIsWeb) {
        final bytes = await audioFile.readAsBytes();
        final filename = 'audio_${DateTime.now().millisecondsSinceEpoch}.webm';
        request.files.add(
          http.MultipartFile.fromBytes(
            'audio_file',
            bytes,
            filename: filename,
            contentType: http_parser.MediaType('audio', 'webm'),
          ),
        );
      } else {
        // Determine content type from file extension
        final extension = audioFile.path.split('.').last.toLowerCase();
        final contentType = _getAudioContentType(extension);

        request.files.add(
          await http.MultipartFile.fromPath(
            'audio_file',
            audioFile.path,
            contentType: contentType,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to convert voice to text');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Voice-to-text error: $e');
      }
      throw Exception('Failed to convert voice to text: $e');
    }
  }

  static Future<Map<String, dynamic>> getSupportedLanguages(
      String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/voice-to-text/languages'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to fetch supported languages: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get supported languages error: $e');
      }
      throw Exception('Failed to fetch supported languages: $e');
    }
  }

  // ========== SUPER ADMIN APIs ==========

  /// Get Haryana overview (super admin analytics)
  static Future<Map<String, dynamic>> getSuperAdminOverview(
      String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/super-admin/analytics/overview'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to fetch super admin overview: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get super admin overview error: $e');
      }
      throw Exception('Failed to fetch super admin overview: $e');
    }
  }

  /// Get district-wise analytics
  static Future<List<Map<String, dynamic>>> getDistrictAnalytics(
      String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/super-admin/analytics/districts'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> stats = jsonDecode(response.body);
        return stats.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
            'Failed to fetch district analytics: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get district analytics error: $e');
      }
      throw Exception('Failed to fetch district analytics: $e');
    }
  }

  /// Get department-wise statistics
  static Future<List<Map<String, dynamic>>> getDepartmentStats(
      String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/super-admin/reports/department-stats'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> stats = jsonDecode(response.body);
        return stats.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
            'Failed to fetch department stats: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get department stats error: $e');
      }
      throw Exception('Failed to fetch department stats: $e');
    }
  }

  /// Get top performing workers
  static Future<List<Map<String, dynamic>>> getTopWorkers(String token,
      {int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/super-admin/reports/top-workers?limit=$limit'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> workers = jsonDecode(response.body);
        return workers.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch top workers: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get top workers error: $e');
      }
      throw Exception('Failed to fetch top workers: $e');
    }
  }

  /// Deactivate an admin
  static Future<void> deactivateAdmin(String token, int adminId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/super-admin/admins/$adminId'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to deactivate admin');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Deactivate admin error: $e');
      }
      throw Exception('Failed to deactivate admin: $e');
    }
  }

  /// Activate an admin
  static Future<void> activateAdmin(String token, int adminId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/super-admin/admins/$adminId/activate'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to activate admin');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Activate admin error: $e');
      }
      throw Exception('Failed to activate admin: $e');
    }
  }

  /// Deactivate a worker
  static Future<void> deactivateWorker(String token, int workerId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/workers/$workerId'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to deactivate worker');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Deactivate worker error: $e');
      }
      throw Exception('Failed to deactivate worker: $e');
    }
  }

  /// Activate a worker
  static Future<void> activateWorker(String token, int workerId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/workers/$workerId/activate'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to activate worker');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Activate worker error: $e');
      }
      throw Exception('Failed to activate worker: $e');
    }
  }

  /// Update feedback
  static Future<Map<String, dynamic>> updateFeedback(
    String token,
    int feedbackId,
    Map<String, dynamic> feedbackData,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/feedback/$feedbackId'),
        headers: _getAuthHeaders(token),
        body: jsonEncode(feedbackData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to update feedback');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Update feedback error: $e');
      }
      throw Exception('Failed to update feedback: $e');
    }
  }

  /// Delete feedback
  static Future<void> deleteFeedback(String token, int feedbackId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/feedback/$feedbackId'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to delete feedback');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Delete feedback error: $e');
      }
      throw Exception('Failed to delete feedback: $e');
    }
  }

  // ========== ADMIN APIs ==========

  /// Get admin analytics/dashboard stats
  static Future<Map<String, dynamic>> getAdminAnalytics(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/analytics/stats'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Add district info from user profile
        final user = await getUserProfile(token);
        return {
          ...data,
          'district': user['district'],
        };
      } else {
        throw Exception(
            'Failed to fetch admin analytics: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get admin analytics error: $e');
      }
      throw Exception('Failed to fetch admin analytics: $e');
    }
  }

  // Helper function to get audio content type from file extension
  static http_parser.MediaType _getAudioContentType(String extension) {
    switch (extension) {
      case 'm4a':
        return http_parser.MediaType('audio', 'mp4');
      case 'mp3':
        return http_parser.MediaType('audio', 'mpeg');
      case 'wav':
        return http_parser.MediaType('audio', 'wav');
      case 'ogg':
        return http_parser.MediaType('audio', 'ogg');
      case 'webm':
        return http_parser.MediaType('audio', 'webm');
      case 'aac':
        return http_parser.MediaType('audio', 'aac');
      case 'opus':
        return http_parser.MediaType('audio', 'opus');
      case 'flac':
        return http_parser.MediaType('audio', 'flac');
      default:
        // Default to m4a for unknown extensions (common on mobile)
        return http_parser.MediaType('audio', 'm4a');
    }
  }
}
