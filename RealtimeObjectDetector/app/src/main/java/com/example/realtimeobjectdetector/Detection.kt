package com.example.realtimeobjectdetector

import android.graphics.RectF
import java.nio.ByteBuffer

data class Detection(
    val label: String,
    val confidence: Float,
    val boundingBox: RectF)

data class LetterboxResult(
    val inputBuffer: ByteBuffer,
    val scale: Float,
    val padX: Float,
    val padY: Float
)