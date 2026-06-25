package com.medique.app

import android.Manifest
import android.content.IntentFilter
import android.telephony.TelephonyManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
import android.widget.Button
import android.widget.Switch
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {

    private val PERMISSIONS = arrayOf(
        Manifest.permission.READ_PHONE_STATE,
        Manifest.permission.READ_CALL_LOG,
        Manifest.permission.SEND_SMS,
        Manifest.permission.ANSWER_PHONE_CALLS,
        Manifest.permission.CALL_PHONE
    )
    
    private val callReceiver = CallReceiver()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val statusText = findViewById<TextView>(R.id.statusText)
        val btnPermissions = findViewById<Button>(R.id.btnPermissions)
        val switchServer = findViewById<Switch>(R.id.switchServer)
        
        val prefs = getSharedPreferences("MediquePrefs", Context.MODE_PRIVATE)
        switchServer.isChecked = prefs.getBoolean("SERVER_ENABLED", true)

        switchServer.setOnCheckedChangeListener { _, isChecked ->
            prefs.edit().putBoolean("SERVER_ENABLED", isChecked).apply()
            if (isChecked) {
                statusText.text = "Server Active. Waiting for Missed Calls..."
            } else {
                statusText.text = "Server Paused. Missed Calls Ignored."
            }
        }

        if (checkPermissions()) {
            if (switchServer.isChecked) {
                statusText.text = "Server Active. Waiting for Missed Calls..."
            } else {
                statusText.text = "Server Paused. Missed Calls Ignored."
            }
            btnPermissions.isEnabled = false
            registerCallReceiver()
        }

        btnPermissions.setOnClickListener {
            ActivityCompat.requestPermissions(this, PERMISSIONS, 100)
        }
    }
    
    private fun registerCallReceiver() {
        val filter = IntentFilter(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
        registerReceiver(callReceiver, filter)
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(callReceiver)
        } catch (e: Exception) {}
    }

    private fun checkPermissions(): Boolean {
        for (p in PERMISSIONS) {
            if (ContextCompat.checkSelfPermission(this, p) != PackageManager.PERMISSION_GRANTED) {
                return false
            }
        }
        return true
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 100 && checkPermissions()) {
            findViewById<TextView>(R.id.statusText).text = "Server Active. Waiting for Missed Calls..."
            findViewById<Button>(R.id.btnPermissions).isEnabled = false
            registerCallReceiver()
        }
    }
}
