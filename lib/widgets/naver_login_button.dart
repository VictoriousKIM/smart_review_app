import 'package:flutter/material.dart';
import '../services/naver_auth_service.dart';

/// 네이버 로그인 버튼 위젯
class NaverLoginButton extends StatefulWidget {
  final VoidCallback? onSuccess;
  final Function(String)? onError;

  const NaverLoginButton({
    super.key,
    this.onSuccess,
    this.onError,
  });

  @override
  State<NaverLoginButton> createState() => _NaverLoginButtonState();
}

class _NaverLoginButtonState extends State<NaverLoginButton> {
  final NaverAuthService _authService = NaverAuthService();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    try {
      final result = await _authService.signInWithNaver();

      if (result?.user != null) {
        widget.onSuccess?.call();
      }
    } catch (e) {
      widget.onError?.call(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF03C75A), // 네이버 그린
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'N',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '네이버로 시작하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}

