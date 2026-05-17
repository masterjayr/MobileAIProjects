package com.example.realtimeobjectdetector

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Canvas
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.example.realtimeobjectdetector.ui.theme.RealtimeObjectDetectorTheme
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executor
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
class MainActivity : ComponentActivity() {
    private val cameraPermissionGranted = mutableStateOf(false)

    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) {
        isGranted: Boolean ->
        cameraPermissionGranted.value = isGranted
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkCameraPermission()
        enableEdgeToEdge()
        setContent {
            RealtimeObjectDetectorTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                   if (cameraPermissionGranted.value) {
                       DetectorApp(modifier = Modifier.padding(innerPadding))

                   }else {
                       Box(modifier = Modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.Center) {
                           Text("Waiting for camera permission...")
                       }
                   }
                }
            }
        }
    }

    private fun checkCameraPermission() {
        when (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)) {
            PackageManager.PERMISSION_GRANTED -> {
                cameraPermissionGranted.value = true
            }
            else -> {
                requestPermissionLauncher.launch(Manifest.permission.CAMERA)
            }
        }
    }
}

@Composable
fun DetectorApp(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val detector = remember { EfficientDetDetector(context) }

    var detections by remember { mutableStateOf<List<Detection>>(emptyList()) }
    var imageWidth by remember { mutableStateOf(1)}
    var imageHeight by remember { mutableStateOf(1)}
    Box(modifier = modifier.fillMaxSize() ) {
        CameraDetectionPreview(
            detector = detector,
            onDetections = { results, width, height ->
                detections = results
                imageWidth = width
                imageHeight = height
            },
            modifier = Modifier.fillMaxSize()
        )

        DetectionOverlay(
            detections = detections,
            modifier = Modifier.fillMaxSize(),
            imageWidth = imageWidth,
            imageHeight = imageHeight
        )
    }

}

@Composable
fun DetectionOverlay(
    detections: List<Detection>,
    imageWidth: Int,
    imageHeight: Int,
    modifier: Modifier = Modifier
) {
    Canvas(modifier = modifier) {
        val canvasAspect = size.width / size.height
        val imageAspect = imageWidth.toFloat() / imageHeight.toFloat()

        val scale: Float
        val offsetX: Float
        val offsetY: Float

        if (imageAspect > canvasAspect) {
            // imageWider
            scale = size.width / imageWidth
            val scaledHeight = imageHeight * scale
            offsetX = 0f
            offsetY = (size.height - scaledHeight) / 2f
        }else {
            // image taller
            scale = size.height / imageHeight
            val scaledWidth = imageWidth * scale
            offsetX = (size.width - scaledWidth) / 2f
            offsetY = 0f
        }
        detections.forEach { detection ->

            val box = detection.boundingBox

            val left = box.left * imageWidth * scale + offsetX
            val top = box.top * imageHeight * scale + offsetY
            val right = box.right * imageWidth * scale + offsetX
            val bottom = box.bottom * imageHeight * scale + offsetY

            drawRect(
                color = Color.Red,
                topLeft = Offset(left, top),
                size = Size(right - left, bottom - top),
                style = Stroke(width = 5f)
            )

            drawContext.canvas.nativeCanvas.drawText(
                "${(detection.label)} ${(detection.confidence * 100).toInt()}%",
                left,
                top - 8f,
                android.graphics.Paint().apply {
                    color = android.graphics.Color.RED
                    textSize = 42f
                    isAntiAlias = true
                }
            )
        }
    }
}

@Composable
fun CameraDetectionPreview(
    detector: EfficientDetDetector,
    onDetections: (List<Detection>, Int, Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    val analysisExecutor = remember {
        Executors.newSingleThreadExecutor()
    }

    val mainExecutor = remember {
        ContextCompat.getMainExecutor(context)
    }

    AndroidView(
        modifier = modifier,
        factory = { ctx ->
            val previewView = PreviewView(ctx)
            previewView.scaleType = PreviewView.ScaleType.FIT_CENTER
            startObjectDetectionCamera(
                context = ctx,
                lifecycleOwner = lifecycleOwner,
                previewView = previewView,
                detector = detector,
                analysisExecutor = analysisExecutor,
                mainExecutor = mainExecutor,
                onDetections = onDetections
            )

            previewView
        }
    )
}

fun imageProxyToBitmap(image: ImageProxy) : Bitmap {
    val yBuffer = image.planes[0].buffer
    val uBuffer = image.planes[1].buffer
    val vBuffer = image.planes[2].buffer

    val ySize = yBuffer.remaining()
    val uSize = uBuffer.remaining()
    val vSize = vBuffer.remaining()

    val nv21 = ByteArray(ySize + uSize + vSize)

    // Y
    yBuffer.get(nv21, 0, ySize)

    // VU (NV21 format)
    vBuffer.get(nv21, ySize, vSize)
    uBuffer.get(nv21, ySize + vSize, uSize)

    val yuvImage = YuvImage(
        nv21,
        ImageFormat.NV21,
        image.width,
        image.height,
        null
    )

    val out = ByteArrayOutputStream()
    yuvImage.compressToJpeg(
        Rect(0, 0, image.width, image.height),
        100,
        out
    )

    val jpegBytes = out.toByteArray()

    return BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)
}

fun rotateBitmap(bitmap: Bitmap, rotationDegrees: Int) : Bitmap {
    if (rotationDegrees == 0) return bitmap
    val matrix = android.graphics.Matrix()
    matrix.postRotate(rotationDegrees.toFloat())

    return Bitmap.createBitmap(
        bitmap,
        0,
        0,
        bitmap.width,
        bitmap.height,
        matrix,
        true
    )
}

fun startObjectDetectionCamera(
    context: Context,
    lifecycleOwner: LifecycleOwner,
    previewView: PreviewView,
    detector: EfficientDetDetector,
    analysisExecutor: ExecutorService,
    mainExecutor: Executor,
    onDetections: (List<Detection>, Int, Int) -> Unit
) {
    val cameraProviderFuture = ProcessCameraProvider.getInstance(context)

    cameraProviderFuture.addListener({
        val cameraProvider = cameraProviderFuture.get()
        val preview = androidx.camera.core.Preview.Builder()
            .build()

        preview.setSurfaceProvider(previewView.surfaceProvider)

        val imageAnalysis = ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()

        var isProcessing = false

        imageAnalysis.setAnalyzer(analysisExecutor) { imageProxy ->

            if (isProcessing) {
                imageProxy.close()
                return@setAnalyzer
            }

            isProcessing = true

            try {
                val bitmap = imageProxyToBitmap(imageProxy)
                val rotatedBitmap = rotateBitmap(
                    bitmap,
                    imageProxy.imageInfo.rotationDegrees
                )
                val results = detector.detect(rotatedBitmap)

                mainExecutor.execute {
                    onDetections(results, rotatedBitmap.width, rotatedBitmap.height)
                }
            } catch(e: Exception) {
                Log.e("ObjectDetection", "Frame error", e)
            } finally {
                isProcessing = false
                imageProxy.close()
            }
        }

        val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
        cameraProvider.unbindAll()
        cameraProvider.bindToLifecycle(
            lifecycleOwner,
            cameraSelector,
            preview,
            imageAnalysis
        )

    }, ContextCompat.getMainExecutor(context))
}