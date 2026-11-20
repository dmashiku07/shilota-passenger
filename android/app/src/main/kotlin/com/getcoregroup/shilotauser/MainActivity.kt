package com.getcoregroup.shilotauser

import android.preference.PreferenceManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "shilota/widget_shortcuts",
        ).setMethodCallHandler { call, result ->
            if (call.method == "syncSavedPlaces") {
                val homeLabel = call.argument<String>("homeLabel") ?: "Home"
                val workLabel = call.argument<String>("workLabel") ?: "Work"
                val prefs = PreferenceManager.getDefaultSharedPreferences(this)
                prefs.edit()
                    .putString("widget_home_label", homeLabel)
                    .putString("widget_work_label", workLabel)
                    .apply()
                FavoriteShortcutWidget.refreshAll(this)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "shilota/app_config",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getGeoapifyApiKey") {
                result.success(BuildConfig.GEOAPIFY_API_KEY.trim())
            } else {
                result.notImplemented()
            }
        }
    }
}
