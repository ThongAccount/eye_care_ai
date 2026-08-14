import java.util.Properties
import java.io.FileInputStream



plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Đọc cấu hình ký release từ android/key.properties (không commit file này lên
// git — trên CI, workflow sẽ tự tạo file này từ GitHub Secrets trước khi
// build). Nếu file không tồn tại (build local chưa cấu hình, hoặc chủ repo
// chưa thêm 4 secret KEYSTORE_BASE64/KEYSTORE_PASSWORD/KEY_ALIAS/KEY_PASSWORD
// trên GitHub), app vẫn build được nhờ ci-fallback-keystore.jks bên dưới.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// FIX "Chưa cài đặt được ứng dụng do gói xung đột với một gói hiện có":
// trước đây khi KHÔNG có key.properties, bản release rơi về dùng
// debug.keystore MẶC ĐỊNH CỦA MÁY (~/.android/debug.keystore). Trên GitHub
// Actions, mỗi lần chạy workflow là một máy ảo HOÀN TOÀN MỚI — file
// debug.keystore đó KHÔNG tồn tại sẵn nên plugin Android tự sinh ra 1 file
// MỚI, KHÁC NHAU ở MỖI LẦN BUILD. Kết quả: build 53 và build 54 có 2 chữ ký
// khác nhau -> Android coi đây là 2 app khác nhau dùng chung package name,
// từ chối cài đè ("package conflicts with an existing package") — đây CHÍNH
// LÀ lỗi trong ảnh chụp màn hình, và nó sẽ LUÔN xảy ra ở MỌI lần cập nhật
// tiếp theo cho tới khi được sửa, không phải lỗi ngẫu nhiên 1 lần.
//
// Giải pháp: dùng 1 file keystore CỐ ĐỊNH, COMMIT THẲNG vào repo, làm phương
// án dự phòng khi chưa cấu hình key.properties thật. File này KHÔNG bí mật gì
// (mục đích chỉ là "chữ ký ổn định giữa các lần build", không phải để bảo vệ
// danh tính lên Play Store — giống hệt tinh thần debug.keystore mặc định của
// Android vốn cũng không phải bí mật) — nhờ vậy MỌI bản release (kể cả khi
// chủ repo chưa từng thêm 4 GitHub Secret ở trên) đều dùng chung 1 chữ ký ổn
// định, cập nhật đè lên nhau bình thường. Muốn phát hành THẬT lên Play
// Store/production, vẫn nên tự tạo keystore RIÊNG và cấu hình 4 secret đó —
// key.properties (nếu có) LUÔN được ưu tiên hơn file dự phòng này.
val ciFallbackKeystoreFile = file("ci-fallback-keystore.jks")
val hasCiFallbackSigning = ciFallbackKeystoreFile.exists()
val ciFallbackAlias = "eyecare_ci_fallback"
val ciFallbackPassword = "eyecare_ci_fallback"

android {
    namespace = "com.eyecare.eye_care_ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.eyecare.eye_care_ai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // health plugin (HealthKit/Health Connect) requires minSdk 26+;
        // flutter.minSdkVersion mặc định thấp hơn nên phải ghi đè ở đây.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        } else if (hasCiFallbackSigning) {
            create("ciFallback") {
                keyAlias = ciFallbackAlias
                keyPassword = ciFallbackPassword
                storeFile = ciFallbackKeystoreFile
                storePassword = ciFallbackPassword
            }
        }
    }

    buildTypes {
        release {
            // Thứ tự ưu tiên: key release THẬT (key.properties, nếu chủ repo
            // đã cấu hình 4 GitHub Secret) > keystore dự phòng CỐ ĐỊNH commit
            // sẵn trong repo (đảm bảo mọi bản release vẫn cùng 1 chữ ký, cập
            // nhật đè lên nhau được) > debug key mặc định của máy (chỉ còn
            // xảy ra nếu ai đó lỡ xoá luôn file ci-fallback-keystore.jks).
            signingConfig = when {
                hasReleaseSigning -> signingConfigs.getByName("release")
                hasCiFallbackSigning -> signingConfigs.getByName("ciFallback")
                else -> signingConfigs.getByName("debug")
            }
        }
    }
    
}

dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
