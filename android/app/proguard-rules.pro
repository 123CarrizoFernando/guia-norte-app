# Reglas base de Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Evitar que R8 falle por clases opcionales faltantes en librerías de terceros
-ignorewarnings
-dontwarn **

# Proteger Image Cropper (UCrop) y OkHttp
-keep class com.yalantis.ucrop** { *; }
-keep interface com.yalantis.ucrop** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Proteger Video Player (ExoPlayer / Media3)
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }

# Proteger Firebase y Google Play Services
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }