import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../posts/create_post_screen.dart';
import '../posts/my_posts_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with SingleTickerProviderStateMixin {
  bool _isRefreshing = false;
  late TabController _tabController;
  bool _isFabExpanded = false;

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

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isRefreshing = false);
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
                    _buildPostList(isInnerProxi: true),
                    _buildPostList(isInnerProxi: false),
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
                    _handleRefresh();
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

  Widget _buildPostList({required bool isInnerProxi}) {
    final posts = isInnerProxi
        ? [
            {
              'name': 'Nick Gartside',
              'date': '12/10/2025 12:39 AM',
              'content': 'Proxi! Proxi! Proxi!',
              'likes': 3,
              'comments': 0,
            },
            {
              'name': 'Trace Sheridan',
              'date': '12/05/2025 12:22 AM',
              'content': 'Wow, very clean and intuitive provisioning. Well done Joe!',
              'likes': 2,
              'comments': 2,
            },
            {
              'name': 'Joe Rodriguez',
              'date': '12/04/2025 11:53 AM',
              'content': 'We got it!!! Will we Beezing the Leeall!!!',
              'likes': 5,
              'comments': 1,
            },
          ]
        : [
            {
              'name': 'Jay Tarpara',
              'date': '02/04/2026 10:10 PM',
              'content': 'Test post',
              'likes': 1,
              'comments': 1,
            },
            {
              'name': 'Sarah Johnson',
              'date': '12/03/2025 09:15 AM',
              'content': 'Loving this community!',
              'likes': 8,
              'comments': 3,
            },
          ];

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return _buildPostCard(
            name: post['name'] as String,
            date: post['date'] as String,
            content: post['content'] as String,
            likes: post['likes'] as int,
            comments: post['comments'] as int,
          );
        },
      ),
    );
  }

  Widget _buildPostCard({
    required String name,
    required String date,
    required String content,
    required int likes,
    required int comments,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white60,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      date,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.favorite_border,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                likes.toString(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 20),
              Icon(
                Icons.chat_bubble_outline,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                comments.toString(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Show comments',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
