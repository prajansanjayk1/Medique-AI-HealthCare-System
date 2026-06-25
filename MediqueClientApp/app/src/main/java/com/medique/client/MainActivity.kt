package com.medique.client

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import com.google.android.gms.tasks.OnCompleteListener
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    
    // Target URL of your Firebase web app
    private val webAppUrl = "https://aishwaryam-acu.web.app/"

    private val tokenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val token = intent?.getStringExtra("token")
            if (!token.isNullOrEmpty()) {
                runOnUiThread {
                    webView.evaluateJavascript("javascript:if(window.onAndroidPushTokenReceived){window.onAndroidPushTokenReceived('$token');}", null)
                }
            }
        }
    }

    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize Firebase
        try {
            FirebaseApp.initializeApp(this)
        } catch (e: Exception) {
            Log.e("MainActivity", "Firebase initialization failed", e)
        }
        
        // Create notification channel
        createNotificationChannel()

        webView = WebView(this)
        setContentView(webView)

        setupWebView()
        
        // Fetch current token and save
        fetchFCMToken()

        // Handle intent if launched from notification
        handleIntent(intent)
    }

    override fun onStart() {
        super.onStart()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            registerReceiver(tokenReceiver, IntentFilter("com.medique.client.FCM_TOKEN"), RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(tokenReceiver, IntentFilter("com.medique.client.FCM_TOKEN"))
        }
    }

    override fun onStop() {
        super.onStop()
        unregisterReceiver(tokenReceiver)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        intent?.let {
            val targetPath = it.getStringExtra("target_url")
            if (!targetPath.isNullOrEmpty()) {
                val fullUrl = if (targetPath.startsWith("http")) targetPath else "${webAppUrl.removeSuffix("/")}/$targetPath"
                Log.d("MainActivity", "Loading URL from notification intent: $fullUrl")
                webView.loadUrl(fullUrl)
            }
        }
    }

    private fun fetchFCMToken() {
        try {
            FirebaseMessaging.getInstance().token.addOnCompleteListener(OnCompleteListener { task ->
                if (!task.isSuccessful) {
                    Log.w("MainActivity", "Fetching FCM registration token failed", task.exception)
                    return@OnCompleteListener
                }
                val token = task.result
                Log.d("MainActivity", "FCM Token: $token")
                val sharedPref = getSharedPreferences("MediQuePrefs", Context.MODE_PRIVATE)
                with(sharedPref.edit()) {
                    putString("fcm_token", token)
                    apply()
                }
                runOnUiThread {
                    webView.evaluateJavascript("javascript:if(window.onAndroidPushTokenReceived){window.onAndroidPushTokenReceived('$token');}", null)
                }
            })
        } catch (e: Exception) {
            Log.e("MainActivity", "Error fetching FCM token", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "high_importance_channel"
            val channelName = "MediQue Notifications"
            val channelDescription = "Urgent MediQue updates including queue status and calling alerts"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                enableLights(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(100, 200, 300, 400, 500)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    private fun setupWebView() {
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(
                view: WebView?, 
                request: android.webkit.WebResourceRequest?
            ): Boolean {
                val url = request?.url?.toString() ?: return false
                if (url.startsWith("upi://", ignoreCase = true)) {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        val chooser = Intent.createChooser(intent, "Pay with UPI")
                        this@MainActivity.startActivityForResult(chooser, UPI_PAYMENT_REQUEST_CODE)
                        return true
                    } catch (e: Exception) {
                        return false
                    }
                }
                return false
            }

            override fun onReceivedError(
                view: WebView?, 
                request: android.webkit.WebResourceRequest?, 
                error: android.webkit.WebResourceError?
            ) {
                super.onReceivedError(view, request, error)
                if (request?.isForMainFrame == true) {
                    val errorHtml = """
                        <html>
                            <body style="display:flex; justify-content:center; align-items:center; height:100vh; font-family:sans-serif; text-align:center; background-color:#FAFAFA; color:#333; margin:0;">
                                <div style="padding:20px;">
                                    <h2 style="color:#D32F2F; margin-bottom:10px;">Connection Lost</h2>
                                    <p style="margin-bottom:20px;">Medique needs an active internet connection.</p>
                                    <button onclick="window.location.reload()" style="padding:12px 24px; font-size:16px; font-weight:bold; border-radius:8px; background:#2196F3; color:white; border:none; box-shadow:0 2px 4px rgba(0,0,0,0.2);">Try Again</button>
                                </div>
                            </body>
                        </html>
                    """.trimIndent()
                    view?.loadDataWithBaseURL(webAppUrl, errorHtml, "text/html", "UTF-8", null)
                }
            }
        }
        webView.webChromeClient = WebChromeClient()
        
        val settings: WebSettings = webView.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.useWideViewPort = true
        settings.loadWithOverviewMode = true
        settings.setSupportZoom(false)
        settings.builtInZoomControls = false

        // Add native UPI Javascript Interface bridge
        webView.addJavascriptInterface(UPIJavaScriptInterface(), "AndroidUPI")
        // Add native notification bridge
        webView.addJavascriptInterface(AndroidNotificationBridge(), "AndroidNotificationBridge")
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack() // Navigate back in WebView history
        } else {
            super.onBackPressed() // Exit App
        }
    }

    inner class AndroidNotificationBridge {
        @JavascriptInterface
        fun getFCMToken(): String {
            val sharedPref = getSharedPreferences("MediQuePrefs", Context.MODE_PRIVATE)
            return sharedPref.getString("fcm_token", "") ?: ""
        }

        @JavascriptInterface
        fun requestNotificationPermission() {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    requestPermissions(
                        arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                        POST_NOTIFICATIONS_REQUEST_CODE
                    )
                }
            }
        }
    }

    // Inner class for Javascript Interface Bridge
    inner class UPIJavaScriptInterface {
        @JavascriptInterface
        fun getInstalledUpiApps(): String {
            val upiApps = JSONArray()
            val upiIntent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("upi://pay")
            }
            val pm = packageManager
            val resolveInfoList = pm.queryIntentActivities(upiIntent, PackageManager.MATCH_DEFAULT_ONLY)
            
            val knownPackages = mapOf(
                "com.google.android.apps.nbu.paisa.user" to "Google Pay",
                "com.phonepe.app" to "PhonePe",
                "net.one97.paytm" to "Paytm",
                "in.org.npci.upiapp" to "BHIM",
                "com.amazon.mShop.android.shopping" to "Amazon Pay"
            )
            
            for (info in resolveInfoList) {
                val pkg = info.activityInfo.packageName
                val appName = knownPackages[pkg] ?: info.loadLabel(pm).toString()
                val appObj = JSONObject().apply {
                    put("packageName", pkg)
                    put("appName", appName)
                }
                upiApps.put(appObj)
            }
            return upiApps.toString()
        }

        @JavascriptInterface
        fun initiateUPIPayment(upiUri: String, appPackage: String?) {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse(upiUri)
            }
            if (!appPackage.isNullOrEmpty()) {
                intent.setPackage(appPackage)
            }
            
            try {
                val chooser = if (appPackage.isNullOrEmpty()) {
                    Intent.createChooser(intent, "Pay with UPI")
                } else {
                    intent
                }
                startActivityForResult(chooser, UPI_PAYMENT_REQUEST_CODE)
            } catch (e: Exception) {
                if (!appPackage.isNullOrEmpty()) {
                    try {
                        val fallbackIntent = Intent(Intent.ACTION_VIEW).apply {
                            data = Uri.parse(upiUri)
                        }
                        val chooser = Intent.createChooser(fallbackIntent, "Pay with UPI")
                        startActivityForResult(chooser, UPI_PAYMENT_REQUEST_CODE)
                    } catch (ex: Exception) {
                        sendPaymentResultToWeb("FAILED", "", "", "", "No UPI apps found: ${ex.message}")
                    }
                } else {
                    sendPaymentResultToWeb("FAILED", "", "", "", "Failed to open UPI apps: ${e.message}")
                }
            }
        }
    }

    private fun parseQueryString(query: String): Map<String, String> {
        val result = mutableMapOf<String, String>()
        val pairs = query.split("&")
        for (pair in pairs) {
            val idx = pair.indexOf("=")
            if (idx > 0) {
                val key = pair.substring(0, idx)
                val value = pair.substring(idx + 1)
                result[key] = value
            } else if (pair.isNotEmpty()) {
                result[pair] = ""
            }
        }
        return result
    }

    private fun sendPaymentResultToWeb(status: String, txnId: String, txnRef: String, responseCode: String, message: String) {
        val script = "javascript:if(window.handleUPIResponse) { window.handleUPIResponse('$status', '$txnId', '$txnRef', '$responseCode', '$message'); }"
        runOnUiThread {
            webView.evaluateJavascript(script, null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == UPI_PAYMENT_REQUEST_CODE) {
            var status = "PENDING"
            var txnId = ""
            var txnRef = ""
            var responseCode = ""
            var message = ""
            
            if (data != null) {
                val response = data.getStringExtra("response") ?: data.data?.toString() ?: ""
                message = response
                val params = parseQueryString(response)
                
                val rawStatus = params["Status"] ?: params["status"] ?: ""
                status = when (rawStatus.uppercase()) {
                    "SUCCESS" -> "SUCCESS"
                    "FAILURE", "FAILED" -> "FAILED"
                    "SUBMITTED" -> "SUBMITTED"
                    "CANCELLED", "CANCEL" -> "CANCELLED"
                    else -> "PENDING"
                }
                
                txnId = params["txnId"] ?: params["txnid"] ?: ""
                txnRef = params["txnRef"] ?: params["txnref"] ?: params["approvalRefNo"] ?: ""
                responseCode = params["responseCode"] ?: params["responsecode"] ?: ""
            } else {
                status = "CANCELLED"
                message = "Payment cancelled by user"
            }
            
            sendPaymentResultToWeb(status, txnId, txnRef, responseCode, message)
        }
    }

    companion object {
        private const val UPI_PAYMENT_REQUEST_CODE = 1001
        private const val POST_NOTIFICATIONS_REQUEST_CODE = 1002
    }
}
