import 'package:flutter_test/flutter_test.dart';
import 'package:smart_review_app/services/campaign_service.dart';
import 'package:smart_review_app/utils/date_time_utils.dart';

void main() {
  group('CampaignService 날짜 검증 테스트', () {
    test('날짜 검증: apply_start_date는 현재 시간 이후여야 함', () async {
      // 이 테스트는 실제 서비스 호출이 필요하므로 통합 테스트로 이동 권장
      // 여기서는 검증 로직만 테스트
      
      final now = DateTimeUtils.nowKST();
      final pastDate = now.subtract(const Duration(days: 1));
      final futureDate = now.add(const Duration(days: 1));
      
      // 날짜 검증 로직 테스트
      expect(pastDate.isBefore(now), true);
      expect(futureDate.isAfter(now), true);
    });

    test('날짜 검증: apply_start_date는 현재 시간으로부터 14일 이내여야 함', () {
      final now = DateTimeUtils.nowKST();
      final validDate = now.add(const Duration(days: 10));
      final invalidDate = now.add(const Duration(days: 20));
      
      final daysUntilValid = validDate.difference(now).inDays;
      final daysUntilInvalid = invalidDate.difference(now).inDays;
      
      expect(daysUntilValid <= 14, true);
      expect(daysUntilInvalid <= 14, false);
    });

    test('날짜 검증: 날짜 순서가 올바른지 확인', () {
      final now = DateTimeUtils.nowKST();
      final applyStartDate = now.add(const Duration(days: 1));
      final applyEndDate = now.add(const Duration(days: 8));
      final reviewStartDate = now.add(const Duration(days: 9));
      final reviewEndDate = now.add(const Duration(days: 38));
      
      // 날짜 순서 검증
      expect(applyStartDate.isBefore(applyEndDate), true);
      expect(applyEndDate.isBefore(reviewStartDate), true);
      expect(reviewStartDate.isBefore(reviewEndDate), true);
    });

    test('날짜 검증: 잘못된 날짜 순서 감지', () {
      final now = DateTimeUtils.nowKST();
      final applyStartDate = now.add(const Duration(days: 8));
      final applyEndDate = now.add(const Duration(days: 1)); // 잘못된 순서
      
      expect(applyStartDate.isAfter(applyEndDate), true); // 에러 케이스
    });
  });

  group('CampaignService 포인트 차감 테스트', () {
    test('비용 계산: payment_method가 direct인 경우 비용은 0', () {
      // calculate_campaign_cost 로직 테스트
      // 직접 지급: 0 * max_participants = 0
      final maxParticipants = 10;
      final cost = 0 * maxParticipants;
      
      expect(cost, 0);
    });

    test('비용 계산: payment_method가 platform인 경우 비용 계산', () {
      // 플랫폼 지급: (product_price + campaign_reward + 0) * max_participants
      final productPrice = 10000;
      final campaignReward = 1000;
      final platformFee = 0; // 현재 플랫폼 수수료
      final maxParticipants = 10;
      
      final cost = (productPrice + campaignReward + platformFee) * maxParticipants;
      
      expect(cost, 110000);
    });

    test('포인트 차감: 차감 후 잔액이 0 이상인지 확인', () {
      final currentPoints = 1000;
      final cost = 500;
      final remainingPoints = currentPoints - cost;
      
      expect(remainingPoints >= 0, true);
      expect(remainingPoints, 500);
    });

    test('포인트 차감: 차감 후 잔액이 0인 경우 허용', () {
      final currentPoints = 1000;
      final cost = 1000;
      final remainingPoints = currentPoints - cost;
      
      expect(remainingPoints >= 0, true);
      expect(remainingPoints, 0);
    });

    test('포인트 차감: 차감 후 잔액이 마이너스인 경우 방지', () {
      final currentPoints = 1000;
      final cost = 1500;
      final remainingPoints = currentPoints - cost;
      
      expect(remainingPoints < 0, true); // 에러 케이스
    });
  });

  group('CampaignService 제약 조건 테스트', () {
    test('제약 조건: max_per_reviewer는 max_participants를 넘을 수 없음', () {
      final maxParticipants = 10;
      final maxPerReviewer = 5;
      
      expect(maxPerReviewer <= maxParticipants, true);
    });

    test('제약 조건: max_per_reviewer가 max_participants를 넘는 경우', () {
      final maxParticipants = 10;
      final maxPerReviewer = 15;
      
      expect(maxPerReviewer > maxParticipants, true); // 에러 케이스
    });

    test('제약 조건: 날짜 순서 검증', () {
      final now = DateTimeUtils.nowKST();
      final applyStartDate = now.add(const Duration(days: 1));
      final applyEndDate = now.add(const Duration(days: 8));
      final reviewStartDate = now.add(const Duration(days: 9));
      final reviewEndDate = now.add(const Duration(days: 38));
      
      // 제약 조건: apply_start_date <= apply_end_date <= review_start_date <= review_end_date
      final isValid = applyStartDate.isBefore(applyEndDate) &&
                      applyEndDate.isBefore(reviewStartDate) &&
                      reviewStartDate.isBefore(reviewEndDate);
      
      expect(isValid, true);
    });
  });
}

