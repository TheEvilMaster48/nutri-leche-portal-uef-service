package com.example.nutri

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (y no FlutterActivity) porque hereda de
// ComponentActivity, que es lo que pide `enableEdgeToEdge()`.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Borde a borde también en Android < 15, donde el sistema no lo impone.
        // Play Console lo pide así ("es posible que la pantalla de borde a borde
        // no se muestre para todos los usuarios"); la llamada de Dart
        // `SystemChrome.setEnabledSystemUIMode` no cuenta para esa revisión.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
