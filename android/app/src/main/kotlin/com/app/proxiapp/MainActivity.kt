package com.app.proxiapp

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    /// Geolocator’s foreground notification uses PendingIntent to bring the task forward.
    /// With [launchMode] singleTop, the existing activity must take the new intent or the
    /// Flutter surface can fail to attach (black screen).
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
