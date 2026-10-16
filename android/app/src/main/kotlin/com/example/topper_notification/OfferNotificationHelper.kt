package com.example.topper_notification

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

object OfferNotificationHelper {
    private const val TAG = "ToppersWisdomNotif"
    const val CHANNEL_ID = "toppers_wisdom_offers"
    const val NOTIFICATION_ID = 7312

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var tickRunnable: Runnable? = null

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Toppers Wisdom Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Toppers Wisdom offers and notifications"
                enableVibration(true)
            }
            context.getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    fun cancel(context: Context) {
        stopCountdown()
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    fun show(context: Context, data: Map<String, String>) {
        val ctx = context.applicationContext
        createChannel(ctx)
        stopCountdown()

        // type == "book" -> book layout, baaki sab -> offer layout
        val type = data["type"]?.trim()?.lowercase().takeUnless { it.isNullOrEmpty() } ?: "other"
        val brand = data["brand"] ?: "Toppers Wisdom"
        val title = data["title"]?.takeIf { it.isNotBlank() } ?: "Special offer just for you!"
        val body = data["body"]?.takeIf { it.isNotBlank() } ?: "Avail the offer NOW!"
        val logo = data["logoText"] ?: "T"
        val imageUrl = (data["imageUrl"] ?: data["image"] ?: data["banner"])?.trim().orEmpty()
        val price = data["price"] ?: "250"
        val buttonText = data["buttonText"] ?: "SHOP"
        val subtitle = data["subtitle"] ?: body

        val expiryMillis = parseExpiryTime(
            data["expiresAt"] ?: data["countdownEnd"] ?:"2026-10-17T14:01:00.000Z"
//            data["expiryTime"]
        )

        Log.d(TAG, "show type=$type expiryMillis=$expiryMillis")

        // FCM service background thread par chalti hai, to yahan download theek hai
        val bitmap = downloadImage(imageUrl)

        val rv: RemoteViews
        var timerRunning = false

        if (type == "book") {
            rv = RemoteViews(ctx.packageName, R.layout.custom_book_notification)
            rv.setTextViewText(R.id.book_logo, logo)
            rv.setTextViewText(R.id.book_header, "$brand • Shop Now")
            rv.setTextViewText(R.id.book_title, title)
            rv.setTextViewText(R.id.book_price, price)
            rv.setTextViewText(R.id.book_subtitle, subtitle)
            rv.setTextViewText(R.id.book_message, body)
            rv.setTextViewText(R.id.book_button, buttonText)
            if (bitmap != null) rv.setImageViewBitmap(R.id.book_image, bitmap)
        } else {
            rv = RemoteViews(ctx.packageName, R.layout.custom_offer_notification)
            rv.setTextViewText(R.id.offer_logo, logo)
            rv.setTextViewText(R.id.offer_brand, brand)
            rv.setTextViewText(R.id.offer_title, title)
            rv.setTextViewText(R.id.offer_message, body)

            if (bitmap != null) {
                rv.setImageViewBitmap(R.id.offer_image, bitmap)
                rv.setViewVisibility(R.id.offer_image, View.VISIBLE)
            } else {
                rv.setViewVisibility(R.id.offer_image, View.GONE)
            }

            // Timer sirf tab jab valid future expiresAt aaye
            timerRunning = applyTimer(rv, expiryMillis)
        }

        notifyNow(ctx, rv, title, body)

        if (timerRunning) startCountdown(ctx, rv, expiryMillis, title, body)
    }

    // ---------- Timer ----------

    private fun applyTimer(rv: RemoteViews, expiryMillis: Long): Boolean {
        val remaining = expiryMillis - System.currentTimeMillis()
        if (remaining <= 0) {
            rv.setViewVisibility(R.id.timer_section, View.GONE)
            return false
        }
        val totalSeconds = remaining / 1000
        rv.setViewVisibility(R.id.timer_section, View.VISIBLE)
        rv.setTextViewText(R.id.timer_hours, String.format("%02d", totalSeconds / 3600))
        rv.setTextViewText(R.id.timer_mins, String.format("%02d", (totalSeconds % 3600) / 60))
        rv.setTextViewText(R.id.timer_secs, String.format("%02d", totalSeconds % 60))
        return true
    }

    private fun startCountdown(
        ctx: Context,
        rv: RemoteViews,
        expiryMillis: Long,
        title: String,
        body: String
    ) {
        val runnable = object : Runnable {
            override fun run() {
                if (tickRunnable !== this) return

                // User ne notification hata di ho to dobara mat dikhao
                if (!isNotificationActive(ctx)) {
                    tickRunnable = null
                    return
                }

                val stillRunning = applyTimer(rv, expiryMillis)
                notifyNow(ctx, rv, title, body)

                if (stillRunning) {
                    mainHandler.postDelayed(this, 1000)
                } else {
                    tickRunnable = null
                }
            }
        }
        tickRunnable = runnable
        mainHandler.postDelayed(runnable, 1000)
    }

    private fun stopCountdown() {
        tickRunnable?.let { mainHandler.removeCallbacks(it) }
        tickRunnable = null
    }

    private fun isNotificationActive(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val nm = ctx.getSystemService(NotificationManager::class.java)
        return nm.activeNotifications.any { it.id == NOTIFICATION_ID }
    }

    // ---------- Notify ----------

    private fun notifyNow(ctx: Context, rv: RemoteViews, title: String, body: String) {
        val launchIntent = (ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: Intent())
            .apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }

        val pendingIntent = PendingIntent.getActivity(
            ctx,
            NOTIFICATION_ID,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification: Notification = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setCustomContentView(rv)
            .setCustomBigContentView(rv)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ActivityCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS)
            == PackageManager.PERMISSION_GRANTED
        ) {
            NotificationManagerCompat.from(ctx).notify(NOTIFICATION_ID, notification)
        } else {
            Log.w(TAG, "Notification permission not granted")
        }
    }

    // ---------- Helpers ----------

    private fun parseExpiryTime(raw: String?): Long {
        if (raw.isNullOrBlank()) return 0L
        val patterns = listOf("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", "yyyy-MM-dd'T'HH:mm:ss'Z'")
        for (p in patterns) {
            try {
                val sdf = SimpleDateFormat(p, Locale.US)
                sdf.timeZone = TimeZone.getTimeZone("UTC")
                sdf.parse(raw)?.time?.let { return it }
            } catch (_: Exception) {
            }
        }
        return raw.toLongOrNull() ?: 0L
    }

    private fun downloadImage(url: String): Bitmap? {
        if (!(url.startsWith("https://") || url.startsWith("http://"))) return null
        var conn: HttpURLConnection? = null
        return try {
            conn = URL(url).openConnection() as HttpURLConnection
            conn.connectTimeout = 10000
            conn.readTimeout = 10000
            conn.instanceFollowRedirects = true
            conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Android) ToppersWisdom")
            conn.connect()
            if (conn.responseCode in 200..299) {
                val bmp = conn.inputStream.use { BitmapFactory.decodeStream(it) }
                scaleDown(bmp, 700)
            } else null
        } catch (e: Exception) {
            Log.e(TAG, "Image download failed: ${e.message}")
            null
        } finally {
            conn?.disconnect()
        }
    }

    // Bada bitmap RemoteViews me crash karta hai, isliye chhota karo
    private fun scaleDown(bmp: Bitmap?, maxSide: Int): Bitmap? {
        if (bmp == null) return null
        val largest = maxOf(bmp.width, bmp.height)
        if (largest <= maxSide) return bmp
        val ratio = maxSide.toFloat() / largest
        return Bitmap.createScaledBitmap(
            bmp,
            (bmp.width * ratio).toInt(),
            (bmp.height * ratio).toInt(),
            true
        )
    }
}