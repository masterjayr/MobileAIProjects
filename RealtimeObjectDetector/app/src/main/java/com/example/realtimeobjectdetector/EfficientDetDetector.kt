package com.example.realtimeobjectdetector

import android.content.Context
import android.graphics.Bitmap
import android.graphics.RectF
import android.util.Log
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel

class EfficientDetDetector(
    private val context: Context
) {
    private val interpreter: Interpreter
    private val labels: List<String>

    init {
        interpreter = Interpreter(loadModelFile())
        labels = loadLabels()
        logModelDetails()
    }

    private fun loadModelFile(): MappedByteBuffer {
      val fileDescriptor = context.assets.openFd("efficientdet_lite0.tflite")
        val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
        val fileChannel = inputStream.channel

        return fileChannel.map(
            FileChannel.MapMode.READ_ONLY,
            fileDescriptor.startOffset,
            fileDescriptor.declaredLength
        )
    }

    private fun logModelDetails() {
        val inputTensor = interpreter.getInputTensor(0)
        Log.d("EfficientDet", "Input shape: ${inputTensor.shape().contentToString()}")
        Log.d("EfficientDet", "Input type: ${inputTensor.dataType()}")

        val outputCount = interpreter.outputTensorCount
        Log.d("EfficientDet", "Output count: $outputCount")

        for (i in 0 until outputCount) {
            val outputTensor = interpreter.getOutputTensor(i)

            Log.d(
                "EfficientDet",
                "Output $i shape: ${outputTensor.shape().contentToString()}, type: ${outputTensor.dataType()}"
            )

        }
    }

    private fun loadLabels(): List<String> {
        return context.assets.open("labels.txt")
            .bufferedReader()
            .readLines()
    }

    fun detect(bitmap: Bitmap): List<Detection> {
        val letterbox = bitmapToLetterboxInputBuffer(bitmap)
        val inputBuffer = letterbox.inputBuffer

        val boxes = Array(1) { Array(25) { FloatArray(4)} }
        val classes = Array(1) { FloatArray(25) }
        val scores = Array(1) { FloatArray(25)}
        val count = FloatArray(1)

        val outputs = mapOf(
            0 to boxes,
            1 to classes,
            2 to scores,
            3 to count
        )

        interpreter.runForMultipleInputsOutputs(arrayOf(inputBuffer), outputs)


        return parseDetections(
            boxes,
            classes,
            scores,
            count[0].toInt(),
            letterbox,
            bitmap.width,
            bitmap.height
        )
    }

    private fun parseDetections(
        boxes: Array<Array<FloatArray>>,
        classes: Array<FloatArray>,
        scores: Array<FloatArray>,
        count: Int,
        letterbox: LetterboxResult,
        originalWidth: Int,
        originalHeight: Int
    ): List<Detection> {
        val results = mutableListOf<Detection>()

        for (i in 0 until count) {

            val inputSize = 320f

            val confidence = scores[0][i]

            if (confidence < 0.5f) continue

            val box = boxes[0][i]

            val ymin = box[0].coerceIn(0f, 1f)
            val xmin = box[1].coerceIn(0f, 1f)
            val ymax = box[2].coerceIn(0f, 1f)
            val xmax = box[3].coerceIn(0f, 1f)

            val rect = RectF(
                xmin,
                ymin,
                xmax,
                ymax
            )

            val classIndex = classes[0][i].toInt()
            val adjustedIndex = classIndex + 1
            val label =
                if (adjustedIndex in labels.indices)
                    labels[adjustedIndex]
                else
                    "Unknown"
            Log.d(
                "LabelDebug",
                "classIndex=$classIndex label=${labels.getOrNull(classIndex)} " +
                        "prev=${labels.getOrNull(classIndex - 1)} " +
                        "next=${labels.getOrNull(classIndex + 1)}"
            )
            results.add(Detection(label = label, confidence=confidence, boundingBox = rect))

        }

        return results.toList()
    }

    private fun bitmapToLetterboxInputBuffer(bitmap: Bitmap): LetterboxResult {
        val inputSize = 320

        val scale = minOf(
            inputSize.toFloat() / bitmap.width,
            inputSize.toFloat() / bitmap.height
        )

        val newWidth = (bitmap.width * scale).toInt()
        val newHeight = (bitmap.height * scale).toInt()

        val resized = Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)

        val padded = Bitmap.createBitmap(inputSize, inputSize, Bitmap.Config.ARGB_8888)

        val canvas = android.graphics.Canvas(padded)
        canvas.drawColor(android.graphics.Color.BLACK)

        val padX = (inputSize - newWidth) / 2f
        val padY = (inputSize - newHeight) / 2f

        canvas.drawBitmap(resized, padX, padY, null)

        val buffer = ByteBuffer.allocateDirect(inputSize * inputSize * 3)
        buffer.order(ByteOrder.nativeOrder())

        val pixels = IntArray(inputSize * inputSize)

        // IMPORTANT: read from padded, not resized
        padded.getPixels(
            pixels,
            0,
            inputSize,
            0,
            0,
            inputSize,
            inputSize
        )

        for (pixel in pixels) {
            val r = (pixel shr 16) and 0xFF
            val g = (pixel shr 8) and 0xFF
            val b = pixel and 0xFF

            buffer.put(r.toByte())
            buffer.put(g.toByte())
            buffer.put(b.toByte())
        }

        buffer.rewind()

        return LetterboxResult(
            inputBuffer = buffer,
            scale = scale,
            padX = padX,
            padY = padY
        )
    }
}