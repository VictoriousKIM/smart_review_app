import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart' as app_user;
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../home/home_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  final bool isSocialLogin;

  const SignupScreen({super.key, this.isSocialLogin = false});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  bool _isLoading = false;
  app_user.UserType _selectedUserType = app_user.UserType.reviewer;

  @override
  void initState() {
    super.initState();
    // 소셜 로그인인 경우 현재 사용자 정보로 초기화
    if (widget.isSocialLogin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final authState = ref.read(authProvider);
        authState.when(
          data: (user) {
            if (user != null && user.displayName != null) {
              _displayNameController.text = user.displayName!;
            }
          },
          loading: () {},
          error: (_, __) {},
        );
      });
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 소셜 로그인인 경우 프로필 업데이트
      if (widget.isSocialLogin) {
        await ref.read(authProvider.notifier).updateProfile({
          'display_name': _displayNameController.text.trim(),
          'user_type': _selectedUserType.name,
        });
      } else {
        // 일반 회원가입 (현재는 사용하지 않음)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('소셜 로그인을 사용해주세요')));
        return;
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('프로필 완성 실패: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSocialLogin ? '프로필 완성' : '회원가입'),
        leading: widget.isSocialLogin
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 소셜 로그인인 경우 안내 메시지
                if (widget.isSocialLogin) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '소셜 로그인이 완료되었습니다.\n추가 정보를 입력해주세요.',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 사용자 타입 선택
                Text(
                  '사용자 타입을 선택해주세요',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                RadioTheme(
                  data: RadioThemeData(
                    fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Theme.of(context).colorScheme.primary;
                      }
                      return Colors.grey;
                    }),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: RadioListTile<app_user.UserType>(
                          title: const Text('리뷰어'),
                          subtitle: const Text('리뷰를 작성합니다'),
                          value: app_user.UserType.reviewer,
                          groupValue: _selectedUserType,
                          onChanged: (value) {
                            setState(() {
                              _selectedUserType = value!;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<app_user.UserType>(
                          title: const Text('광고주'),
                          subtitle: const Text('캠페인을 관리합니다'),
                          value: app_user.UserType.advertiser,
                          groupValue: _selectedUserType,
                          onChanged: (value) {
                            setState(() {
                              _selectedUserType = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 표시 이름 입력
                CustomTextField(
                  controller: _displayNameController,
                  labelText: '표시 이름',
                  prefixIcon: Icons.person_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '표시 이름을 입력해주세요';
                    }
                    if (value.length < 2) {
                      return '표시 이름은 2자 이상이어야 합니다';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // 완료 버튼
                CustomButton(
                  text: widget.isSocialLogin ? '프로필 완성' : '회원가입',
                  onPressed: _isLoading ? null : _completeProfile,
                  isLoading: _isLoading,
                ),

                // 일반 회원가입인 경우에만 로그인 링크 표시
                if (!widget.isSocialLogin) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '이미 계정이 있으신가요? ',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('로그인'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
