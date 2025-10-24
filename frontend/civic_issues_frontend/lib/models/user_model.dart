class User {
  final int id;
  final String fullName;
  final String email;
  final String role;
  final String? district;
  final String? pincode;
  final bool isActive;
  final DateTime createdAt;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.district,
    this.pincode,
    required this.isActive,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'client',
      district: json['district'],
      pincode: json['pincode'],
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'role': role,
      'district': district,
      'pincode': pincode,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Helper getter for compatibility
  String get name => fullName;
}

// Note: Backend returns lowercase status values (pending, assigned, completed, verified)
// These enums are kept for reference but we use lowercase strings in actual code
enum ProblemStatus {
  pending,
  assigned,
  completed,
  verified,
}

enum MediaType {
  photoInitial,
  photoProof,
  audio,
  signature,
}

class UserInProblemResponse {
  final int id;
  final String fullName;

  UserInProblemResponse({
    required this.id,
    required this.fullName,
  });

  factory UserInProblemResponse.fromJson(Map<String, dynamic> json) {
    return UserInProblemResponse(
      id: json['id'],
      fullName: json['full_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
    };
  }
}

class Department {
  final int id;
  final String name;

  Department({
    required this.id,
    required this.name,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class WorkerInProblemResponse {
  final UserInProblemResponse user;
  final Department department;

  WorkerInProblemResponse({
    required this.user,
    required this.department,
  });

  factory WorkerInProblemResponse.fromJson(Map<String, dynamic> json) {
    return WorkerInProblemResponse(
      user: UserInProblemResponse.fromJson(json['user']),
      department: Department.fromJson(json['department']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'department': department.toJson(),
    };
  }
}

class Media {
  final int id;
  final int problemId;
  final String fileUrl;
  final String mediaType;

  Media({
    required this.id,
    required this.problemId,
    required this.fileUrl,
    required this.mediaType,
  });

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      id: json['id'],
      problemId: json['problem_id'],
      fileUrl: json['file_url'],
      mediaType: json['media_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'problem_id': problemId,
      'file_url': fileUrl,
      'media_type': mediaType,
    };
  }
}

class Feedback {
  final int id;
  final int problemId;
  final int userId;
  final String comment;
  final int rating;
  final String? sentiment;

  Feedback({
    required this.id,
    required this.problemId,
    required this.userId,
    required this.comment,
    required this.rating,
    this.sentiment,
  });

  factory Feedback.fromJson(Map<String, dynamic> json) {
    return Feedback(
      id: json['id'],
      problemId: json['problem_id'],
      userId: json['user_id'],
      comment: json['comment'],
      rating: json['rating'],
      sentiment: json['sentiment'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'problem_id': problemId,
      'user_id': userId,
      'comment': comment,
      'rating': rating,
      'sentiment': sentiment,
    };
  }
}

class Issue {
  final int id;
  final String title;
  final String description;
  final String status;
  final double priority;
  final String problemType;
  final String district;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final UserInProblemResponse submittedBy;
  final List<Media> mediaFiles;
  final List<Feedback> feedback;
  final WorkerInProblemResponse? assignedTo;
  final String? location;
  final double? latitude;
  final double? longitude;

  Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.problemType,
    required this.district,
    required this.createdAt,
    this.updatedAt,
    required this.submittedBy,
    required this.mediaFiles,
    required this.feedback,
    this.assignedTo,
    this.location,
    this.latitude,
    this.longitude,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      status: (json['status'] ?? 'pending').toString().toLowerCase(), // Backend returns lowercase
      priority: (json['priority'] ?? 0.0).toDouble(),
      problemType: json['problem_type'] ?? '',
      district: json['district'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      submittedBy: UserInProblemResponse.fromJson(json['submitted_by']),
      mediaFiles: (json['media_files'] as List<dynamic>?)
          ?.map((media) => Media.fromJson(media))
          .toList() ?? [],
      feedback: (json['feedback'] as List<dynamic>?)
          ?.map((feedback) => Feedback.fromJson(feedback))
          .toList() ?? [],
      assignedTo: json['assigned_to'] != null 
          ? WorkerInProblemResponse.fromJson(json['assigned_to']) 
          : null,
      location: json['location'] ?? 'Location not available',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'problem_type': problemType,
      'district': district,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'submitted_by': submittedBy.toJson(),
      'media_files': mediaFiles.map((media) => media.toJson()).toList(),
      'feedback': feedback.map((feedback) => feedback.toJson()).toList(),
      'assigned_to': assignedTo?.toJson(),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class Problem {
  final int id;
  final String title;
  final String description;
  final String problemType;
  final String district;
  final String location;
  final double priority;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int userId;
  final int? assignedWorkerId;
  final String? assignedTo;
  final String? submittedBy;
  final List<Map<String, dynamic>>? mediaFiles;

  Problem({
    required this.id,
    required this.title,
    required this.description,
    required this.problemType,
    required this.district,
    required this.location,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    this.assignedWorkerId,
    this.assignedTo,
    this.submittedBy,
    this.mediaFiles,
  });

  factory Problem.fromJson(Map<String, dynamic> json) {
    return Problem(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      problemType: json['problem_type'],
      district: json['district'],
      location: json['location'] ?? '',
      priority: (json['priority'] ?? 0.0).toDouble(),
      status: (json['status'] ?? 'pending').toString().toLowerCase(), // Backend returns lowercase
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at'] ?? json['created_at']),
      userId: json['user_id'],
      assignedWorkerId: json['assigned_worker_id'],
      assignedTo: json['assigned_to']?['full_name'],
      submittedBy: json['submitted_by']?['full_name'],
      mediaFiles: json['media_files']?.cast<Map<String, dynamic>>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'problem_type': problemType,
      'district': district,
      'location': location,
      'priority': priority,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user_id': userId,
      'assigned_worker_id': assignedWorkerId,
      'assigned_to': assignedTo,
      'submitted_by': submittedBy,
      'media_files': mediaFiles,
    };
  }
}

class WorkerStats {
  final int tasksCompleted;
  final int pendingTasks;
  final double averageRating;
  final int monthlyTasks;

  WorkerStats({
    required this.tasksCompleted,
    required this.pendingTasks,
    required this.averageRating,
    required this.monthlyTasks,
  });

  factory WorkerStats.fromJson(Map<String, dynamic> json) {
    return WorkerStats(
      tasksCompleted: json['tasks_completed'] ?? 0,
      pendingTasks: json['pending_tasks'] ?? 0,
      averageRating: (json['average_rating'] ?? 0.0).toDouble(),
      monthlyTasks: json['monthly_tasks'] ?? 0,
    );
  }
}

class AdminStats {
  final int totalIssues;
  final int pendingIssues;
  final int completedIssues;
  final double averageResolutionTime;

  AdminStats({
    required this.totalIssues,
    required this.pendingIssues,
    required this.completedIssues,
    required this.averageResolutionTime,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalIssues: json['total_issues'] ?? 0,
      pendingIssues: json['pending_issues'] ?? 0,
      completedIssues: json['completed_issues'] ?? 0,
      averageResolutionTime: (json['average_resolution_time'] ?? 0.0).toDouble(),
    );
  }
}

class Worker {
  final int id;
  final String fullName;
  final String email;
  final String department;
  final int tasksCompleted;
  final double rating;

  Worker({
    required this.id,
    required this.fullName,
    required this.email,
    required this.department,
    required this.tasksCompleted,
    required this.rating,
  });

  factory Worker.fromJson(Map<String, dynamic> json) {
    return Worker(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      department: json['department']?['name'] ?? 'Unknown',
      tasksCompleted: json['tasks_completed'] ?? 0,
      rating: (json['rating'] ?? 0.0).toDouble(),
    );
  }
}

class Admin {
  final int id;
  final String fullName;
  final String email;
  final String district;
  final String status;

  Admin({
    required this.id,
    required this.fullName,
    required this.email,
    required this.district,
    required this.status,
  });

  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      district: json['district'],
      status: json['is_active'] ? 'Active' : 'Inactive',
    );
  }
}

