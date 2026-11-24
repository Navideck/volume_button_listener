package com.navideck.volume_button_listener

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.ContentObserver
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.Log

public enum class VolumeButtonDirection {
    UP,
    DOWN
}

public class VolumeButtonListener(
    private val context: Context,
    handler: Handler? = null,
    /** Returns the current uptime in milliseconds. Injectable so tests can control the ignore window. */
    private val nowMillis: () -> Long = { SystemClock.uptimeMillis() },
) {
    public var volumeButtonPressed: ((VolumeButtonDirection) -> Unit)? = null
    public var volumeButtonReleased: ((VolumeButtonDirection) -> Unit)? = null
    public var showsVolumeUi: Boolean = false

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
    private val mainHandler = handler ?: try {
        Handler(Looper.getMainLooper())
    } catch (e: Exception) {
        Handler(Looper.myLooper() ?: Looper.getMainLooper())
    }

    private var isListening = false
    private var isPaused = false

    private var baselineVolume: Int = 0
    private var lastObservedVolume: Int = 0
    private var activeDirection: VolumeButtonDirection? = null

    private val releaseInactivityIntervalMs: Long = 100L
    private val programmaticChangeIgnoreIntervalMs: Long = 200L
    private var ignoreVolumeChangesUntil: Long = 0L

    private var releaseRunnable: Runnable? = null
    private var contentObserver: ContentObserver? = null
    private var broadcastReceiver: BroadcastReceiver? = null

    public fun pause() {
        isPaused = true
        stopListening()
    }

    public fun resume() {
        if (!isPaused) return
        isPaused = false
        if (hasActiveCallbacks()) {
            startListening()
        }
    }

    public fun startListening() {
        if (isListening) return
        val am = audioManager ?: return
        isListening = true

        val current = am.getStreamVolume(AudioManager.STREAM_MUSIC)
        baselineVolume = current
        lastObservedVolume = current
        activeDirection = null

        Log.d(TAG, "startListening: currentVolume=$current")
        ensureVolumeAwayFromBounds(current)

        registerContentObserver()
        registerBroadcastReceiver()
    }

    public fun stopListening() {
        if (!isListening) return
        Log.d(TAG, "stopListening")
        isListening = false
        activeDirection = null
        releaseRunnable?.let { mainHandler.removeCallbacks(it) }
        releaseRunnable = null

        contentObserver?.let {
            try {
                context.contentResolver.unregisterContentObserver(it)
            } catch (e: Exception) {
                // Ignore
            }
        }
        contentObserver = null

        broadcastReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (e: Exception) {
                // Ignore
            }
        }
        broadcastReceiver = null
    }

    public fun isListening(): Boolean = isListening && !isPaused

    public fun getVolume(): Double {
        val am = audioManager ?: return 0.0
        val current = am.getStreamVolume(AudioManager.STREAM_MUSIC)
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (max <= 0) return 0.0
        return (current.toDouble() / max).coerceIn(0.0, 1.0)
    }

    public fun setVolume(volume: Double) {
        val am = audioManager ?: return
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val index = (volume.coerceIn(0.0, 1.0) * max).toInt().coerceIn(0, max)
        setSystemVolume(index)
        if (isListening) {
            baselineVolume = index
            lastObservedVolume = index
        }
    }

    private fun hasActiveCallbacks(): Boolean {
        return volumeButtonPressed != null || volumeButtonReleased != null
    }

    private fun registerContentObserver() {
        if (contentObserver != null) return
        val observer = object : ContentObserver(mainHandler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                super.onChange(selfChange, uri)
                handleVolumeChange("ContentObserver($uri)")
            }
        }
        contentObserver = observer
        try {
            context.contentResolver.registerContentObserver(
                Settings.System.CONTENT_URI,
                true,
                observer
            )
            Log.d(TAG, "Registered ContentObserver on Settings.System.CONTENT_URI")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register ContentObserver", e)
        }
    }

    private fun registerBroadcastReceiver() {
        if (broadcastReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == VOLUME_CHANGED_ACTION) {
                    val streamType = intent.getIntExtra(EXTRA_VOLUME_STREAM_TYPE, -1)
                    if (streamType == -1 || streamType == AudioManager.STREAM_MUSIC) {
                        // Read the stream instead of trusting the intent extras: the
                        // broadcast is not a protected broadcast, so the value it
                        // carries is only useful after it matches the real volume.
                        handleVolumeChange("BroadcastReceiver(stream=$streamType)")
                    }
                }
            }
        }
        broadcastReceiver = receiver
        val filter = IntentFilter(VOLUME_CHANGED_ACTION)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // Not exported: only the system (and this app) should be able to
                // deliver volume changes, otherwise any installed app could
                // fabricate button events.
                context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.registerReceiver(receiver, filter)
            }
            Log.d(TAG, "Registered BroadcastReceiver for VOLUME_CHANGED_ACTION")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register BroadcastReceiver", e)
        }
    }

    /**
     * Infers a press/release from the current stream volume. Called by the
     * content observer and the volume broadcast receiver; `internal` so the
     * unit tests can drive it without a device.
     */
    internal fun handleVolumeChange(source: String) {
        if (!isListening || isPaused) return
        val am = audioManager ?: return

        val currentVolume = am.getStreamVolume(AudioManager.STREAM_MUSIC)

        val now = nowMillis()
        if (now < ignoreVolumeChangesUntil && currentVolume == baselineVolume) {
            lastObservedVolume = currentVolume
            Log.d(TAG, "Ignoring programmatic volume change from $source: vol=$currentVolume")
            return
        }

        if (currentVolume == lastObservedVolume) {
            return
        }

        val direction = if (currentVolume > lastObservedVolume) {
            VolumeButtonDirection.UP
        } else {
            VolumeButtonDirection.DOWN
        }

        Log.d(TAG, "Volume change detected from $source: $lastObservedVolume -> $currentVolume ($direction)")
        lastObservedVolume = currentVolume

        // If direction changed while a press was active, release the previous direction first
        val prevDirection = activeDirection
        if (prevDirection != null && prevDirection != direction) {
            releaseRunnable?.let { mainHandler.removeCallbacks(it) }
            releaseRunnable = null
            activeDirection = null
            volumeButtonReleased?.invoke(prevDirection)
        }

        if (activeDirection == null) {
            activeDirection = direction
        }
        // Emit a press for every step so held buttons and rapid repeats are
        // visible to listeners; the inactivity timer decides when it releases.
        volumeButtonPressed?.invoke(direction)

        releaseRunnable?.let { mainHandler.removeCallbacks(it) }
        val directionForRelease = direction
        val runnable = Runnable {
            if (!isListening || isPaused) return@Runnable
            releaseRunnable = null
            activeDirection = null
            Log.d(TAG, "Volume button released: $directionForRelease")
            volumeButtonReleased?.invoke(directionForRelease)
            if (!showsVolumeUi) {
                setSystemVolume(baselineVolume)
                lastObservedVolume = baselineVolume
            } else {
                baselineVolume = lastObservedVolume
                ensureVolumeAwayFromBounds(lastObservedVolume)
            }
        }
        releaseRunnable = runnable
        mainHandler.postDelayed(runnable, releaseInactivityIntervalMs)
    }

    private fun setSystemVolume(volumeIndex: Int) {
        ignoreVolumeChangesUntil = nowMillis() + programmaticChangeIgnoreIntervalMs
        try {
            audioManager?.setStreamVolume(
                AudioManager.STREAM_MUSIC,
                volumeIndex,
                AudioManager.FLAG_REMOVE_SOUND_AND_VIBRATE
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to setSystemVolume", e)
        }
    }

    private fun ensureVolumeAwayFromBounds(volume: Int) {
        val am = audioManager ?: return
        val min = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            am.getStreamMinVolume(AudioManager.STREAM_MUSIC)
        } else {
            0
        }
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (volume <= min) {
            val target = (min + 1).coerceAtMost(max)
            setSystemVolume(target)
            baselineVolume = target
            lastObservedVolume = target
        } else if (volume >= max) {
            val target = (max - 1).coerceAtLeast(min)
            setSystemVolume(target)
            baselineVolume = target
            lastObservedVolume = target
        }
    }

    private companion object {
        private const val TAG = "VolumeButtonKit"
        private const val VOLUME_CHANGED_ACTION = "android.media.VOLUME_CHANGED_ACTION"
        private const val EXTRA_VOLUME_STREAM_TYPE = "android.media.EXTRA_VOLUME_STREAM_TYPE"
    }
}
