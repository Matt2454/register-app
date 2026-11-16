# Android release verification — 16 November 2026

Release: Register 8.3.0 (51), application ID
`app.register.personal.r9457c4543606d986`.

- Android release APK built successfully from commit
  `07215eb` with Flutter 3.47.5, JDK 21, Android Gradle Plugin 9.1.0,
  compile/target SDK 36 and minimum SDK 24 (Android 7.0).
- Universal APK contains ARMv7, ARM64 and x86-64 AOT application/engine libraries.
  It contains no debug kernel or integration-test native plugin and is not
  marked debuggable.
- Native 64-bit ELF load segments and uncompressed APK library offsets meet
  16 KB alignment requirements, including after local signing.
- APK signed locally with the private RSA-3072 release key. APK signature
  schemes v2 and v3 verified successfully. No private keys/passwords are in
  the source repository, cloud artifact, APK, or public source archive.
- Linux CI: 89 Flutter tests passed; 4 tests for unsupported host notification/
  Mac widget behavior were skipped. The complete Mac-hosted suite previously
  passed all 93 cases.
- A test-signed copy of the same compiled release APK installed and launched
  on a disposable Android 15/API 35 x86-64 emulator. English, Italian and German
  switching, a force-stop/relaunch with German retained, and switching back to
  English passed. The permanent local release signature was checked separately.
- Physical Android hardware, real-account delivery of background notifications,
  and Google Play publication were not tested/performed.

Build: https://github.com/Matt2454/register-app/actions/runs/43844817230

Successful emulator check:
https://github.com/Matt2454/register-app/actions/runs/43894270781

APK SHA-256:
`47bc5877ab454cef3d053774abf4c8720c5cb38fb036ff087007a232755ecd9d`

Signing certificate SHA-256:
`f292fb3b935c035611888145478f6949cc8f9cb2db45536dc96643d57f18c37d`

The private signing backup is delivered separately for future updates. Keep it
private and preserve it when moving or deleting the development workspace.
