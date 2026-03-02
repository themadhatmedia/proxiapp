import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/discover_controller.dart';
import '../../widgets/discover_post_card.dart';
import '../posts/create_post_screen.dart';
import '../posts/my_posts_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFabExpanded = false;
  final DiscoverController _controller = Get.put(DiscoverController());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF0A0A0A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Wins',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              _buildToggleTabs(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInnerProxiList(),
                    _buildOuterProxiList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildSpeedDialFab(),
    );
  }

  Widget _buildSpeedDialFab() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        if (_isFabExpanded)
          GestureDetector(
            onTap: () {
              setState(() {
                _isFabExpanded = false;
              });
            },
            child: Container(
              color: Colors.black.withOpacity(0.5),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_isFabExpanded) ...[
              _buildSpeedDialOption(
                icon: Icons.add,
                label: 'Create Post',
                onTap: () async {
                  setState(() {
                    _isFabExpanded = false;
                  });
                  final result = await Get.to(() => const CreatePostScreen());
                  if (result == true) {
                    _controller.fetchPosts();
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildSpeedDialOption(
                icon: Icons.article_outlined,
                label: 'My Posts',
                onTap: () async {
                  setState(() {
                    _isFabExpanded = false;
                  });
                  await Get.to(() => const MyPostsScreen());
                },
              ),
              const SizedBox(height: 16),
            ],
            FloatingActionButton(
              heroTag: 'discover_fab',
              onPressed: () {
                setState(() {
                  _isFabExpanded = !_isFabExpanded;
                });
              },
              backgroundColor: Colors.white,
              child: AnimatedRotation(
                turns: _isFabExpanded ? 0.250 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isFabExpanded ? Icons.close : Icons.add,
                  color: Colors.black,
                  size: 28.0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeedDialOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.black,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(28.0),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(28.0),
            shape: BoxShape.rectangle,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Inner Proxi'),
            Tab(text: 'Outer Proxi'),
          ],
        ),
      ),
    );
  }

  Widget _buildInnerProxiList() {
    return Obx(() {
      if (_controller.isLoadingInner.value) {
        return const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        );
      }

      if (_controller.innerProxyPosts.isEmpty) {
        return RefreshIndicator(
          onRefresh: _controller.refreshInnerPosts,
          color: Colors.white,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Center(
                  child: Text(
                    'No posts yet',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _controller.refreshInnerPosts,
        color: Colors.white,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: _controller.innerProxyPosts.length,
          itemBuilder: (context, index) {
            final post = _controller.innerProxyPosts[index];
            return DiscoverPostCard(post: post);
          },
        ),
      );
    });
  }

  Widget _buildOuterProxiList() {
    return Obx(() {
      if (_controller.isLoadingOuter.value) {
        return const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        );
      }

      if (_controller.outerProxyPosts.isEmpty) {
        return RefreshIndicator(
          onRefresh: _controller.refreshOuterPosts,
          color: Colors.white,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Center(
                  child: Text(
                    'No posts yet',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _controller.refreshOuterPosts,
        color: Colors.white,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: _controller.outerProxyPosts.length,
          itemBuilder: (context, index) {
            final post = _controller.outerProxyPosts[index];
            return DiscoverPostCard(post: post);
          },
        ),
      );
    });
  }
}
