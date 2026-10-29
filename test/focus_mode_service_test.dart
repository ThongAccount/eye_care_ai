import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eye_care_ai/services/focus_mode_service.dart';

/// Test cho việc CACHE quyền DND (PLAN.md § D).
///
/// `eye_care_ai/focus_mode` chỉ có handler native ở Android
/// (FocusModeHandler.kt) — ở test ta mock kênh này để kiểm tra hành vi cache
/// mà không cần máy thật.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('eye_care_ai/focus_mode');
  final calls = <MethodCall>[];

  /// native trả về giá trị này cho method 'hasAccess'.
  var nativeGranted = true;

  /// method 'enable' trả về giá trị này.
  var nativeEnableResult = true;

  /// method 'enable' NÉM LỖI thay vì trả lời (native crash / channel hỏng).
  var nativeEnableThrows = false;

  void installChannel() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'hasAccess':
          return nativeGranted;
        case 'enable':
          if (nativeEnableThrows) {
            // Lỗi thật, không phải "bị từ chối" — kênh mất trả lời.
            throw StateError('native enable crashed');
          }
          return nativeEnableResult;
        default:
          return null;
      }
    });
  }

  int countCalls(String method) =>
      calls.where((c) => c.method == method).length;

  setUp(() {
    calls.clear();
    nativeGranted = true;
    nativeEnableResult = true;
    nativeEnableThrows = false;
    SharedPreferences.setMockInitialValues({});
    installChannel();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('a granted state is cached — the native side is asked only once',
      () async {
    expect(await FocusModeService.instance.hasAccess(), isTrue);
    expect(await FocusModeService.instance.hasAccess(), isTrue);

    expect(countCalls('hasAccess'), 1);
  });

  test('the cached grant survives a failing native call', () async {
    expect(await FocusModeService.instance.hasAccess(), isTrue);

    // Native hỏng (channel không còn trả lời) — quyền đã cấp vẫn phải giữ.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    expect(await FocusModeService.instance.hasAccess(), isTrue);
    expect(countCalls('hasAccess'), 1);
  });

  test('enable() returning false clears the cached grant', () async {
    expect(await FocusModeService.instance.hasAccess(), isTrue);

    // Người dùng tự thu hồi quyền ở Cài đặt hệ thống -> native từ chối.
    nativeEnableResult = false;
    expect(await FocusModeService.instance.enable(), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(FocusModeService.dndGrantedPrefKey), isFalse);

    // Lần hỏi sau phải hỏi lại native và báo đúng sự thật.
    nativeGranted = false;
    expect(await FocusModeService.instance.hasAccess(), isFalse);
    expect(countCalls('hasAccess'), 2);
  });

  // Chỉ khi native trả lời CHẮC CHẮN "không" (false) thì cache mới bị xoá.
  // Lỗi kênh / native crash KHÔNG phải từ chối — xoá cache ở đây sẽ làm
  // banner "cấp quyền DND" hiện lại dù người dùng đã cấp.
  test('enable() THROWING does not clear the cached grant', () async {
    expect(await FocusModeService.instance.hasAccess(), isTrue);

    nativeEnableThrows = true;
    expect(await FocusModeService.instance.enable(), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(FocusModeService.dndGrantedPrefKey), isTrue);

    // Lần hỏi sau vẫn báo true VÀ không hỏi lại native nữa.
    expect(await FocusModeService.instance.hasAccess(), isTrue);
    expect(countCalls('hasAccess'), 1);
  });

  test('the grant is persisted, so it survives an app restart', () async {
    expect(await FocusModeService.instance.hasAccess(), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(FocusModeService.dndGrantedPrefKey), isTrue);

    // App restart: kênh native không trả lời nữa, nhưng quyền đã cấp vẫn
    // được nhớ -> banner "cấp quyền DND" không hiện lại.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    expect(await FocusModeService.instance.hasAccess(), isTrue);
  });
}
