import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key});

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
      appBar: AppBar(
        title: const Text(
          '이용가이드',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.black,
          indicatorWeight: 3,
          labelColor: Colors.black,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          unselectedLabelColor: Colors.grey[600],
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 16,
          ),
          tabs: const [
            Tab(text: '리뷰어'),
            Tab(text: '광고주'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildReviewerGuide(), _buildAdvertiserGuide()],
      ),
    );
  }

  Widget _buildReviewerGuide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGuideSection(
            title: '리뷰어 가이드',
            subtitle: '캠페인에 참여하고 리뷰를 작성하는 방법을 알아보세요',
            icon: Icons.rate_review,
            color: Colors.blue,
          ),
          const SizedBox(height: 24),

          _buildStepCard(
            step: 1,
            title: '캠페인 찾기',
            description: '홈 화면에서 관심 있는 캠페인을 찾아보세요',
            icon: Icons.search,
          ),

          _buildStepCard(
            step: 2,
            title: '캠페인 신청',
            description: '원하는 캠페인을 선택하고 신청 버튼을 눌러주세요',
            icon: Icons.touch_app,
          ),

          _buildStepCard(
            step: 3,
            title: '제품 체험',
            description: '승인 후 제품을 받아서 충분히 사용해보세요',
            icon: Icons.inventory,
          ),

          _buildStepCard(
            step: 4,
            title: '리뷰 작성',
            description: '체험한 내용을 바탕으로 솔직한 리뷰를 작성하세요',
            icon: Icons.edit,
          ),

          _buildStepCard(
            step: 5,
            title: '포인트 적립',
            description: '리뷰 작성 완료 시 포인트가 자동으로 적립됩니다',
            icon: Icons.stars,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvertiserGuide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGuideSection(
            title: '광고주 가이드',
            subtitle: '효과적인 캠페인을 생성하고 관리하는 방법을 알아보세요',
            icon: Icons.campaign,
            color: Colors.green,
          ),
          const SizedBox(height: 24),

          _buildStepCard(
            step: 1,
            title: '캠페인 생성',
            description: '마이페이지에서 새로운 캠페인을 생성하세요',
            icon: Icons.add_circle,
          ),

          _buildStepCard(
            step: 2,
            title: '캠페인 정보 입력',
            description: '제품 정보, 보상, 모집 인원 등을 상세히 입력하세요',
            icon: Icons.info,
          ),

          _buildStepCard(
            step: 3,
            title: '리뷰어 모집',
            description: '캠페인이 공개되어 리뷰어들이 신청할 수 있습니다',
            icon: Icons.people,
          ),

          _buildStepCard(
            step: 4,
            title: '신청자 관리',
            description: '신청한 리뷰어들을 검토하고 승인하세요',
            icon: Icons.checklist,
          ),

          _buildStepCard(
            step: 5,
            title: '성과 분석',
            description: '리뷰 결과와 캠페인 성과를 분석하세요',
            icon: Icons.analytics,
          ),
        ],
      ),
    );
  }

  Widget _buildGuideSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}








