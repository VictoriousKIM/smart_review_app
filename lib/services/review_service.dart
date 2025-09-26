import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review.dart';
import '../models/api_response.dart';
import '../config/supabase_config.dart';

class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  // 리뷰 작성
  Future<ApiResponse<Review>> createReview({
    required String campaignId,
    required String title,
    required String content,
    required int rating,
    List<String> images = const [],
    List<String> pros = const [],
    List<String> cons = const [],
    List<String> tags = const [],
    bool isVerified = false,
  }) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        return ApiResponse<Review>(success: false, error: '로그인이 필요합니다.');
      }

      final reviewData = {
        'campaign_id': campaignId,
        'user_id': user.id,
        'title': title,
        'content': content,
        'rating': rating,
        'images': images,
        'pros': pros,
        'cons': cons,
        'tags': tags,
        'is_verified': isVerified,
        'status': 'pending',
        'reward_earned': 0,
        'like_count': 0,
        'comment_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('reviews')
          .insert(reviewData)
          .select()
          .single();

      final review = Review.fromJson(response);

      return ApiResponse<Review>(
        success: true,
        data: review,
        message: '리뷰가 성공적으로 작성되었습니다.',
      );
    } catch (e) {
      return ApiResponse<Review>(success: false, error: e.toString());
    }
  }

  // 리뷰 목록 가져오기
  Future<ApiResponse<List<Review>>> getReviews({
    String? campaignId,
    int page = 1,
    int limit = 10,
    String? sortBy = 'latest',
  }) async {
    try {
      var query = _supabase.from('reviews').select().eq('status', 'approved');

      if (campaignId != null) {
        query = query.eq('campaign_id', campaignId);
      }

      final response = await query;

      final reviews = (response as List)
          .map((json) => Review.fromJson(json))
          .toList();

      return ApiResponse<List<Review>>(success: true, data: reviews);
    } catch (e) {
      return ApiResponse<List<Review>>(success: false, error: e.toString());
    }
  }

  // 리뷰 상세 정보 가져오기
  Future<ApiResponse<Review>> getReviewById(String reviewId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select()
          .eq('id', reviewId)
          .single();

      final review = Review.fromJson(response);

      return ApiResponse<Review>(success: true, data: review);
    } catch (e) {
      return ApiResponse<Review>(success: false, error: e.toString());
    }
  }

  // 사용자의 리뷰 목록
  Future<ApiResponse<List<Review>>> getUserReviews({
    String? userId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final targetUserId = userId ?? SupabaseConfig.client.auth.currentUser?.id;
      if (targetUserId == null) {
        return ApiResponse<List<Review>>(
          success: false,
          error: '사용자 ID가 필요합니다.',
        );
      }

      final response = await _supabase
          .from('reviews')
          .select()
          .eq('user_id', targetUserId);

      final reviews = (response as List)
          .map((json) => Review.fromJson(json))
          .toList();

      return ApiResponse<List<Review>>(success: true, data: reviews);
    } catch (e) {
      return ApiResponse<List<Review>>(success: false, error: e.toString());
    }
  }

  // 리뷰 수정
  Future<ApiResponse<Review>> updateReview({
    required String reviewId,
    String? title,
    String? content,
    int? rating,
    List<String>? images,
    List<String>? pros,
    List<String>? cons,
    List<String>? tags,
  }) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        return ApiResponse<Review>(success: false, error: '로그인이 필요합니다.');
      }

      // 리뷰 소유자 확인
      final review = await _supabase
          .from('reviews')
          .select('user_id')
          .eq('id', reviewId)
          .single();

      if (review['user_id'] != user.id) {
        return ApiResponse<Review>(success: false, error: '리뷰를 수정할 권한이 없습니다.');
      }

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (title != null) updateData['title'] = title;
      if (content != null) updateData['content'] = content;
      if (rating != null) updateData['rating'] = rating;
      if (images != null) updateData['images'] = images;
      if (pros != null) updateData['pros'] = pros;
      if (cons != null) updateData['cons'] = cons;
      if (tags != null) updateData['tags'] = tags;

      final response = await _supabase
          .from('reviews')
          .update(updateData)
          .eq('id', reviewId)
          .select()
          .single();

      final updatedReview = Review.fromJson(response);

      return ApiResponse<Review>(
        success: true,
        data: updatedReview,
        message: '리뷰가 성공적으로 수정되었습니다.',
      );
    } catch (e) {
      return ApiResponse<Review>(success: false, error: e.toString());
    }
  }

  // 리뷰 삭제
  Future<ApiResponse<bool>> deleteReview(String reviewId) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        return ApiResponse<bool>(success: false, error: '로그인이 필요합니다.');
      }

      // 리뷰 소유자 확인
      final review = await _supabase
          .from('reviews')
          .select('user_id')
          .eq('id', reviewId)
          .single();

      if (review['user_id'] != user.id) {
        return ApiResponse<bool>(success: false, error: '리뷰를 삭제할 권한이 없습니다.');
      }

      await _supabase.from('reviews').delete().eq('id', reviewId);

      return ApiResponse<bool>(
        success: true,
        data: true,
        message: '리뷰가 성공적으로 삭제되었습니다.',
      );
    } catch (e) {
      return ApiResponse<bool>(success: false, error: e.toString());
    }
  }

  // 리뷰 좋아요
  Future<ApiResponse<bool>> likeReview(String reviewId) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        return ApiResponse<bool>(success: false, error: '로그인이 필요합니다.');
      }

      // 이미 좋아요했는지 확인
      final existingLike = await _supabase
          .from('review_likes')
          .select()
          .eq('review_id', reviewId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingLike != null) {
        // 좋아요 취소
        await _supabase
            .from('review_likes')
            .delete()
            .eq('review_id', reviewId)
            .eq('user_id', user.id);

        // TODO: 좋아요 수 감소 로직 구현

        return ApiResponse<bool>(
          success: true,
          data: false,
          message: '좋아요를 취소했습니다.',
        );
      } else {
        // 좋아요 추가
        await _supabase.from('review_likes').insert({
          'review_id': reviewId,
          'user_id': user.id,
          'created_at': DateTime.now().toIso8601String(),
        });

        // TODO: 좋아요 수 증가 로직 구현

        return ApiResponse<bool>(
          success: true,
          data: true,
          message: '좋아요를 눌렀습니다.',
        );
      }
    } catch (e) {
      return ApiResponse<bool>(success: false, error: e.toString());
    }
  }

  // 댓글 작성
  Future<ApiResponse<Comment>> createComment({
    required String reviewId,
    required String content,
    String? parentId,
  }) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        return ApiResponse<Comment>(success: false, error: '로그인이 필요합니다.');
      }

      final commentData = {
        'review_id': reviewId,
        'user_id': user.id,
        'content': content,
        'parent_id': parentId,
        'like_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('comments')
          .insert(commentData)
          .select()
          .single();

      final comment = Comment.fromJson(response);

      // TODO: 댓글 수 증가 로직 구현

      return ApiResponse<Comment>(
        success: true,
        data: comment,
        message: '댓글이 작성되었습니다.',
      );
    } catch (e) {
      return ApiResponse<Comment>(success: false, error: e.toString());
    }
  }

  // 댓글 목록 가져오기
  Future<ApiResponse<List<Comment>>> getComments({
    required String reviewId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase
          .from('comments')
          .select()
          .eq('review_id', reviewId);

      final comments = (response as List)
          .map((json) => Comment.fromJson(json))
          .toList();

      return ApiResponse<List<Comment>>(success: true, data: comments);
    } catch (e) {
      return ApiResponse<List<Comment>>(success: false, error: e.toString());
    }
  }
}
