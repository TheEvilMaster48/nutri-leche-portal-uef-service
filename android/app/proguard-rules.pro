# Reglas de R8 para el build release (isMinifyEnabled = true).
# Flutter y la mayoría de plugins traen sus propias reglas (consumer rules);
# aquí solo va lo que no las trae.

# flutter_local_notifications: guarda las notificaciones programadas
# (zonedSchedule, recordatorio de eventos) serializadas con Gson. Sin esto R8
# renombra los campos y al reiniciar el teléfono no se pueden restaurar.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-dontwarn com.google.gson.**

# media_kit: se comunica con libmpv por JNI.
-keep class com.alexmercerind.** { *; }

# Play Core (referenciado por el embedding de Flutter para deferred
# components, que la app no usa).
-dontwarn com.google.android.play.core.**
