import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/campaign.dart';
import '../../models/api_response.dart';
import '../../services/campaign_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class CampaignCreationScreen extends ConsumerStatefulWidget {
  const CampaignCreationScreen({super.key});

  @override
  ConsumerState<CampaignCreationScreen> createState() =>
      _CampaignCreationScreenState();
}

class _CampaignCreationScreenState
    extends ConsumerState<CampaignCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _productPriceController = TextEditingController();
  final _reviewRewardController = TextEditingController();

  // 폼 상태
  String _selectedCategory = 'reviewer';
  String _selectedType = 'reviewer';
  String _selectedPlatform = 'coupang';
  DateTime? _startDate;
  DateTime? _endDate;
  int _maxParticipants = 50;

  // 이전 캠페인 관련
  List<Campaign> _previousCampaigns = [];
  Campaign? _selectedPreviousCampaign;
  bool _isLoadingPreviousCampaigns = false;
  bool _isCreatingCampaign = false;

  // 에러 상태
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPreviousCampaigns();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _productPriceController.dispose();
    _reviewRewardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('캠페인 생성'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingPreviousCampaigns
                ? null
                : _loadPreviousCampaigns,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 에러 메시지 표시
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[800]),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _errorMessage = null),
                      ),
                    ],
                  ),
                ),
              ],

              // 이전 캠페인 불러오기
              _buildPreviousCampaignSelector(),
              const SizedBox(height: 24),

              // 캠페인 기본 정보
              _buildCampaignForm(),
              const SizedBox(height: 24),

              // 세션 정보
              _buildSessionForm(),
              const SizedBox(height: 24),

              // 생성 버튼
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviousCampaignSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Text(
                  '이전 캠페인 불러오기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingPreviousCampaigns)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<Campaign>(
                initialValue: _selectedPreviousCampaign,
                decoration: InputDecoration(
                  hintText: '이전 캠페인을 선택하세요 (선택사항)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                ),
                items: [
                  DropdownMenuItem<Campaign>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.add, color: Colors.green[600]),
                        const SizedBox(width: 8),
                        Text(
                          '새로 입력하기',
                          style: TextStyle(color: Colors.green[600]),
                        ),
                      ],
                    ),
                  ),
                  ..._previousCampaigns.map((campaign) {
                    return DropdownMenuItem<Campaign>(
                      value: campaign,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            campaign.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${campaign.category.name} • ${campaign.platform} • 사용 ${campaign.usageCount}회',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (Campaign? campaign) {
                  setState(() {
                    _selectedPreviousCampaign = campaign;
                    _errorMessage = null; // 에러 메시지 초기화
                    if (campaign != null) {
                      _fillFormWithPreviousCampaign(campaign);
                    } else {
                      _clearForm();
                    }
                  });
                },
              ),
            if (_previousCampaigns.isEmpty && !_isLoadingPreviousCampaigns)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '이전에 생성한 캠페인이 없습니다.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign, color: Colors.orange[600]),
                const SizedBox(width: 8),
                Text(
                  '캠페인 정보',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 캠페인 제목
            CustomTextField(
              controller: _titleController,
              labelText: '캠페인 제목 *',
              hintText: '예: 무선 이어폰 리뷰 캠페인',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '캠페인 제목을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 설명
            CustomTextField(
              controller: _descriptionController,
              labelText: '설명',
              hintText: '캠페인에 대한 자세한 설명을 입력하세요',
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // 카테고리와 타입
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: '카테고리 *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'reviewer', child: Text('리뷰어')),
                      DropdownMenuItem(value: 'press', child: Text('기자단')),
                      DropdownMenuItem(value: 'visit', child: Text('방문형')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      labelText: '타입 *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'reviewer', child: Text('리뷰어')),
                      DropdownMenuItem(value: 'press', child: Text('기자단')),
                      DropdownMenuItem(value: 'visit', child: Text('방문형')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 가격과 보상
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _productPriceController,
                    labelText: '상품 가격',
                    hintText: '0',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    controller: _reviewRewardController,
                    labelText: '리뷰 보상',
                    hintText: '0',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 플랫폼
            DropdownButtonFormField<String>(
              initialValue: _selectedPlatform,
              decoration: const InputDecoration(
                labelText: '플랫폼 *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'coupang', child: Text('쿠팡')),
                DropdownMenuItem(value: 'naver', child: Text('네이버')),
                DropdownMenuItem(value: '11st', child: Text('11번가')),
                DropdownMenuItem(value: 'gmarket', child: Text('G마켓')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPlatform = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.purple[600]),
                const SizedBox(width: 8),
                Text(
                  '세션 정보',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 시작일과 종료일
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: '시작일 *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(context, true),
                    controller: TextEditingController(
                      text: _startDate?.toString().split(' ')[0] ?? '',
                    ),
                    validator: (value) {
                      if (_startDate == null) {
                        return '시작일을 선택해주세요';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: '종료일 *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(context, false),
                    controller: TextEditingController(
                      text: _endDate?.toString().split(' ')[0] ?? '',
                    ),
                    validator: (value) {
                      if (_endDate == null) {
                        return '종료일을 선택해주세요';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 모집 인원
            TextFormField(
              decoration: const InputDecoration(
                labelText: '모집 인원 *',
                border: OutlineInputBorder(),
                suffixText: '명',
                hintText: '50',
              ),
              keyboardType: TextInputType.number,
              initialValue: _maxParticipants.toString(),
              onChanged: (value) {
                _maxParticipants = int.tryParse(value) ?? 50;
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '모집 인원을 입력해주세요';
                }
                final count = int.tryParse(value);
                if (count == null || count <= 0) {
                  return '올바른 인원수를 입력해주세요';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return CustomButton(
      text: '캠페인 생성하기',
      onPressed: _canCreateCampaign() && !_isCreatingCampaign
          ? _createCampaign
          : null,
      isLoading: _isCreatingCampaign,
    );
  }

  // 이전 캠페인 목록 로드
  Future<void> _loadPreviousCampaigns() async {
    setState(() {
      _isLoadingPreviousCampaigns = true;
      _errorMessage = null;
    });

    try {
      final response = await CampaignService().getUserPreviousCampaigns();
      if (response.success && response.data != null) {
        setState(() {
          _previousCampaigns = response.data!;
        });
      } else {
        setState(() {
          _errorMessage = '이전 캠페인을 불러오는데 실패했습니다: ${response.error}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoadingPreviousCampaigns = false;
      });
    }
  }

  // 이전 캠페인으로 폼 채우기
  void _fillFormWithPreviousCampaign(Campaign campaign) {
    try {
      _titleController.text = campaign.title;
      _descriptionController.text = campaign.description;
      _productPriceController.text = campaign.productPrice.toString();
      _reviewRewardController.text = campaign.reviewReward.toString();

      setState(() {
        _selectedCategory = campaign.category.name;
        _selectedType = campaign.type.name;
        _selectedPlatform = campaign.platform;
        _startDate = campaign.startDate;
        _endDate = campaign.endDate;
        _maxParticipants = campaign.maxParticipants ?? 50;
      });

      // 사용자에게 피드백 제공
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('이전 캠페인 정보가 자동으로 입력되었습니다. 필요시 수정하세요.'),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = '폼 자동완성 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 폼 초기화
  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _productPriceController.clear();
    _reviewRewardController.clear();

    setState(() {
      _selectedCategory = 'reviewer';
      _selectedType = 'reviewer';
      _selectedPlatform = 'coupang';
      _startDate = null;
      _endDate = null;
      _maxParticipants = 50;
    });
  }

  // 날짜 선택
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: isStartDate
            ? (_startDate ?? DateTime.now())
            : (_endDate ?? DateTime.now().add(const Duration(days: 30))),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );

      if (picked != null) {
        setState(() {
          if (isStartDate) {
            _startDate = picked;
            // 시작일이 종료일보다 늦으면 종료일도 조정
            if (_endDate != null && _startDate!.isAfter(_endDate!)) {
              _endDate = _startDate!.add(const Duration(days: 30));
            }
          } else {
            _endDate = picked;
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '날짜 선택 중 오류가 발생했습니다: $e';
      });
    }
  }

  bool _canCreateCampaign() {
    return _titleController.text.trim().isNotEmpty &&
        _startDate != null &&
        _endDate != null &&
        _maxParticipants > 0;
  }

  Future<void> _createCampaign() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreatingCampaign = true;
      _errorMessage = null;
    });

    try {
      ApiResponse<Campaign> response;

      if (_selectedPreviousCampaign != null) {
        // 이전 캠페인 기반으로 생성
        response = await CampaignService().createCampaignFromPrevious(
          previousCampaign: _selectedPreviousCampaign!,
          newTitle: _titleController.text.trim(),
          startDate: _startDate!,
          endDate: _endDate!,
          maxParticipants: _maxParticipants,
        );
      } else {
        // 신규 캠페인 생성
        response = await CampaignService().createCampaign(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          type: _selectedType,
          platform: _selectedPlatform,
          productPrice: int.tryParse(_productPriceController.text) ?? 0,
          reviewReward: int.tryParse(_reviewRewardController.text) ?? 0,
          startDate: _startDate!,
          endDate: _endDate!,
          maxParticipants: _maxParticipants,
        );
      }

      if (response.success && response.data != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? '캠페인이 성공적으로 생성되었습니다!'),
              backgroundColor: Colors.green[600],
            ),
          );
          context.pop();
        }
      } else {
        setState(() {
          _errorMessage = response.error ?? '캠페인 생성에 실패했습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '예상치 못한 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isCreatingCampaign = false;
      });
    }
  }
}
