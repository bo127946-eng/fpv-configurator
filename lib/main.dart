Run flutter build apk --release

Running Gradle task 'assembleRelease'...                        
Warning: This version only understands SDK XML versions up to 3 but an SDK XML file of version 4 was encountered. This can happen if you use versions of Android Studio and the command-line tools that were released at different times.
Checking the license for package Android SDK Build-Tools 30.0.3 in /usr/local/lib/android/sdk/licenses
License for package Android SDK Build-Tools 30.0.3 accepted.
Preparing "Install Android SDK Build-Tools 30.0.3 (revision: 30.0.3)".
"Install Android SDK Build-Tools 30.0.3 (revision: 30.0.3)" ready.
Installing Android SDK Build-Tools 30.0.3 in /usr/local/lib/android/sdk/build-tools/30.0.3
"Install Android SDK Build-Tools 30.0.3 (revision: 30.0.3)" complete.
"Install Android SDK Build-Tools 30.0.3 (revision: 30.0.3)" finished.
Checking the license for package Android SDK Platform 29 in /usr/local/lib/android/sdk/licenses
License for package Android SDK Platform 29 accepted.
Preparing "Install Android SDK Platform 29 (revision: 5)".
"Install Android SDK Platform 29 (revision: 5)" ready.
Installing Android SDK Platform 29 in /usr/local/lib/android/sdk/platforms/android-29
"Install Android SDK Platform 29 (revision: 5)" complete.
"Install Android SDK Platform 29 (revision: 5)" finished.
lib/main.dart:145:54: Error: Member not found: 'between'.
                mainAxisAlignment: MainAxisAlignment.between,
                                                     ^^^^^^^
Target kernel_snapshot failed: Exception


FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:compileFlutterBuildRelease'.
> Process 'command '/opt/hostedtoolcache/flutter/stable-3.22.3-x64/flutter/bin/flutter'' finished with non-zero exit value 1

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights.

* Get more help at https://help.gradle.org

BUILD FAILED in 1m 32s
Running Gradle task 'assembleRelease'...                           93.5s
Gradle task assembleRelease failed with exit code 1
