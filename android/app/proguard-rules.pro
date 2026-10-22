# shared_preferences_android 2.5 calls its Kotlin API from Dart through JNI, which R8 cannot
# see, and ships no rule to keep it: without this the release app stops before its first frame
# (NoSuchMethodError on SharedPreferencesApiRegistrar.getAll).
-keep class io.flutter.plugins.sharedpreferences.** { *; }
# The JNI lookups name the method by its full signature, so the types in it keep their names.
-keep class kotlin.coroutines.Continuation { *; }
