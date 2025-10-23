import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  // For mobile: Replace 192.168.1.100 with YOUR computer's IP address from ipconfig
  // For web: Use http://127.0.0.1:8000
  static const String baseUrl = 'http://192.168.5.247:8000'; // CHANGE THIS IP!

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
      } else {
        throw Exception('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      throw Exception('Login failed: $e');
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
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to create issue');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Create issue error: $e');
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

  static Future<Map<String, dynamic>> createAdmin(
    String token,
    Map<String, dynamic> adminData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/super-admin/create-admin'),
        headers: _getAuthHeaders(token),
        body: jsonEncode(adminData),
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

      // Add audio file
      if (kIsWeb) {
        final bytes = await audioFile.readAsBytes();
        final filename = 'audio_${DateTime.now().millisecondsSinceEpoch}.webm';
        request.files.add(
          http.MultipartFile.fromBytes(
            'audio_file',
            bytes,
            filename: filename,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('audio_file', audioFile.path),
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
}
