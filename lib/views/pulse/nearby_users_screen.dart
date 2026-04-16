import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../utils/pulse_distance_format.dart';
import '../../widgets/safe_avatar.dart';
import 'user_profile_detail_screen.dart';

class NearbyUsersScreen extends StatefulWidget {
  final Map<String, dynamic> nearbyUsersData;
  final int selectedRadius;
  /// Matches GET /puls/distance-options `distance_unit`.
  final String distanceUnit;
  final Position currentPosition;
  final ScrollController? scrollController;

  const NearbyUsersScreen({
    super.key,
    required this.nearbyUsersData,
    required this.selectedRadius,
    this.distanceUnit = 'yards',
    required this.currentPosition,
    this.scrollController,
  });

  @override
  State<NearbyUsersScreen> createState() => _NearbyUsersScreenState();
}

class _NearbyUsersScreenState extends State<NearbyUsersScreen> {
  late int _localFilterRadius;

  @override
  void initState() {
    super.initState();
    _localFilterRadius = widget.selectedRadius;
  }

  List<int> _buildLocalFilterOptions() {
    final maxRadius = widget.selectedRadius;
    if (maxRadius <= 1) return const [];
    final values = <int>[];
    for (int i = 1; i < maxRadius; i += 2) {
      values.add(i);
    }
    return values;
  }

  List<dynamic> _sortUsersByMatchScore(List<dynamic> users) {
    final sortedUsers = List<dynamic>.from(users);
    sortedUsers.sort((a, b) {
      final scoreA = a['match_score'] ?? 0;
      final scoreB = b['match_score'] ?? 0;
      return scoreB.compareTo(scoreA);
    });
    return sortedUsers;
  }

  double _userDistance(dynamic user) {
    final raw = user['distance'];
    if (raw is num) return raw.toDouble();
    return double.tryParse('$raw') ?? 0;
  }

  List<dynamic> _applyLocalRadiusFilter(List<dynamic> users) {
    final maxDistance = _localFilterRadius.toDouble();
    return users.where((u) => _userDistance(u) <= maxDistance).toList();
  }

  Widget _buildLocalFilterChips(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final options = _buildLocalFilterOptions();
    if (options.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter by distance',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                context: context,
                value: widget.selectedRadius,
                label: 'All',
                selected: _localFilterRadius == widget.selectedRadius,
                onTap: () {
                  setState(() => _localFilterRadius = widget.selectedRadius);
                },
              ),
              ...options.map((r) => _buildFilterChip(
                    context: context,
                    value: r,
                    label: '$r',
                    selected: _localFilterRadius == r,
                    onTap: () {
                      setState(() => _localFilterRadius = r);
                    },
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required int value,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final unit = pulseDistanceUnitDisplay(widget.distanceUnit);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? cs.primary : context.proxi.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? cs.primary : cs.outline.withOpacity(0.4),
            ),
          ),
          child: Text(
            label == 'All' ? '$label ($value $unit)' : '$label $unit',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rawUsers = widget.nearbyUsersData['users'] as List<dynamic>? ?? [];
    final users = _sortUsersByMatchScore(rawUsers);
    final filteredUsers = _applyLocalRadiusFilter(users);

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.scaffoldGradient(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 5.0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: cs.onSurface),
                ),
                Expanded(
                  child: Text(
                    'Nearby Users',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.proxi.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.outline.withOpacity(0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Users Found',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${filteredUsers.length}/${users.length}',
                        style: TextStyle(
                          fontSize: 28,
                          color: cs.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Search Radius',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.selectedRadius} ${pulseDistanceUnitDisplay(widget.distanceUnit)}',
                        style: TextStyle(
                          fontSize: 28,
                          color: cs.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: _buildLocalFilterChips(context),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: cs.onSurfaceVariant.withOpacity(0.35),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found nearby',
                          style: TextStyle(
                            fontSize: 18,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return _buildUserCard(context, user, widget.distanceUnit);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, dynamic user, String distanceUnit) {
    final cs = Theme.of(context).colorScheme;
    final userData = user['user'] ?? user;
    final profile = userData['profile'] ?? {};

    final name = userData['name'] ?? profile['display_name'] ?? 'Unknown User';
    final bio = profile['bio'] ?? '';
    final avatarUrl = profile['avatar'];
    final matchScore = user['match_score'] ?? 0;
    final distance = (user['distance'] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.proxi.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeAvatar(
                imageUrl: avatarUrl,
                size: 80,
                fallbackText: name,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _getMatchColor(matchScore).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$matchScore%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _getMatchColor(matchScore),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getMatchLabel(matchScore),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getMatchColor(matchScore).withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        bio,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatPulseDistanceAway(distance, distanceUnit),
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement messaging feature
                  },
                  icon: const Icon(Icons.message, size: 18),
                  label: const Text(
                    'Send Message',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: cs.onSurface,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      enableDrag: true,
                      isDismissible: true,
                      builder: (context) => DraggableScrollableSheet(
                        initialChildSize: 0.95,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        expand: false,
                        builder: (context, scrollController) => UserProfileDetailScreen(
                          userData: user,
                          distanceUnit: distanceUnit,
                          scrollController: scrollController,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person, size: 18),
                  label: const Text(
                    'See Profile',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getMatchColor(int score) {
    if (score > 80) {
      return const Color(0xFF4CAF50);
    } else if (score >= 50) {
      return const Color(0xFFFFA726);
    } else {
      return const Color(0xFFE74C3C);
    }
  }

  String _getMatchLabel(int score) {
    if (score > 80) {
      return 'Great Potential';
    } else if (score >= 50) {
      return 'Good Potential';
    } else {
      return 'Potential';
    }
  }
}
