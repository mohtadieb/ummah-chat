# --- Keep uCrop BitmapLoadTask (image_cropper / uCrop) ---
-keep class com.yalantis.ucrop.task.BitmapLoadTask {
    *;
}

# --- Ignore optional TLS providers used by OkHttp ---
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
