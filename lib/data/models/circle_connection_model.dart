class CircleConnectionModel {
  final int id;
  final int userId;
  final int connectedUserId;
  final String circleType;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ConnectedUser? connectedUser;

  CircleConnectionModel({
    required this.id,
    required this.userId,
    required this.connectedUserId,
    required this.circleType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.connectedUser,
  });

  factory CircleConnectionModel.fromJson(Map<String, dynamic> json) {
    return CircleConnectionModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      connectedUserId: json['connected_user_id'] ?? 0,
      circleType: json['circle_type'] ?? '',
      status: json['status'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      connectedUser: json['connected_user'] != null ? ConnectedUser.fromJson(json['connected_user']) : null,
    );
  }
}

class ConnectedUser {
  final int id;
  final String name;
  final String email;
  final bool isActive;
  final UserProfile? profile;

  ConnectedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.isActive,
    this.profile,
  });

  factory ConnectedUser.fromJson(Map<String, dynamic> json) {
    return ConnectedUser(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      isActive: json['is_active'] ?? true,
      profile: json['profile'] != null ? UserProfile.fromJson(json['profile']) : null,
    );
  }
}

class UserProfile {
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

  UserProfile({
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

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
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
