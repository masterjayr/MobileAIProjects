package com.example.simpleaiapp

import android.content.Context
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder

object ModelRunner {
    private var interpreter: Interpreter? = null

    private val inputBuffer: ByteBuffer =
        ByteBuffer.allocateDirect(4).order(ByteOrder.nativeOrder())

    private val outputBuffer: ByteBuffer =
        ByteBuffer.allocateDirect(4).order(ByteOrder.nativeOrder())

    fun initialize(context: Context) {
        if (interpreter != null) return

        val assetFileDescriptor = context.assets.openFd("simple_model.tflite")
        val inputStream = assetFileDescriptor.createInputStream()
        val modelBytes = inputStream.readBytes()

        val buffer = ByteBuffer.allocateDirect(modelBytes.size)
        buffer.order(ByteOrder.nativeOrder())
        buffer.put(modelBytes)

        buffer.rewind()

        interpreter = Interpreter(buffer)
    }

    fun runInference(inputValue: Float): Float {
        inputBuffer.rewind()
        inputBuffer.putFloat(inputValue)

        outputBuffer.rewind()

        interpreter?.run(inputBuffer, outputBuffer)

        outputBuffer.rewind()
        return outputBuffer.float
    }
}