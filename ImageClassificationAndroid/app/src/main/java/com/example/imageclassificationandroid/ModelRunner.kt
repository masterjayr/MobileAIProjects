package com.example.imageclassificationandroid

import android.content.Context
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder

val classes = listOf(
    "airplane",
    "automobile",
    "bird",
    "cat",
    "deer",
    "dog",
    "frog",
    "horse",
    "ship",
    "truck"
)

class ModelRunner(context: Context) {
    private var interpreter: Interpreter

    private val inputBuffer: ByteBuffer =
        ByteBuffer.allocateDirect(1 * 32 * 32 * 3 * 4).order(ByteOrder.nativeOrder())

    private val output = Array(1) { FloatArray(10)}

    init {
        val assetFile = context.assets.open("cifar10_model.tflite")
        val modelBytes = assetFile.readBytes()

        val modelBuffer = ByteBuffer.allocateDirect(modelBytes.size)
        modelBuffer.order(ByteOrder.nativeOrder())
        modelBuffer.put(modelBytes)
        modelBuffer.rewind()

        interpreter = Interpreter(modelBuffer)
    }

    fun run(bitmap: android.graphics.Bitmap): Int {
        inputBuffer.rewind()

        val resized = android.graphics.Bitmap.createScaledBitmap(bitmap, 32, 32, true)

        for (y in 0 until 32) {
            for (x in 0 until 32) {
                val pixel = resized.getPixel(x, y)

                val r = ((pixel shr 16) and 0xFF) / 255f
                val g = ((pixel shr 8) and 0xFF) / 255f
                val b = (pixel and 0xFF) / 255f

                inputBuffer.putFloat(r)
                inputBuffer.putFloat(g)
                inputBuffer.putFloat(b)
            }
        }

        interpreter.run(inputBuffer, output)

        return output[0].indices.maxBy { output[0][it] }
    }
}