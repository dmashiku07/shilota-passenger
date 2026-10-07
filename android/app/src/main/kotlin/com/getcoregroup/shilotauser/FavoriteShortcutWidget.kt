package com.getcoregroup.shilotauser

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.preference.PreferenceManager
import android.widget.RemoteViews

class FavoriteShortcutWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_favorite_shortcuts)
            val prefs = PreferenceManager.getDefaultSharedPreferences(context)
            val homeLabel = prefs.getString("widget_home_label", "Home")
            val workLabel = prefs.getString("widget_work_label", "Work")
            views.setTextViewText(R.id.widgetGoHome, homeLabel)
            views.setTextViewText(R.id.widgetGoWork, workLabel)
            views.setOnClickPendingIntent(
                R.id.widgetGoHome,
                shortcutIntent(context, "home", 10),
            )
            views.setOnClickPendingIntent(
                R.id.widgetGoWork,
                shortcutIntent(context, "work", 11),
            )
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    companion object {
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, FavoriteShortcutWidget::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids != null && ids.isNotEmpty()) {
                FavoriteShortcutWidget().onUpdate(context, manager, ids)
            }
        }
    }

    private fun shortcutIntent(
        context: Context,
        shortcut: String,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("shilota://app/home?shortcut=$shortcut"),
            context,
            MainActivity::class.java,
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getActivity(context, requestCode, intent, flags)
    }
}
