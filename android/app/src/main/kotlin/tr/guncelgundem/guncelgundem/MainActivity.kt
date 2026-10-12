package tr.guncelgundem.guncelgundem

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * GüncelGündem — Mobil Ana Aktivite
 *
 * Firebase/FCM mimarisinden bağımsız, hafif bir bildirim izni köprüsü sağlar.
 * Android 13+ (API 33) POST_NOTIFICATIONS runtime iznini yönetir; eski
 * sürümlerde sistem bildirim durumunu raporlar. Yeni push altyapısı kurmaz.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "tr.guncelgundem/notifications"
    private val deepLinkChannelName = "tr.guncelgundem/deeplinks"
    private val permissionRequestCode = 9140
    private val prefsName = "gg_notification_permission"
    private val keyRequested = "post_notifications_requested"

    private var pendingResult: MethodChannel.Result? = null
    private var deepLinkChannel: MethodChannel? = null
    private var pendingInitialLink: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureNotificationChannels()
        // Cold-start linkini kaydet; Dart tarafı `initial` ile talep edecek.
        intent?.dataString?.takeIf { it.isNotEmpty() }?.let { pendingInitialLink = it }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.dataString?.takeIf { it.isNotEmpty() }?.let { url ->
            // Warm-start linki: Dart tarafına event olarak yayınla.
            val channel = deepLinkChannel
            if (channel != null) {
                channel.invokeMethod("onLink", mapOf("url" to url))
            } else {
                pendingInitialLink = url
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkStatus" -> result.success(currentStatus())
                    "request" -> handleRequest(result)
                    "openSettings" -> result.success(openNotificationSettings())
                    else -> result.notImplemented()
                }
            }
        deepLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deepLinkChannelName,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "initial" -> {
                        val link = pendingInitialLink
                        pendingInitialLink = null
                        result.success(link)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    /** FCM payload'ındaki kanal kimlikleriyle birebir aynı Android 8+ kanalları. */
    private fun ensureNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return

        val news = NotificationChannel(
            "guncelgundem_news",
            "Güncel Gündem Haberleri",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Güncel haberler ve bilgilendirmeler"
            enableVibration(true)
        }
        val breaking = NotificationChannel(
            "guncelgundem_breaking",
            "Son Dakika Haberleri",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Önemli ve son dakika haberleri"
            enableVibration(true)
        }
        manager.createNotificationChannels(listOf(news, breaking))
    }

    /** Güncel izin durumunu string olarak döner. */
    private fun currentStatus(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            // 13 öncesi runtime izin yok; yalnız sistem ayarındaki durum geçerli.
            return if (NotificationManagerCompat.from(this).areNotificationsEnabled()) {
                "granted"
            } else {
                "permanentlyDenied"
            }
        }

        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED

        if (granted) return "granted"

        val hasRequested = getSharedPreferences(prefsName, MODE_PRIVATE)
            .getBoolean(keyRequested, false)
        val showRationale =
            ActivityCompat.shouldShowRequestPermissionRationale(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            )

        // Daha önce sorulmuş, rationale de yoksa kullanıcı kalıcı reddetmiştir.
        return if (hasRequested && !showRationale) "permanentlyDenied" else "denied"
    }

    private fun handleRequest(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(currentStatus())
            return
        }

        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            result.success("granted")
            return
        }

        // Aynı anda yalnız bir bekleyen istek olmasını garanti et.
        if (pendingResult != null) {
            result.success(currentStatus())
            return
        }

        pendingResult = result
        getSharedPreferences(prefsName, MODE_PRIVATE)
            .edit()
            .putBoolean(keyRequested, true)
            .apply()
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            permissionRequestCode,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) return

        val result = pendingResult
        pendingResult = null
        if (result == null) return

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        result.success(if (granted) "granted" else currentStatus())
    }

    /** Uygulamanın sistem bildirim ayarlarını açar. */
    private fun openNotificationSettings(): Boolean {
        return try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                }
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", packageName, null)
                }
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
