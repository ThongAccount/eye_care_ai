import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Đo khoảng cách MẮT -> MÀN HÌNH bằng camera trước, dùng cho bài kiểm tra
/// thị lực (thay lời nhắc tĩnh "giữ cách 40cm" bằng số đo THẬT theo thời
/// gian thực).
///
/// CÁCH TÍNH (không cần hiệu chỉnh riêng từng máy):
///   1. ML Kit tìm khuôn mặt + 2 điểm mốc MẮT TRÁI/MẮT PHẢI trên khung hình.
///   2. Khoảng cách 2 mắt tính bằng PIXEL trên ảnh, so với khoảng cách 2
///      đồng tử TRUNG BÌNH của người trưởng thành (~6.3cm, số liệu nhân
///      trắc học phổ biến) để suy ra khoảng cách thật bằng công thức tam
///      giác đồng dạng:
///         khoảng_cách_cm = (6.3cm × tiêu_cự_px) / khoảng_cách_2_mắt_px
///   3. `tiêu_cự_px` ước lượng từ độ rộng ảnh + góc nhìn (FOV) ngang giả
///      định ~70° — thông số phổ biến của camera trước điện thoại, KHÔNG
///      đọc được chính xác tuyệt đối qua Flutter cho mọi máy.
///
/// BUG ĐÃ SỬA ("Face not detected" dù mặt rõ ràng trong khung hình): trước
/// đây dùng `FaceDetectorMode.fast` + BẮT BUỘC phải có đủ landmark mắt trái
/// VÀ mắt phải mới tính — nhưng ở chế độ `fast`, ML Kit ưu tiên tốc độ nên
/// landmark mắt RẤT HAY bị null dù bounding box khuôn mặt vẫn nhận diện
/// đúng (đặc biệt khi đầu hơi nghiêng hoặc ánh sáng không lý tưởng), khiến
/// app báo "không thấy mặt" liên tục dù mặt rõ ràng đang trong khung hình.
/// Giờ đổi sang `FaceDetectorMode.accurate` (đánh đổi chậm hơn 1 chút để
/// đổi lấy landmark ổn định hơn nhiều) VÀ thêm phương án DỰ PHÒNG: nếu vẫn
/// thiếu landmark mắt, dùng luôn ĐỘ RỘNG KHUÔN MẶT (bounding box) so với độ
/// rộng khuôn mặt trung bình (~14cm) để ước lượng khoảng cách — kém chính
/// xác hơn dùng khoảng cách 2 mắt một chút, nhưng vẫn tốt hơn nhiều so với
/// báo "không phát hiện được" khi thực ra đã thấy mặt.
///
/// GIỚI HẠN THỰC TẾ CẦN BIẾT: đây là ước lượng dựa trên số đo trung bình
/// dân số + giả định góc nhìn camera — sai số thực tế có thể dao động
/// ±15-20% tùy khuôn mặt người dùng và đời máy cụ thể. Đủ dùng để phân biệt
/// "quá gần / vừa / quá xa" (mục đích chính: nhắc giữ khoảng cách ỔN ĐỊNH
/// giữa các lần đo, không phải đo milimet chính xác tuyệt đối).
class DistanceService {
  DistanceService._();
  static final instance = DistanceService._();

  static const double _kInterpupillaryDistanceCm = 6.3;
  static const double _kAverageFaceWidthCm = 14.0;
  static const double _kAssumedHorizontalFovDegrees = 70;

  CameraController? _controller;
  FaceDetector? _faceDetector;
  bool _busy = false;
  bool _disposed = false;

  final _distanceController = StreamController<double?>.broadcast();

  /// Stream khoảng cách ước lượng (cm), null = hiện không thấy khuôn mặt rõ
  /// ràng (quá tối, ra khỏi khung hình, camera chưa sẵn sàng...).
  Stream<double?> get distanceStream => _distanceController.stream;

  bool get isRunning => _controller != null && (_controller?.value.isStreamingImages ?? false);

  Future<bool> isCameraAvailable() async {
    try {
      final cameras = await availableCameras();
      return cameras.any((c) => c.lensDirection == CameraLensDirection.front);
    } catch (_) {
      return false;
    }
  }

  Future<bool> start() async {
    if (isRunning) return true;
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        front,
        ResolutionPreset.low, // đủ dùng để tìm mốc mắt, không cần ảnh nét cao -> đỡ tốn pin/CPU
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await _controller!.initialize();

      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          // Chậm hơn "fast" một chút nhưng landmark mắt ổn định hơn HẲN —
          // xem giải thích chi tiết ở doc comment class phía trên.
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      _disposed = false;
      await _controller!.startImageStream(_onFrame);
      return true;
    } catch (_) {
      await stop();
      return false;
    }
  }

  Future<void> stop() async {
    _disposed = true;
    try {
      if (_controller?.value.isStreamingImages ?? false) {
        await _controller?.stopImageStream();
      }
    } catch (_) {}
    await _controller?.dispose();
    _controller = null;
    await _faceDetector?.close();
    _faceDetector = null;
  }

  void _onFrame(CameraImage image) async {
    if (_busy || _disposed || _faceDetector == null || _controller == null) return;
    _busy = true;
    try {
      final inputImage = _toInputImage(image, _controller!.description);
      if (inputImage == null) {
        _distanceController.add(null);
        return;
      }
      final faces = await _faceDetector!.processImage(inputImage);
      if (faces.isEmpty) {
        _distanceController.add(null);
        return;
      }
      final face = faces.first;
      final imageWidthPx = image.width.toDouble();
      final fovRad = _kAssumedHorizontalFovDegrees * math.pi / 180;
      final focalLengthPx = (imageWidthPx / 2) / math.tan(fovRad / 2);

      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];

      double? distanceCm;
      if (leftEye != null && rightEye != null) {
        // Cách chính, chính xác hơn: dựa trên khoảng cách 2 mắt.
        final dx = (leftEye.position.x - rightEye.position.x).toDouble();
        final dy = (leftEye.position.y - rightEye.position.y).toDouble();
        final eyeDistancePx = math.sqrt(dx * dx + dy * dy);
        if (eyeDistancePx >= 1) {
          distanceCm = (_kInterpupillaryDistanceCm * focalLengthPx) / eyeDistancePx;
        }
      }
      if (distanceCm == null) {
        // Dự phòng: đã thấy khuôn mặt (bounding box) nhưng thiếu landmark
        // mắt -> ước lượng bằng độ rộng khuôn mặt thay vì báo "không thấy".
        final faceWidthPx = face.boundingBox.width;
        if (faceWidthPx >= 1) {
          distanceCm = (_kAverageFaceWidthCm * focalLengthPx) / faceWidthPx;
        }
      }

      if (distanceCm == null) {
        _distanceController.add(null);
        return;
      }
      // Giới hạn khoảng hợp lý (10cm-150cm) — ngoài khoảng này gần như chắc
      // chắn là nhiễu/đo sai, không phải người dùng thật sự đứng xa/gần vậy.
      if (distanceCm < 10 || distanceCm > 150) {
        _distanceController.add(null);
        return;
      }
      _distanceController.add(distanceCm);
    } catch (_) {
      _distanceController.add(null);
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription description) {
    try {
      final rotation = InputImageRotationValue.fromRawValue(description.sensorOrientation) ??
          InputImageRotation.rotation0deg;

      // NV21 (Android) chỉ có 1 plane khi dùng imageFormatGroup: nv21.
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}