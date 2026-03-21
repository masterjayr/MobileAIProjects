package com.example.realtimeimageclassifier

import android.content.Context
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel

class MobileNetClassifier(context: Context) {
    private val interpreter: Interpreter
    private val labels: List<String>

    init {
        interpreter = Interpreter(loadModelFile(context))
        labels = loadLabels(context)
    }

    private fun loadModelFile(context:Context): MappedByteBuffer {
        val fileDescriptor = context.assets.openFd("mobilenet_v1_1.0_224.tflite")
        val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
        val fileChannel = inputStream.channel

        val startOffset = fileDescriptor.startOffset
        val declaredLength = fileDescriptor.declaredLength

        return fileChannel.map(
            FileChannel.MapMode.READ_ONLY,
            startOffset,
            declaredLength
        )
    }

    private fun loadLabels(context: Context): List<String> {
        return context.assets.open("labels.txt")
            .bufferedReader()
            .readLines()
    }

    fun classify(inputBuffer: ByteBuffer): Pair<String, Float> {
        val output = Array(1) { FloatArray(1001)}

        interpreter.run(inputBuffer, output)

        val scores = output[0]

        var maxIndex = 0
        var maxScore = scores[0]

        for (i in scores.indices) {
            if (scores[i] > maxScore) {
                maxScore = scores[i]
                maxIndex = i
            }
        }

        val labelIndex = if (labels.size == 1000) maxIndex - 1 else maxIndex

        val label = if (labelIndex in labels.indices)
            labels[labelIndex]
        else
            "Unknown"

        return Pair(label, maxScore)
    }
}