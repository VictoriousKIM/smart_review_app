import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_review_app/services/r2_upload_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mock 플러그인 등록
    const MethodChannel(
      'plugins.flutter.io/shared_preferences',
    ).setMockMethodCallHandler((call) async {
      if (call.method == 'getAll') {
        return <String, dynamic>{}; // 빈 맵 반환
      }
      return null;
    });

    // Supabase 초기화 (테스트 환경용)
    await Supabase.initialize(
      url: kDebugMode
          ? 'http://127.0.0.1:54321'
          : 'https://ythmnhadeyfusmfhcgdr.supabase.co',
      anonKey: kDebugMode
          ? 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH'
          : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl0aG1uaGFkZXlmdXNtZmhjZ2RyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwMDU4MDQsImV4cCI6MjA3MzU4MTgwNH0.BzTELGjnSewXprm_3mjJnOXusvp5Sw5jagpmKUYEM50',
      debug: true,
    );
    print('✅ Supabase 초기화 완료');
  });

  group('R2 Upload Service Tests', () {
    test('사업자등록증 업로드 테스트', () async {
      // 테스트 이미지 파일 읽기
      final imageFile = File('사업자등록증(포인터스) (1).png');

      if (!await imageFile.exists()) {
        throw Exception('테스트 이미지 파일을 찾을 수 없습니다: ${imageFile.path}');
      }

      final imageBytes = await imageFile.readAsBytes();
      print('📄 이미지 파일 크기: ${imageBytes.length} bytes');

      // 테스트 사용자 ID (seed.sql에 정의된 UUID 사용)
      const userId = '5d1e6c3b-7202-4dd8-9a67-d1ff0363f2f1';
      print('👤 사용자 ID: $userId');

      try {
        // 사업자등록증 업로드
        print('🚀 업로드 시작...');
        final uploadedUrl = await R2UploadService.uploadBusinessRegistration(
          fileBytes: Uint8List.fromList(imageBytes),
          fileName: '사업자등록증_테스트.png',
          userId: userId,
        );

        print('✅ 업로드 성공!');
        print('📎 업로드된 URL: $uploadedUrl');

        // 업로드된 파일 존재 여부 확인
        final exists = await R2UploadService.fileExists(uploadedUrl);
        print('🔍 파일 존재 여부: $exists');

        expect(exists, true);
        expect(uploadedUrl, isNotEmpty);
        expect(uploadedUrl, startsWith('http'));
      } catch (e, stackTrace) {
        print('❌ 업로드 실패: $e');
        print('📚 스택 트레이스: $stackTrace');
        rethrow;
      }
    });

    test('파일 검증 테스트 - 지원하지 않는 확장자', () {
      final bytes = Uint8List.fromList([1, 2, 3]);

      expect(
        () => R2UploadService.uploadBusinessRegistration(
          fileBytes: bytes,
          fileName: 'test.xyz',
          userId: 'test-user-id',
        ),
        throwsException,
      );
    });

    test('파일 검증 테스트 - 파일 크기 초과', () {
      final bytes = Uint8List(11 * 1024 * 1024); // 11MB

      expect(
        () => R2UploadService.uploadBusinessRegistration(
          fileBytes: bytes,
          fileName: 'test.png',
          userId: 'test-user-id',
        ),
        throwsException,
      );
    });
  });
}
