import 'package:flutter/material.dart';

class SafeAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final String fallbackText;
  final BoxFit fit;

  const SafeAvatar({
    super.key,
    this.imageUrl,
    required this.size,
    this.fallbackText = 'U',
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.primary.withOpacity(0.85),
      ),
      child: ClipOval(
        child: _buildContent(cs),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback(cs);
    }

    return Image.network(
      imageUrl!,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _buildFallback(Theme.of(context).colorScheme),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildFallback(Theme.of(context).colorScheme);
      },
    );
  }

  Widget _buildFallback(ColorScheme cs) {
    return Center(
      child: Text(
        fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : 'U',
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
