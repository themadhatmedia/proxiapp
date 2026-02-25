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
      connectedUser: json['connected_user'] != null ? ConnectedUser.fromJson(json['connected_user']) : (json['other_user'] != null ? ConnectedUser.fromJson(json['other_user']) : null),
    );
  }
}

class ConnectedUser {
  final int id;
  final String name;
  final String email;
  final bool isActive;
  final bool isAdmin;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? emailVerifiedAt;
  final DateTime? lastLoginAt;
  final UserProfile? profile;

  ConnectedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.isActive,
    required this.isAdmin,
    this.createdAt,
    this.updatedAt,
    this.emailVerifiedAt,
    this.lastLoginAt,
    this.profile,
  });

  factory ConnectedUser.fromJson(Map<String, dynamic> json) {
    return ConnectedUser(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      isActive: json['is_active'] ?? true,
      isAdmin: json['is_admin'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      emailVerifiedAt: json['email_verified_at'] != null ? DateTime.tryParse(json['email_verified_at']) : null,
      lastLoginAt: json['last_login_at'] != null ? DateTime.tryParse(json['last_login_at']) : null,
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
  final String? accountType;
  final bool locationVisible;
  final bool onlineStatus;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? linkedinUrl;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? xUrl;
  final String? snapchatUrl;
  final String? tiktokUrl;
  final String? otherUrl;
  final bool? restrictDm;

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
    this.accountType,
    required this.locationVisible,
    required this.onlineStatus,
    this.lastSeenAt,
    this.createdAt,
    this.updatedAt,
    this.linkedinUrl,
    this.facebookUrl,
    this.instagramUrl,
    this.xUrl,
    this.snapchatUrl,
    this.tiktokUrl,
    this.otherUrl,
    this.restrictDm,
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
      accountType: json['account_type'],
      locationVisible: json['location_visible'] ?? true,
      onlineStatus: json['online_status'] ?? false,
      lastSeenAt: json['last_seen_at'] != null ? DateTime.tryParse(json['last_seen_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      linkedinUrl: json['linkedin_url'],
      facebookUrl: json['facebook_url'],
      instagramUrl: json['instagram_url'],
      xUrl: json['x_url'],
      snapchatUrl: json['snapchat_url'],
      tiktokUrl: json['tiktok_url'],
      otherUrl: json['other_url'],
      restrictDm: json['restrict_dm'],
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
      'account_type': accountType,
      'location_visible': locationVisible,
      'online_status': onlineStatus,
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'linkedin_url': linkedinUrl,
      'facebook_url': facebookUrl,
      'instagram_url': instagramUrl,
      'x_url': xUrl,
      'snapchat_url': snapchatUrl,
      'tiktok_url': tiktokUrl,
      'other_url': otherUrl,
      'restrict_dm': restrictDm,
    };
  }
}
