# Android Studio's bundled JDK, and the SDK it installs.
if test -d /opt/android-studio/jbr
    set -gx JAVA_HOME /opt/android-studio/jbr
end

if test -d ~/Android/Sdk
    set -gx ANDROID_HOME ~/Android/Sdk
    set -gx ANDROID_AVD_HOME ~/.config/.android/avd
    # fish sorts globs with numbers in natural order, so the last is the newest
    # NDK. `set` allows a glob that matches nothing.
    set -l ndks $ANDROID_HOME/ndk/*/
    if set -q ndks[1]
        set -gx NDK_HOME (path normalize $ndks[-1])
    end
    if test -d $ANDROID_HOME/platform-tools
        fish_add_path -g $ANDROID_HOME/platform-tools
    end
end
