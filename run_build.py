import os
import subprocess
from pathlib import Path

import modal


app = modal.App("flutter-build-apk")

# Persistent build caches.
cache_volume = modal.Volume.from_name(
    "flutter-build-cache",
    create_if_missing=True,
)

# APK output volume (survives container teardown).
output_volume = modal.Volume.from_name(
    "flutter-build-output",
    create_if_missing=True,
)

# Secrets:
#   KEYSTORE_BASE64
#   KEYSTORE_PASSWORD
#   KEY_ALIAS
#   KEY_PASSWORD
#   NIM_API_KEY
flutter_build_secret = modal.Secret.from_name("flutter-build")


image = (
    modal.Image.from_registry(
        "ubuntu:24.04",
        add_python="3.12",
    )
    .apt_install(
        "git",
        "curl",
        "unzip",
        "xz-utils",
        "zip",
        "ca-certificates",
        "gnupg",
        "libglu1-mesa",
    )
    # Eclipse Temurin 17
    .run_commands(
        "mkdir -p /etc/apt/keyrings",
        (
            "curl -fsSL "
            "https://packages.adoptium.net/artifactory/api/gpg/key/public "
            "| gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg"
        ),
        (
            "echo \"deb [signed-by=/etc/apt/keyrings/adoptium.gpg] "
            "https://packages.adoptium.net/artifactory/deb "
            "$(awk -F= '/^VERSION_CODENAME/{print $2}' /etc/os-release) main\" "
            "> /etc/apt/sources.list.d/adoptium.list"
        ),
        "apt-get update",
        "apt-get install -y temurin-17-jdk",
    )
    # Flutter stable
    .run_commands(
        "git clone --depth 1 --branch stable "
        "https://github.com/flutter/flutter.git /opt/flutter",
        "/opt/flutter/bin/flutter config --no-analytics",
        "/opt/flutter/bin/flutter precache --android",
    )
    .env(
        {
            "PATH": (
                "/opt/flutter/bin:"
                "/opt/flutter/bin/cache/dart-sdk/bin:"
                "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            ),
            "JAVA_HOME": "/usr/lib/jvm/temurin-17-jdk-amd64",
            "ANDROID_HOME": "/opt/android-sdk",
            "ANDROID_SDK_ROOT": "/opt/android-sdk",
            "PUB_CACHE": "/cache/pub",
            "GRADLE_USER_HOME": "/cache/gradle",
        }
    )
    # Android SDK (cmdline-tools + platform-tools + platform 36 + build-tools 36)
    .run_commands(
        "mkdir -p /opt/android-sdk/cmdline-tools",
        "curl -fsSL -o /tmp/cmdtools.zip "
        "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip",
        "unzip -q /tmp/cmdtools.zip -d /opt/android-sdk/cmdline-tools",
        "mv /opt/android-sdk/cmdline-tools/cmdline-tools /opt/android-sdk/cmdline-tools/latest",
        "yes | /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses",
        "/opt/android-sdk/cmdline-tools/latest/bin/sdkmanager "
        "\"platform-tools\" \"platforms;android-36\" \"build-tools;36.0.0\"",
        "chmod -R a+rX /opt/android-sdk",
    )
)


def run(*args, cwd=None, env=None, check=True):
    print("+", " ".join(str(x) for x in args), flush=True)

    subprocess.run(
        list(map(str, args)),
        cwd=cwd,
        env=env,
        check=check,
    )


@app.function(
    image=image,
    secrets=[flutter_build_secret],
    volumes={"/cache": cache_volume, "/output": output_volume},
    cpu=4,
    memory=8 * 1024,
    timeout=60 * 60,
)
def build_apk(
    build_number: str,
    commit_hash: str,
    repo_url: str = "https://github.com/ThongAccount/eye_care_ai.git",
    branch: str = "main",
    project_dir: str = "/workspace",
):
    import base64

    print("=" * 70)
    print("MODAL FLUTTER APK BUILD")
    print("=" * 70)
    print(f"Repo : {repo_url}")
    print(f"Branch: {branch}")
    print(f"Build : {build_number}")
    print(f"Commit: {commit_hash}")

    # ------------------------------------------------------------------
    # Clone repo (fresh checkout; nothing sensitive leaves the machine)
    # ------------------------------------------------------------------

    project = Path(project_dir)
    if project.exists():
        run("rm", "-rf", str(project))
    run("git", "clone", "--depth", "1", "--branch", branch, repo_url, str(project))

    if not (project / "pubspec.yaml").exists():
        raise RuntimeError(f"{project}/pubspec.yaml not found after clone")

    os.chdir(project)

    # ------------------------------------------------------------------
    # Environment
    # ------------------------------------------------------------------

    run("java", "-version")
    run("flutter", "--version")
    run("flutter", "doctor", "-v")

    # ------------------------------------------------------------------
    # Equivalent to actions/cache
    # ------------------------------------------------------------------

    print("\n--- Persistent caches ---")
    print("PUB_CACHE =", os.environ["PUB_CACHE"])
    print("GRADLE_USER_HOME =", os.environ["GRADLE_USER_HOME"])

    # ------------------------------------------------------------------
    # Install dependencies
    # ------------------------------------------------------------------

    print("\n--- Flutter dependencies ---")
    run("flutter", "pub", "get")

    # ------------------------------------------------------------------
    # Clean stale build state
    # ------------------------------------------------------------------

    print("\n--- Cleaning stale build state ---")
    run("flutter", "clean")

    gradlew = project / "android" / "gradlew"

    if gradlew.exists():
        gradlew.chmod(gradlew.stat().st_mode | 0o111)
        run(str(gradlew), "--stop", check=False)

    # ------------------------------------------------------------------
    # Release signing
    # ------------------------------------------------------------------

    keystore_b64 = os.environ.get("KEYSTORE_BASE64")

    if keystore_b64:
        print("\n--- Configuring release signing ---")

        keystore = project / "android" / "app" / "release-keystore.jks"
        key_properties = project / "android" / "key.properties"

        keystore.write_bytes(
            __import__("base64").b64decode(keystore_b64)
        )

        key_properties.write_text(
            "storeFile=release-keystore.jks\n"
            f"storePassword={os.environ['KEYSTORE_PASSWORD']}\n"
            f"keyAlias={os.environ['KEY_ALIAS']}\n"
            f"keyPassword={os.environ['KEY_PASSWORD']}\n"
        )

        print("Release signing configured.")
    else:
        print("\n--- No keystore secret; using unsigned/default release ---")

    # ------------------------------------------------------------------
    # Version
    # ------------------------------------------------------------------

    version = "unknown"

    for line in (project / "pubspec.yaml").read_text().splitlines():
        if line.startswith("version:"):
            version = line.split(":", 1)[1].strip()
            break

    print("Version:", version)
    print("Build number:", build_number)
    print("Commit:", commit_hash)

    # ------------------------------------------------------------------
    # Flutter release build
    # Equivalent to:
    #
    # flutter build apk --release
    #   --build-number=${{ github.run_number }}
    #   --dart-define=NIM_API_KEY=${{ secrets.NIM_API_KEY }}
    #   --dart-define=COMMIT_HASH=${{ github.sha }}
    # ------------------------------------------------------------------

    print("\n--- Building release APK ---")

    NIM_API_KEY = os.environ.get('NIM_API_KEY', '')
    if not NIM_API_KEY.startswith("nvapi-"):
        print("WARNING: Invalid NVIDIA NIM API key. Chat features will be unavailable.")

    run(
        "flutter",
        "build",
        "apk",
        "--release",
        f"--build-number={build_number}",
        f"--dart-define=NIM_API_KEY={NIM_API_KEY}",
        f"--dart-define=COMMIT_HASH={commit_hash}",
    )

    # ------------------------------------------------------------------
    # Rename APK
    # ------------------------------------------------------------------

    apk = (
        project
        / "build"
        / "app"
        / "outputs"
        / "flutter-apk"
        / "app-release.apk"
    )

    if not apk.exists():
        raise RuntimeError(f"APK was not produced: {apk}")

    release_dir = project / "release"
    release_dir.mkdir(exist_ok=True)

    short_sha = commit_hash[:8]

    output_name = (
        f"eye_care_ai-{version}-{short_sha}"
        f"-build{build_number}.apk"
    )

    output = release_dir / output_name
    output.write_bytes(apk.read_bytes())

    # Persist APK on the output volume so it survives container teardown.
    out_volume_path = Path("/output") / output.name
    out_volume_path.write_bytes(output.read_bytes())
    print("Copied APK to output volume:", out_volume_path)

    print("\n" + "=" * 70)
    print("BUILD SUCCESSFUL")
    print("=" * 70)
    print("APK:", output)
    print("Size:", round(output.stat().st_size / 1024 / 1024, 2), "MiB")


@app.local_entrypoint()
def main(
    build_number: str,
    commit_hash: str,
    branch: str = "main",
    repo_url: str = "https://github.com/ThongAccount/eye_care_ai.git",
):
    """
    Build eye_care_ai exclusively on Modal.

    Example:

        modal run run_build.py \
          --build-number 42 \
          --commit-hash "$(git rev-parse HEAD)" \
          --branch feat/app-lock

    The repo is cloned from GitHub on the Modal side — nothing local
    is uploaded. Uses the secret 'flutter-build' (KEYSTORE_BASE64,
    KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD, NIM_API_KEY) and the
    volume 'flutter-build-cache' (created on first run).
    """

    print("=" * 70)
    print("Submitting Flutter build to Modal")
    print("=" * 70)
    print(f"Repo : {repo_url}")
    print(f"Branch: {branch}")
    print(f"Build : {build_number}")
    print(f"Commit: {commit_hash}")

    build_apk.remote(
        build_number=build_number,
        commit_hash=commit_hash,
        repo_url=repo_url,
        branch=branch,
    )
