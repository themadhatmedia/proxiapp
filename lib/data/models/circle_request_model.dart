class CircleRequestModel {
  final int id;
  final int fromUserId;
  final int toUserId;
  final String circleType;
  final String status;
  final String? message;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RequestUser? toUser;
  final RequestUser? fromUser;

  CircleRequestModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.circleType,
    required this.status,
    this.message,
    required this.createdAt,
    required this.updatedAt,
    this.toUser,
    this.fromUser,
  });

  factory CircleRequestModel.fromJson(Map<String, dynamic> json) {
    return CircleRequestModel(
      id: json['id'] ?? 0,
      fromUserId: json['from_user_id'] ?? 0,
      toUserId: json['to_user_id'] ?? 0,
      circleType: json['circle_type'] ?? '',
      status: json['status'] ?? '',
      message: json['message'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      toUser: json['to_user'] != null ? RequestUser.fromJson(json['to_user']) : null,
      fromUser: json['from_user'] != null ? RequestUser.fromJson(json['from_user']) : null,
    );
  }
}

class RequestUser {
  final int id;
  final String name;
  final String email;
  final bool isActive;
  final RequestUserProfile? profile;

  RequestUser({
    required this.id,
    required this.name,
    required this.email,
    required this.isActive,
    this.profile,
  });

  factory RequestUser.fromJson(Map<String, dynamic> json) {
    return RequestUser(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      isActive: json['is_active'] ?? true,
      profile: json['profile'] != null ? RequestUserProfile.fromJson(json['profile']) : null,
    );
  }
}

class RequestUserProfile {
  final int id;
  final int userId;
  final String? displayName;
  final String? bio;
  final String? avatar;
  final String? banner;
  final String? dateOfBirth;
  final String? gender;
  final String? phone;
  final List<String>? interests;
  final List<String>? coreValues;
  final String? city;
  final String? state;
  final String? profession;
  final bool locationVisible;
  final bool onlineStatus;

  RequestUserProfile({
    required this.id,
    required this.userId,
    this.displayName,
    this.bio,
    this.avatar,
    this.banner,
    this.dateOfBirth,
    this.gender,
    this.phone,
    this.interests,
    this.coreValues,
    this.city,
    this.state,
    this.profession,
    required this.locationVisible,
    required this.onlineStatus,
  });

  factory RequestUserProfile.fromJson(Map<String, dynamic> json) {
    return RequestUserProfile(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      displayName: json['display_name'],
      bio: json['bio'],
      avatar: json['avatar'],
      banner: json['banner'],
      dateOfBirth: json['date_of_birth'],
      gender: json['gender'],
      phone: json['phone'],
      interests: json['interests'] != null ? List<String>.from(json['interests']) : null,
      coreValues: json['core_values'] != null ? List<String>.from(json['core_values']) : null,
      city: json['city'],
      state: json['state'],
      profession: json['profession'],
      locationVisible: json['location_visible'] ?? true,
      onlineStatus: json['online_status'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'display_name': displayName,
      'bio': bio,
      'avatar': avatar,
      'banner': banner,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'phone': phone,
      'interests': interests,
      'core_values': coreValues,
      'city': city,
      'state': state,
      'profession': profession,
      'location_visible': locationVisible,
      'online_status': onlineStatus,
    };
  }
}
