import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// 시각적으로 이미지를 크롭할 수 있는 위젯
class ImageCropEditor extends StatefulWidget {
  final Uint8List imageBytes;
  final img.Image? decodedImage;
  final Rect? initialCrop;

  const ImageCropEditor({
    super.key,
    required this.imageBytes,
    this.decodedImage,
    this.initialCrop,
  });

  @override
  State<ImageCropEditor> createState() => _ImageCropEditorState();
}

class _ImageCropEditorState extends State<ImageCropEditor> {
  late img.Image _image;
  Rect? _cropRect;
  Offset? _dragStart;
  Rect? _dragStartRect; // 드래그 시작 시 크롭 영역 저장
  String _dragMode = 'none';
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _image = widget.decodedImage ?? img.decodeImage(widget.imageBytes)!;
    _cropRect =
        widget.initialCrop ??
        Rect.fromLTWH(0, 0, _image.width / 2, _image.height.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final imageWidth = _image.width.toDouble();
    final imageHeight = _image.height.toDouble();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final maxDialogWidth = screenWidth - 32;
    final maxDialogHeight = screenHeight - 32;

    const headerHeight = 60.0;
    const buttonHeight = 80.0;
    const padding = 32.0 * 2;

    final availableWidth = maxDialogWidth - padding;
    final availableHeight =
        maxDialogHeight - headerHeight - buttonHeight - padding;

    final imageAspect = imageWidth / imageHeight;
    final availableAspect = availableWidth / availableHeight;

    double displayWidth, displayHeight;
    if (imageAspect > availableAspect) {
      displayWidth = availableWidth;
      displayHeight = availableWidth / imageAspect;
    } else {
      displayHeight = availableHeight;
      displayWidth = availableHeight * imageAspect;
    }

    _scale = displayWidth / imageWidth;

    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxDialogWidth,
          maxHeight: maxDialogHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.crop, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '상품 이미지 크롭',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${_image.width}x${_image.height}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // 이미지 및 크롭 영역
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: Container(
                      width: displayWidth,
                      height: displayHeight,
                      color: Colors.grey[200],
                      child: Stack(
                        children: [
                          // 원본 이미지 (정확한 위치에 배치)
                          Positioned(
                            left: 0,
                            top: 0,
                            width: displayWidth,
                            height: displayHeight,
                            child: Image.memory(
                              widget.imageBytes,
                              width: displayWidth,
                              height: displayHeight,
                              fit: BoxFit.fill, // 정확한 크기로 채우기
                            ),
                          ),

                          // 크롭 영역 외부 어두운 오버레이
                          if (_cropRect != null) ...[
                            _buildDarkOverlay(displayWidth, displayHeight),
                            _buildCropBorder(),
                            ..._buildHandles(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 하단 버튼
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_cropRect != null)
                    Text(
                      'X: ${_cropRect!.left.toInt()}, Y: ${_cropRect!.top.toInt()}\n'
                      'W: ${_cropRect!.width.toInt()}, H: ${_cropRect!.height.toInt()}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    )
                  else
                    const SizedBox.shrink(),

                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _cropRect = Rect.fromLTWH(
                              0,
                              0,
                              _image.width / 2,
                              _image.height.toDouble(),
                            );
                          });
                        },
                        child: const Text('왼쪽 절반'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _cropRect = Rect.fromLTWH(
                              _image.width / 4,
                              0,
                              _image.width / 2,
                              _image.height.toDouble(),
                            );
                          });
                        },
                        child: const Text('중앙'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('취소'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (_cropRect != null) {
                            Navigator.pop(context, {
                              'x': _cropRect!.left.toInt(),
                              'y': _cropRect!.top.toInt(),
                              'width': _cropRect!.width.toInt(),
                              'height': _cropRect!.height.toInt(),
                            });
                          }
                        },
                        child: const Text('적용'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 어두운 오버레이 빌드 (크롭 영역 외부)
  Widget _buildDarkOverlay(double displayWidth, double displayHeight) {
    if (_cropRect == null) return const SizedBox.shrink();

    final left = _cropRect!.left * _scale;
    final top = _cropRect!.top * _scale;
    final width = _cropRect!.width * _scale;
    final height = _cropRect!.height * _scale;

    return Stack(
      children: [
        // 왼쪽
        if (left > 0)
          Positioned(
            left: 0,
            top: 0,
            width: left,
            height: displayHeight,
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
        // 오른쪽
        if (left + width < displayWidth)
          Positioned(
            left: left + width,
            top: 0,
            width: displayWidth - (left + width),
            height: displayHeight,
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
        // 위쪽
        if (top > 0)
          Positioned(
            left: left,
            top: 0,
            width: width,
            height: top,
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
        // 아래쪽
        if (top + height < displayHeight)
          Positioned(
            left: left,
            top: top + height,
            width: width,
            height: displayHeight - (top + height),
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
      ],
    );
  }

  // 크롭 영역 테두리
  Widget _buildCropBorder() {
    if (_cropRect == null) return const SizedBox.shrink();

    return Positioned(
      left: _cropRect!.left * _scale,
      top: _cropRect!.top * _scale,
      width: _cropRect!.width * _scale,
      height: _cropRect!.height * _scale,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue, width: 2),
        ),
        child: CustomPaint(painter: GridPainter()),
      ),
    );
  }

  List<Widget> _buildHandles() {
    if (_cropRect == null) return [];

    final handles = <Widget>[];
    const handleSize = 20.0;

    final left = _cropRect!.left * _scale;
    final top = _cropRect!.top * _scale;
    final width = _cropRect!.width * _scale;
    final height = _cropRect!.height * _scale;

    // 모서리 핸들 (8개 방향)
    final positions = [
      {'x': left, 'y': top, 'cursor': SystemMouseCursors.resizeUpLeft},
      {'x': left + width / 2, 'y': top, 'cursor': SystemMouseCursors.resizeUp},
      {'x': left + width, 'y': top, 'cursor': SystemMouseCursors.resizeUpRight},
      {
        'x': left,
        'y': top + height / 2,
        'cursor': SystemMouseCursors.resizeLeft,
      },
      {
        'x': left + width,
        'y': top + height / 2,
        'cursor': SystemMouseCursors.resizeRight,
      },
      {
        'x': left,
        'y': top + height,
        'cursor': SystemMouseCursors.resizeDownLeft,
      },
      {
        'x': left + width / 2,
        'y': top + height,
        'cursor': SystemMouseCursors.resizeDown,
      },
      {
        'x': left + width,
        'y': top + height,
        'cursor': SystemMouseCursors.resizeDownRight,
      },
    ];

    for (final pos in positions) {
      handles.add(
        Positioned(
          left: (pos['x'] as double) - handleSize / 2,
          top: (pos['y'] as double) - handleSize / 2,
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: BoxDecoration(
              color: Colors.blue,
              border: Border.all(color: Colors.white, width: 2),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return handles;
  }

  void _onPanStart(DragStartDetails details) {
    if (_cropRect == null) return;

    final localX = details.localPosition.dx;
    final localY = details.localPosition.dy;

    final left = _cropRect!.left * _scale;
    final top = _cropRect!.top * _scale;
    final right = left + _cropRect!.width * _scale;
    final bottom = top + _cropRect!.height * _scale;

    const hitMargin = 15.0;

    _dragStart = details.localPosition;
    _dragStartRect = _cropRect; // 시작 시 크롭 영역 저장

    // 핸들 감지 (우선순위 순서)
    final isNearLeft = (localX - left).abs() <= hitMargin;
    final isNearRight = (localX - right).abs() <= hitMargin;
    final isNearTop = (localY - top).abs() <= hitMargin;
    final isNearBottom = (localY - bottom).abs() <= hitMargin;
    final isNearCenterX = (localX - (left + right) / 2).abs() <= hitMargin;
    final isNearCenterY = (localY - (top + bottom) / 2).abs() <= hitMargin;

    if (isNearLeft && isNearTop) {
      _dragMode = 'resize_tl';
    } else if (isNearRight && isNearTop) {
      _dragMode = 'resize_tr';
    } else if (isNearLeft && isNearBottom) {
      _dragMode = 'resize_bl';
    } else if (isNearRight && isNearBottom) {
      _dragMode = 'resize_br';
    } else if (isNearCenterX && isNearTop) {
      _dragMode = 'resize_t';
    } else if (isNearCenterX && isNearBottom) {
      _dragMode = 'resize_b';
    } else if (isNearLeft && isNearCenterY) {
      _dragMode = 'resize_l';
    } else if (isNearRight && isNearCenterY) {
      _dragMode = 'resize_r';
    } else if (localX >= left &&
        localX <= right &&
        localY >= top &&
        localY <= bottom) {
      _dragMode = 'move';
    } else {
      _dragMode = 'none';
    }

    debugPrint('🎯 드래그 모드: $_dragMode');
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_cropRect == null || _dragStart == null || _dragStartRect == null) {
      return;
    }

    final delta = details.localPosition - _dragStart!;
    final deltaX = delta.dx / _scale;
    final deltaY = delta.dy / _scale;

    final imageWidth = _image.width.toDouble();
    final imageHeight = _image.height.toDouble();
    const minSize = 50.0;

    setState(() {
      if (_dragMode == 'move') {
        // 이동
        final newLeft = (_dragStartRect!.left + deltaX).clamp(
          0.0,
          imageWidth - _dragStartRect!.width,
        );
        final newTop = (_dragStartRect!.top + deltaY).clamp(
          0.0,
          imageHeight - _dragStartRect!.height,
        );

        _cropRect = Rect.fromLTWH(
          newLeft,
          newTop,
          _dragStartRect!.width,
          _dragStartRect!.height,
        );
      } else if (_dragMode.startsWith('resize_')) {
        // 리사이즈
        double newLeft = _dragStartRect!.left;
        double newTop = _dragStartRect!.top;
        double newWidth = _dragStartRect!.width;
        double newHeight = _dragStartRect!.height;

        if (_dragMode.contains('l')) {
          // 왼쪽 가장자리
          newLeft = (_dragStartRect!.left + deltaX).clamp(0.0, imageWidth);
          newWidth = (_dragStartRect!.right - newLeft).clamp(
            minSize,
            imageWidth,
          );
          newLeft = _dragStartRect!.right - newWidth;
        }
        if (_dragMode.contains('r')) {
          // 오른쪽 가장자리
          newWidth = (_dragStartRect!.width + deltaX).clamp(
            minSize,
            imageWidth - _dragStartRect!.left,
          );
        }
        if (_dragMode.contains('t')) {
          // 위쪽 가장자리
          newTop = (_dragStartRect!.top + deltaY).clamp(0.0, imageHeight);
          newHeight = (_dragStartRect!.bottom - newTop).clamp(
            minSize,
            imageHeight,
          );
          newTop = _dragStartRect!.bottom - newHeight;
        }
        if (_dragMode.contains('b')) {
          // 아래쪽 가장자리
          newHeight = (_dragStartRect!.height + deltaY).clamp(
            minSize,
            imageHeight - _dragStartRect!.top,
          );
        }

        // 최종 검증
        newLeft = newLeft.clamp(0.0, imageWidth - minSize);
        newTop = newTop.clamp(0.0, imageHeight - minSize);
        newWidth = newWidth.clamp(minSize, imageWidth - newLeft);
        newHeight = newHeight.clamp(minSize, imageHeight - newTop);

        _cropRect = Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _dragStart = null;
    _dragStartRect = null;
    _dragMode = 'none';
    debugPrint('✅ 최종 크롭: $_cropRect');
  }
}

// 그리드 페인터 (3x3 가이드라인)
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    // 세로선
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );

    // 가로선
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
