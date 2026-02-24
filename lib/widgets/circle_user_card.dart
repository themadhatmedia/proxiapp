import 'package:flutter/material.dart';

class CircleUserCard extends StatelessWidget {
  final String name;
  final String? bio;
  final String? avatarUrl;
  final VoidCallback? onTap;
  final List<PopupMenuEntry<String>> menuItems;
  final Function(String) onMenuSelected;
  final bool isLoading;

  const CircleUserCard({
    super.key,
    required this.name,
    this.bio,
    this.avatarUrl,
    this.onTap,
    required this.menuItems,
    required this.onMenuSelected,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                    image: avatarUrl != null && avatarUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatarUrl == null || avatarUrl!.isEmpty
                      ? Icon(
                          Icons.person,
                          size: 24,
                          color: Colors.white.withOpacity(0.8),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (bio != null && bio!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          bio!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.7),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  PopupMenuButton<String>(
                    onSelected: onMenuSelected,
                    itemBuilder: (context) => menuItems,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert,
                      color: Colors.white.withOpacity(0.9),
                      size: 20,
                    ),
                    color: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    offset: const Offset(0, 40),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
