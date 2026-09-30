package com.navideck.volume_button_listener

import android.app.Activity
import android.view.Window
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import org.mockito.Mockito
import org.mockito.Mockito.`when`
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/*
 * Exercises the Android interceptor bookkeeping behind [isListening] and
 * [stopListener] without an emulator. The window callback is the only thing that
 * actually receives key events, so "listening" must mean "the window still
 * delegates to our interceptor", not merely "we once installed one".
 *
 * Run with `./gradlew testDebugUnitTest` from `example/android/`.
 */

internal class VolumeButtonListenerPluginTest {

    private class Fixture {
        val activity: Activity = Mockito.mock(Activity::class.java)
        val window: Window = Mockito.mock(Window::class.java)
        val delegate: Window.Callback = Mockito.mock(Window.Callback::class.java)
        var installed: Window.Callback? = null

        init {
            `when`(activity.window).thenReturn(window)
            `when`(window.callback).thenReturn(delegate)
            Mockito.doAnswer { invocation ->
                installed = invocation.getArgument(0) as Window.Callback
                null
            }.`when`(window).setCallback(Mockito.any(Window.Callback::class.java))
        }

        fun plugin(): VolumeButtonListenerPlugin {
            val binding = Mockito.mock(ActivityPluginBinding::class.java)
            `when`(binding.activity).thenReturn(activity)
            return VolumeButtonListenerPlugin().also { it.onAttachedToActivity(binding) }
        }

        /** Simulates the host replacing `window.callback` with its own. */
        fun clobber(callback: Window.Callback) {
            `when`(window.callback).thenReturn(callback)
        }

        /** Makes `window.callback` report whatever was installed. */
        fun acceptInstalled() {
            installed?.let { `when`(window.callback).thenReturn(it) }
        }
    }

    @Test
    fun isListening_isFalseBeforeStart() {
        assertFalse(Fixture().plugin().isListening())
    }

    @Test
    fun isListening_isTrueWhileWindowDelegatesToInterceptor() {
        val fixture = Fixture()
        val plugin = fixture.plugin()

        plugin.startListener()
        fixture.acceptInstalled()

        assertTrue(plugin.isListening())
    }

    @Test
    fun isListening_isFalseAfterWindowCallbackIsReplaced() {
        val fixture = Fixture()
        val plugin = fixture.plugin()

        plugin.startListener()
        fixture.acceptInstalled()
        assertTrue(plugin.isListening())

        // The host installs its own callback over ours (as Android XR does when
        // it moves input focus between surfaces or spaces).
        fixture.clobber(Mockito.mock(Window.Callback::class.java))

        assertFalse(plugin.isListening())
    }

    @Test
    fun stopListener_clearsStateEvenWhenTheInterceptorWasReplaced() {
        val fixture = Fixture()
        val plugin = fixture.plugin()

        plugin.startListener()
        fixture.clobber(Mockito.mock(Window.Callback::class.java))

        plugin.stopListener()

        assertFalse(plugin.isListening())
        // Must not overwrite the callback that replaced ours.
        Mockito.verify(fixture.window, Mockito.never()).setCallback(fixture.delegate)
    }

    @Test
    fun stopListener_restoresOriginalCallbackWhileStillInstalled() {
        val fixture = Fixture()
        val plugin = fixture.plugin()

        plugin.startListener()
        fixture.acceptInstalled()

        plugin.stopListener()

        Mockito.verify(fixture.window).setCallback(fixture.delegate)
        assertFalse(plugin.isListening())
    }
}
