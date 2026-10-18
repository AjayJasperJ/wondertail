package com.ajayjasperj.wondertail

import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.SoundPool
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.math.*

class MainActivity : FlutterActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
    private val pool = SoundPool.Builder().setMaxStreams(4).setAudioAttributes(attributes).build()
    private val sounds = mutableMapOf<String, Int>()
    private val ready = mutableSetOf<Int>()
    private var musicStream = 0
    private var desiredTheme: Int? = null
    private var destroyed = false
    private lateinit var manager: AudioManager
    private var focus: AudioFocusRequest? = null
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change < 0) handler.post { stopAudio() }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        manager = getSystemService(AUDIO_SERVICE) as AudioManager
        pool.setOnLoadCompleteListener { _, id, status ->
            if (status == 0) {
                ready.add(id)
                desiredTheme?.let { playMusic(it) }
            }
        }
        val tracks = mapOf(
            "music0" to doubleArrayOf(261.63,329.63,392.0,523.25,392.0,329.63,293.66,392.0),
            "music1" to doubleArrayOf(293.66,440.0,587.33,523.25,440.0,349.23,329.63,440.0),
            "music2" to doubleArrayOf(329.63,392.0,493.88,659.25,587.33,493.88,392.0,293.66),
            "coin" to doubleArrayOf(880.0,1318.51),
            "near" to doubleArrayOf(659.25,880.0),
            "task" to doubleArrayOf(523.25,659.25,783.99),
            "complete" to doubleArrayOf(523.25,659.25,783.99,1046.5)
        )
        worker.execute {
            tracks.forEach { (name, notes) ->
                val file = File(cacheDir, "wondertail-$name.wav")
                synthesize(file, notes, if (name.startsWith("music")) 0.65 else 0.11)
                handler.post {
                    if (!destroyed) sounds[name] = pool.load(file.absolutePath, 1)
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wondertail/audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "music" -> {
                        desiredTheme = (call.arguments as? Number)?.toInt() ?: 0
                        playMusic(desiredTheme!!)
                    }
                    "cue" -> {
                        sounds[call.arguments as? String]?.let { id ->
                            if (ready.contains(id)) pool.play(id, 0.55f, 0.55f, 2, 0, 1f)
                        }
                    }
                    "pause" -> stopAudio()
                    else -> { result.notImplemented(); return@setMethodCallHandler }
                }
                result.success(null)
            }
    }

    private fun playMusic(theme: Int) {
        val id = sounds["music$theme"] ?: return
        if (!ready.contains(id)) return
        val granted = if (android.os.Build.VERSION.SDK_INT >= 26) {
            val request = focus ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attributes).setOnAudioFocusChangeListener(focusListener)
                .build().also { focus = it }
            manager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            manager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        }
        if (granted != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) return
        pool.stop(musicStream)
        musicStream = pool.play(id, 0.18f, 0.18f, 1, -1, 1f)
    }

    private fun stopAudio() {
        desiredTheme = null
        pool.autoPause()
        pool.stop(musicStream)
        musicStream = 0
        if (::manager.isInitialized) {
            if (android.os.Build.VERSION.SDK_INT >= 26) {
                focus?.let { manager.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                manager.abandonAudioFocus(focusListener)
            }
        }
    }

    private fun synthesize(file: File, notes: DoubleArray, beat: Double) {
        val rate = 22050
        val samples = (notes.size * beat * rate).toInt()
        val data = ByteBuffer.allocate(44 + samples * 2).order(ByteOrder.LITTLE_ENDIAN)
        data.put("RIFF".toByteArray()).putInt(36 + samples * 2).put("WAVEfmt ".toByteArray())
        data.putInt(16).putShort(1.toShort()).putShort(1.toShort()).putInt(rate)
        data.putInt(rate * 2).putShort(2.toShort()).putShort(16.toShort())
        data.put("data".toByteArray()).putInt(samples * 2)
        for (i in 0 until samples) {
            val t = i.toDouble() / rate
            val local = t % beat
            val f = notes[min((t / beat).toInt(), notes.lastIndex)]
            val envelope = min(local / 0.012, 1.0) * exp(-local * 5) * min((beat - local) / 0.04, 1.0)
            val wave = sin(2 * PI * f * local) + 0.25 * sin(4 * PI * f * local)
            data.putShort((wave * envelope * 10000).toInt().toShort())
        }
        file.writeBytes(data.array())
    }

    override fun onPause() {
        stopAudio()
        super.onPause()
    }
    override fun onDestroy() {
        destroyed = true
        worker.shutdownNow()
        pool.release()
        super.onDestroy()
    }
}
