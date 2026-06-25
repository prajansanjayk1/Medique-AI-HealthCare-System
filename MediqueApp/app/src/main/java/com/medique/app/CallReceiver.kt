package com.medique.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsManager
import android.telephony.TelephonyManager
import android.telecom.TelecomManager
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

class CallReceiver : BroadcastReceiver() {

    companion object {
        private var lastState = TelephonyManager.EXTRA_STATE_IDLE
        private var savedNumber: String? = null
    }
    
    // Webhook for Firebase
    private val webhookUrl = "https://us-central1-aishwaryam-acu.cloudfunctions.net/phoneCallHook"
    private val webhookSecret = "REPLACE_WITH_YOUR_HOOK_SECRET" // set to your phone hook secret
    private val client = OkHttpClient()

    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences("MediquePrefs", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("SERVER_ENABLED", true)) {
            return // Server is toggled OFF from the UI, ignore all events entirely
        }

        if (intent.action == TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
            val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            val incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

            if (state == TelephonyManager.EXTRA_STATE_RINGING) {
                lastState = state!!
                savedNumber = incomingNumber
                Log.d("CallReceiver", "Ringing: $incomingNumber")

                // Auto-reject call immediately so patient doesn't have to wait or get billed
                try {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                        val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
                        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ANSWER_PHONE_CALLS) == PackageManager.PERMISSION_GRANTED) {
                            telecomManager.endCall()
                        }
                    } else {
                        // Fallback for Android 8.0 and below (Common on older/cheaper devices)
                        val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                        val m = tm.javaClass.getDeclaredMethod("getITelephony")
                        m.isAccessible = true
                        val telephony = m.invoke(tm)
                        val mEndCall = telephony.javaClass.getDeclaredMethod("endCall")
                        mEndCall.isAccessible = true
                        mEndCall.invoke(telephony)
                    }
                } catch (e: Exception) {
                    Log.e("CallReceiver", "Failed to end call", e)
                }
            }
            if (state == TelephonyManager.EXTRA_STATE_IDLE) {
                if (lastState == TelephonyManager.EXTRA_STATE_RINGING) {
                    // It was a missed call or rejected call
                    Log.d("CallReceiver", "Missed call from: $savedNumber")
                    if (savedNumber != null) {
                        processMissedCall(savedNumber!!, context)
                    }
                }
                lastState = state!!
                savedNumber = null
            }
        }
    }

    private fun processMissedCall(phoneNumber: String, context: Context) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Remove + and spaces
                val cleanPhone = phoneNumber.replace(Regex("\\\\D"), "")
                val hookUrl = "$webhookUrl?phone=$cleanPhone&secret=$webhookSecret"
                val request = Request.Builder()
                    .url(hookUrl)
                    .addHeader("x-hook-secret", webhookSecret)
                    .get()
                    .build()

                Log.d("CallReceiver", "Calling Webhook: $hookUrl")
                client.newCall(request).execute().use { response ->
                    if (response.isSuccessful) {
                        val respBody = response.body?.string()
                        Log.d("CallReceiver", "Webhook Success: $respBody")
                        
                        // Parse JSON and send SMS
                        val json = JSONObject(respBody ?: "{}")
                        if (json.optBoolean("success")) {
                            val smsText = json.optString("smsMessage", "Your token is confirmed.")
                            sendSms(cleanPhone, smsText)
                        } else {
                            Log.e("CallReceiver", "Webhook returned failure format")
                        }
                    } else {
                        Log.e("CallReceiver", "Webhook Error: ${response.code}")
                    }
                    Unit
                }
            } catch (e: Exception) {
                Log.e("CallReceiver", "Error processing call", e)
            }
        }
    }

    private fun sendSms(phone: String, message: String) {
        try {
            val smsManager = SmsManager.getDefault() // For SDK < 31 it's deprecated but works fine, for 31+ context.getSystemService(SmsManager::class.java)
            smsManager.sendTextMessage(phone, null, message, null, null)
            Log.d("CallReceiver", "SMS sent to $phone: $message")
        } catch (e: Exception) {
            Log.e("CallReceiver", "Failed to send SMS", e)
        }
    }
}
