package com.example.topper_notification

import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

class MyFcmService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        Log.d("ToppersWisdomNotif", "onMessageReceived data=${message.data} notifTitle=${message.notification?.title}")

        val map = HashMap<String, String>(message.data)

        // Console wala "notification" payload aaye to uska title/body/image bhi use karo
        message.notification?.let { n ->
            if (!map.containsKey("title")) map["title"] = n.title ?: ""
            if (!map.containsKey("body")) map["body"] = n.body ?: ""
            if (!map.containsKey("imageUrl")) map["imageUrl"] = n.imageUrl?.toString() ?: ""
        }

        if (map.isNotEmpty()) {
            OfferNotificationHelper.show(applicationContext, map)
        }
    }
}