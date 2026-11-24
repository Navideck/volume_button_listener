package com.navideck.volume_button_listener

import android.content.ContentResolver
import android.content.Context
import android.media.AudioManager
import android.os.Handler
import org.mockito.Mockito
import org.mockito.Mockito.`when`
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/*
 * Exercises the volumeEvents-mode press detection in [VolumeButtonListener]
 * (the class in VolumeButtonKit.kt) without a device: direction inference,
 * release/revert behaviour, programmatic setVolume, and focus suspension.
 *
 * The handler and the clock are injected so the release timer can be fired
 * manually instead of relying on a real Looper.
 */
internal class VolumeButtonKitTest {

    private class Fixture {
        val context: Context = Mockito.mock(Context::class.java)
        val audioManager: AudioManager = Mockito.mock(AudioManager::class.java)
        val contentResolver: ContentResolver = Mockito.mock(ContentResolver::class.java)
        val handler: Handler = Mockito.mock(Handler::class.java)

        val pressed = mutableListOf<VolumeButtonDirection>()
        val released = mutableListOf<VolumeButtonDirection>()

        var volume = 5
        var now = 1_000L
        private val posted = mutableListOf<Runnable>()

        // Lazy so the kit is created after the stubs below are in place.
        val listener: VolumeButtonListener by lazy {
            VolumeButtonListener(
                context,
                handler,
                nowMillis = { now },
            ).apply {
                volumeButtonPressed = { pressed.add(it) }
                volumeButtonReleased = { released.add(it) }
            }
        }

        init {
            `when`(context.getSystemService(Context.AUDIO_SERVICE)).thenReturn(audioManager)
            `when`(context.contentResolver).thenReturn(contentResolver)
            `when`(audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)).thenAnswer { volume }
            `when`(audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)).thenReturn(15)
            Mockito.doAnswer { invocation ->
                volume = invocation.getArgument(1)
                null
            }.`when`(audioManager).setStreamVolume(
                Mockito.anyInt(),
                Mockito.anyInt(),
                Mockito.anyInt(),
            )
            Mockito.doAnswer { invocation ->
                posted.add(invocation.getArgument(0))
                true
            }.`when`(handler).postDelayed(Mockito.any(Runnable::class.java), Mockito.anyLong())
            Mockito.doAnswer { invocation ->
                posted.remove(invocation.getArgument(0))
                null
            }.`when`(handler).removeCallbacks(Mockito.any(Runnable::class.java))
        }

        /** Simulates the hardware button moving the media stream by one step. */
        fun moveVolumeTo(value: Int) {
            volume = value
            listener.handleVolumeChange("test")
        }

        /** Runs the pending inactivity timer, as the main looper eventually would. */
        fun fireRelease() {
            check(posted.isNotEmpty()) { "no release scheduled" }
            posted.removeAt(posted.lastIndex).run()
        }
    }

    @Test
    fun volumeIncreaseEmitsPressedUp() {
        val fixture = Fixture()
        fixture.listener.startListening()

        fixture.moveVolumeTo(6)

        assertEquals(listOf(VolumeButtonDirection.UP), fixture.pressed)
        assertTrue(fixture.released.isEmpty())
    }

    @Test
    fun volumeDecreaseEmitsPressedDown() {
        val fixture = Fixture()
        fixture.listener.startListening()

        fixture.moveVolumeTo(4)

        assertEquals(listOf(VolumeButtonDirection.DOWN), fixture.pressed)
    }

    @Test
    fun releaseRevertsVolumeWhenVolumeUiIsHidden() {
        val fixture = Fixture()
        fixture.listener.startListening()

        fixture.moveVolumeTo(6)
        fixture.fireRelease()

        assertEquals(listOf(VolumeButtonDirection.UP), fixture.released)
        // The system already applied the change; showVolumeUI = false (default)
        // reverts it so relying on button events does not drift the volume.
        assertEquals(5, fixture.volume)
    }

    @Test
    fun releaseKeepsVolumeWhenVolumeUiIsShown() {
        val fixture = Fixture()
        fixture.listener.showsVolumeUi = true
        fixture.listener.startListening()

        fixture.moveVolumeTo(6)
        fixture.fireRelease()

        assertEquals(listOf(VolumeButtonDirection.UP), fixture.released)
        assertEquals(6, fixture.volume)
    }

    @Test
    fun changingDirectionReleasesThePreviousDirection() {
        val fixture = Fixture()
        fixture.listener.startListening()

        fixture.moveVolumeTo(6)
        fixture.moveVolumeTo(5)

        assertEquals(
            listOf(VolumeButtonDirection.UP, VolumeButtonDirection.DOWN),
            fixture.pressed,
        )
        assertEquals(listOf(VolumeButtonDirection.UP), fixture.released)
    }

    @Test
    fun appInitiatedSetVolumeIsNotReportedAsAPress() {
        val fixture = Fixture()
        fixture.listener.startListening()

        fixture.listener.setVolume(0.5)
        // The content observer fires for the change the app just made.
        fixture.listener.handleVolumeChange("observer")

        assertTrue(fixture.pressed.isEmpty(), "app-initiated volume must not look like a button")
        assertEquals(7, fixture.volume)

        // A real step after the ignore window is still detected.
        fixture.now += 300
        fixture.moveVolumeTo(8)
        assertEquals(listOf(VolumeButtonDirection.UP), fixture.pressed)
    }

    @Test
    fun pauseStopsDeliveringEventsUntilResumed() {
        val fixture = Fixture()
        fixture.listener.startListening()

        fixture.listener.pause()
        assertFalse(fixture.listener.isListening())
        fixture.moveVolumeTo(6)
        assertTrue(fixture.pressed.isEmpty())

        fixture.listener.resume()
        assertTrue(fixture.listener.isListening())
        fixture.moveVolumeTo(7)
        assertEquals(listOf(VolumeButtonDirection.UP), fixture.pressed)
    }

    @Test
    fun startListeningMovesVolumeAwayFromBounds() {
        val fixture = Fixture()
        fixture.volume = 0

        fixture.listener.startListening()
        assertEquals(1, fixture.volume)

        fixture.listener.stopListening()
        fixture.volume = 15
        fixture.listener.startListening()
        assertEquals(14, fixture.volume)
    }
}
