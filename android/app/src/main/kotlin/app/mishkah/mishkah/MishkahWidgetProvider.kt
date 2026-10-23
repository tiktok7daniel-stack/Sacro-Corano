package app.mishkah.mishkah

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing the verse of the day and today's prayer times.
 * The Flutter side (lib/services/home_widget_sync.dart) writes the values
 * into the shared preferences read here; no network access is involved.
 */
class MishkahWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val arabic = widgetData.getString("lang", "ar") == "ar"
        val names = if (arabic) {
            listOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")
        } else {
            listOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")
        }
        val keys = listOf("fajr", "dhuhr", "asr", "maghrib", "isha")
        val next = widgetData.getString("next_name", null)

        val launch = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.mishkah_widget)
            views.setTextViewText(R.id.widget_verse, widgetData.getString("verse_text", "") ?: "")
            views.setTextViewText(R.id.widget_ref, widgetData.getString("verse_ref", "") ?: "")
            val times = keys.mapIndexed { i, k ->
                val t = widgetData.getString("time_$k", "--:--")
                if (k == next) "● ${names[i]} $t" else "${names[i]} $t"
            }
            views.setTextViewText(R.id.widget_times, times.joinToString("   "))
            views.setOnClickPendingIntent(R.id.widget_root, launch)
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
