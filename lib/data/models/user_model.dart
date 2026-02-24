class User {
  final int id;
  final String name;
  final String email;
  final Profile? profile;
  final List<String>? interests;
  final List<String>? coreValues;
  final DateTime? createdAt;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? city;
  final String? state;
  final String? profession;
  final Membership? membership;
  final String? linkedinUrl;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? xUrl;
  final String? snapchatUrl;
  final String? tiktokUrl;
  final String? otherUrl;
  final String? accountType;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.profile,
    this.interests,
    this.coreValues,
    this.createdAt,
    this.displayName,
    this.avatarUrl,
    this.dateOfBirth,
    this.gender,
    this.city,
    this.state,
    this.profession,
    this.membership,
    this.linkedinUrl,
    this.facebookUrl,
    this.instagramUrl,
    this.xUrl,
    this.snapchatUrl,
    this.tiktokUrl,
    this.otherUrl,
    this.accountType,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final userData = json['user'] ?? json;
    final profileData = userData['profile'];

    List<String>? interests;
    if (userData['interests'] != null) {
      interests = List<String>.from(userData['interests']);
    } else if (profileData?['interests'] != null) {
      interests = List<String>.from(profileData['interests']);
    }

    List<String>? coreValues;
    if (userData['core_values'] != null) {
      coreValues = List<String>.from(userData['core_values']);
    } else if (profileData?['core_values'] != null) {
      coreValues = List<String>.from(profileData['core_values']);
    }

    String? displayName;
    if (userData['display_name'] != null) {
      displayName = userData['display_name'];
    } else if (profileData?['display_name'] != null) {
      displayName = profileData['display_name'];
    }

    String? avatarUrl;
    if (userData['avatar_url'] != null) {
      avatarUrl = userData['avatar_url'];
    } else if (profileData?['avatar'] != null) {
      avatarUrl = profileData['avatar'];
    }

    DateTime? dateOfBirth;
    final dobString = profileData?['date_of_birth'];
    if (dobString != null) {
      try {
        dateOfBirth = DateTime.parse(dobString);
      } catch (e) {
        dateOfBirth = null;
      }
    }

    String? gender = profileData?['gender'];
    String? city = profileData?['city'];
    String? state = profileData?['state'];
    String? profession = profileData?['profession'];
    String? linkedinUrl = profileData?['linkedin_url'];
    String? facebookUrl = profileData?['facebook_url'];
    String? instagramUrl = profileData?['instagram_url'];
    String? xUrl = profileData?['x_url'];
    String? snapchatUrl = profileData?['snapchat_url'];
    String? tiktokUrl = profileData?['tiktok_url'];
    String? otherUrl = profileData?['other_url'];
    String? accountType = profileData?['account_type'];

    Membership? membership;
    if (userData['membership'] != null) {
      membership = Membership.fromJson(userData['membership']);
    }

    return User(
      id: userData['id'],
      name: userData['name'],
      email: userData['email'],
      profile: profileData != null ? Profile.fromJson(profileData) : null,
      interests: interests,
      coreValues: coreValues,
      createdAt: userData['created_at'] != null ? DateTime.parse(userData['created_at']) : null,
      displayName: displayName,
      avatarUrl: avatarUrl,
      dateOfBirth: dateOfBirth,
      gender: gender,
      city: city,
      state: state,
      profession: profession,
      membership: membership,
      linkedinUrl: linkedinUrl,
      facebookUrl: facebookUrl,
      instagramUrl: instagramUrl,
      xUrl: xUrl,
      snapchatUrl: snapchatUrl,
      tiktokUrl: tiktokUrl,
      otherUrl: otherUrl,
      accountType: accountType,
    );
  }

  Map<String, dynamic> toJson() {
    final profileData = <String, dynamic>{};
    if (profile != null) {
      profileData.addAll(profile!.toJson());
    }
    if (dateOfBirth != null) {
      profileData['date_of_birth'] = dateOfBirth!.toIso8601String();
    }
    if (gender != null) {
      profileData['gender'] = gender;
    }
    if (city != null) {
      profileData['city'] = city;
    }
    if (state != null) {
      profileData['state'] = state;
    }
    if (profession != null) {
      profileData['profession'] = profession;
    }
    if (interests != null) {
      profileData['interests'] = interests;
    }
    if (coreValues != null) {
      profileData['core_values'] = coreValues;
    }

    return {
      'id': id,
      'name': name,
      'email': email,
      'profile': profileData.isNotEmpty ? profileData : null,
      'interests': interests,
      'core_values': coreValues,
      'created_at': createdAt?.toIso8601String(),
      'display_name': displayName,
      'avatar_url': avatarUrl,
      if (membership != null) 'membership': _membershipToJson(membership!),
    };
  }

  Map<String, dynamic> _membershipToJson(Membership membership) {
    return {
      'id': membership.id,
      'user_id': membership.userId,
      'membership_id': membership.membershipId,
      'status': membership.status,
      if (membership.membership != null)
        'membership': {
          'id': membership.membership!.id,
          'name': membership.membership!.name,
          'description': membership.membership!.description,
          'price': membership.membership!.price,
          if (membership.membership!.features != null)
            'features': {
              'inner_circle_limit': membership.membership!.features!.innerCircleLimit,
              'outer_circle_limit': membership.membership!.features!.outerCircleLimit,
              'daily_pulse_limit': membership.membership!.features!.dailyPulseLimit,
            },
        },
    };
  }
}

class Profile {
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final bool? restrictDm;

  Profile({
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.restrictDm,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      displayName: json['display_name'],
      bio: json['bio'],
      avatarUrl: json['avatar_url'],
      restrictDm: json['restrict_dm'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'bio': bio,
      'avatar_url': avatarUrl,
      'restrict_dm': restrictDm,
    };
  }
}

class AuthResponse {
  final User user;
  final String token;

  AuthResponse({
    required this.user,
    required this.token,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: User.fromJson(json['user']),
      token: json['token'],
    );
  }
}

class Membership {
  final int id;
  final int userId;
  final int membershipId;
  final String status;
  final int dailyPulsesUsed;
  final MembershipPlan? membership;

  Membership({
    required this.id,
    required this.userId,
    required this.membershipId,
    required this.status,
    required this.dailyPulsesUsed,
    this.membership,
  });

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      id: json['id'],
      userId: json['user_id'],
      membershipId: json['membership_id'],
      status: json['status'] ?? 'active',
      dailyPulsesUsed: json['daily_pulses_used'] ?? 0,
      membership: json['membership'] != null ? MembershipPlan.fromJson(json['membership']) : null,
    );
  }
}

class MembershipPlan {
  final int id;
  final String name;
  final String description;
  final String price;
  final MembershipFeatures? features;

  MembershipPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.features,
  });

  factory MembershipPlan.fromJson(Map<String, dynamic> json) {
    return MembershipPlan(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      price: json['price']?.toString() ?? '0.00',
      features: json['features'] != null ? MembershipFeatures.fromJson(json['features']) : null,
    );
  }
}

class MembershipFeatures {
  final int innerCircleLimit;
  final int outerCircleLimit;
  final int dailyPulseLimit;

  MembershipFeatures({
    required this.innerCircleLimit,
    required this.outerCircleLimit,
    required this.dailyPulseLimit,
  });

  factory MembershipFeatures.fromJson(Map<String, dynamic> json) {
    return MembershipFeatures(
      innerCircleLimit: json['inner_circle_limit'] ?? 0,
      outerCircleLimit: json['outer_circle_limit'] ?? 0,
      dailyPulseLimit: json['daily_pulse_limit'] ?? 0,
    );
  }
}
