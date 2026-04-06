import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../controllers/bookmarks_controller.dart';
import '../../widgets/circle_user_card.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(BookmarksController());
    final scrollController = ScrollController();
    final cs = Theme.of(context).colorScheme;

    scrollController.addListener(() {
      if (scrollController.position.pixels >= scrollController.position.maxScrollExtent * 0.8) {
        controller.loadBookmarks();
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: context.proxi.surfaceCard,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Bookmarks',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.scaffoldGradient(context),
        ),
        child: Obx(() {
          if (controller.isLoading.value && controller.bookmarkedUsers.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(ProxiPalette.bookmarkSaved),
              ),
            );
          }

          if (controller.bookmarkedUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 80,
                    color: cs.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No bookmarks yet',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Users you bookmark will appear here',
                    style: TextStyle(
                      color: cs.onSurfaceVariant.withOpacity(0.85),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => controller.loadBookmarks(refresh: true),
            color: ProxiPalette.bookmarkSaved,
            backgroundColor: cs.surfaceContainerHighest,
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: controller.bookmarkedUsers.length + (controller.hasMore.value ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == controller.bookmarkedUsers.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: const AlwaysStoppedAnimation<Color>(ProxiPalette.bookmarkSaved),
                      ),
                    ),
                  );
                }

                final user = controller.bookmarkedUsers[index];
                return CircleUserCard(
                  user: user,
                  showBookmarkButton: true,
                  requireRemoveBookmarkConfirmation: true,
                  bottomMargin: 6,
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
