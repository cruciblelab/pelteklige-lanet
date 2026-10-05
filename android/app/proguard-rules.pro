# ONNX Runtime'ın yerel (C++) kodu Java sınıflarına JNI ile İSİMLE erişir
# (FindClass / GetMethodID). R8 bu sınıfları silerse ya da adlarını
# değiştirirse model çalıştırılırken uygulama çöker:
#   "JNI DETECTED ERROR IN APPLICATION: java_class == null in call to GetMethodID"
# onnxruntime-android AAR'ı kendi kurallarını getirmediği için burada koruyoruz.
-keep class ai.onnxruntime.** { *; }
-keepclassmembers class ai.onnxruntime.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}
