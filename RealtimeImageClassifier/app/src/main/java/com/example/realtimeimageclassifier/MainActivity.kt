package com.example.realtimeimageclassifier

import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.example.realtimeimageclassifier.ui.theme.RealtimeImageClassifierTheme
import androidx.camera.view.PreviewView
import androidx.compose.runtime.mutableStateOf
import android.Manifest
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import androidx.compose.foundation.background
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.*
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executor
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : ComponentActivity() {
    // 1. Create a state to track if permission is granted
    private val cameraPermissionGranted = mutableStateOf(false)

    // 2. Create the launcher to ask for permission
    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        cameraPermissionGranted.value = isGranted
    }
    override fun onCreate(savedInstanceState: Bundle?) {

        super.onCreate(savedInstanceState)
        checkCameraPermission()
        enableEdgeToEdge()
        setContent {
            RealtimeImageClassifierTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    if (cameraPermissionGranted.value) {
                        CameraView(
                            name = "Android",
                            modifier = Modifier.padding(innerPadding)
                        )
                    } else {
                        // Optional: Show a message while waiting for permission
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
fun CameraView(name: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val classifier = remember { MobileNetClassifier(context) }
    val prediction = remember { mutableStateOf("Detecting...") }
    val tracker = remember { ClassificationState() }

    Box(
        modifier = modifier.fillMaxSize()
    ) {
        CameraPreview (
            modifier = Modifier.fillMaxSize(),
            classifier = classifier,
            onPrediction = { label, confidence ->
                prediction.value = "$label (${String.format("%.2f", confidence)})"
            },
            tracker = tracker
        )

        Text(
            text = prediction.value,
            color = androidx.compose.ui.graphics.Color.White,
            fontSize = 20.sp,
            modifier = Modifier.align(Alignment.BottomCenter)
                .background(androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.5f))
                .padding(16.dp)

        )
    }
}

@Composable
fun CameraPreview(
    modifier: Modifier = Modifier,
    classifier: MobileNetClassifier,
    onPrediction: (String, Float) -> Unit,
    tracker: ClassificationState
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    // ✅ Create executor here (Composable scope)
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

            startCamera(
                context = ctx,
                lifecycleOwner = lifecycleOwner,
                previewView = previewView,
                classifier = classifier,
                onPrediction = onPrediction,
                analysisExecutor = analysisExecutor,
                mainExecutor = mainExecutor,

                tracker = tracker
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

fun bitmapToInputBuffer(bitmap: Bitmap): ByteBuffer {

    val resizedBitmap = Bitmap.createScaledBitmap(bitmap, 224, 224, true)

    val inputBuffer = ByteBuffer.allocateDirect(4 * 224 * 224 * 3)
    inputBuffer.order(ByteOrder.nativeOrder())

    val intValues = IntArray(224 * 224)
    resizedBitmap.getPixels(intValues, 0, 224, 0, 0, 224, 224)

    for (pixelValue in intValues) {

        val r = (pixelValue shr 16 and 0xFF)
        val g = (pixelValue shr 8 and 0xFF)
        val b = (pixelValue and 0xFF)

        inputBuffer.putFloat(r / 255.0f)
        inputBuffer.putFloat(g / 255.0f)
        inputBuffer.putFloat(b / 255.0f)
    }

    inputBuffer.rewind()
    return inputBuffer
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

fun startCamera(
    context: Context,
    lifecycleOwner: LifecycleOwner,
    previewView: PreviewView,
    classifier: MobileNetClassifier,
    onPrediction: (String, Float) -> Unit,
    analysisExecutor: ExecutorService,
    mainExecutor: Executor,

    tracker: ClassificationState
) {
    val cameraProviderFuture = ProcessCameraProvider.getInstance(context)

    cameraProviderFuture.addListener({

        val cameraProvider = cameraProviderFuture.get()

        val preview = androidx.camera.core.Preview.Builder()
            .build()

        preview.setSurfaceProvider(previewView.surfaceProvider)

        val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

        cameraProvider.unbindAll()


        val imageAnalysis = ImageAnalysis.Builder()
            .setBackpressureStrategy(
                ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST
            ).build()

        var isProcessing = false
        var lastProcessingTime = 0L
        val minDelay = 100L

        imageAnalysis.setAnalyzer(
            analysisExecutor
        ) { imageProxy ->
            val threshold = 0.3f
            val requiredConsistency = 3

            val currentTime = System.currentTimeMillis()

            if (currentTime - lastProcessingTime < minDelay) {
                imageProxy.close()
                return@setAnalyzer
            }
            lastProcessingTime = currentTime

            if (isProcessing) {
                imageProxy.close()
                return@setAnalyzer
            }

            isProcessing = true

            // Use a try-finally block to ensure the image ALWAYS closes
            try {
                val bitmap = imageProxyToBitmap(imageProxy)
                val rotationDegrees = imageProxy.imageInfo.rotationDegrees
                val rotatedBitmap = rotateBitmap(bitmap, rotationDegrees)
                val inputBuffer = bitmapToInputBuffer(rotatedBitmap)
                val (label, confidence) = classifier.classify(inputBuffer)

                Log.d("Prediction", "$label: $confidence")
                if (confidence < threshold) {
                    // Ignore weak predictions
                    imageProxy.close()
                    isProcessing = false
                    return@setAnalyzer
                }
                if(label == tracker.lastLabel) {
                    tracker.sameCount++
                } else {
                    tracker.lastLabel = label
                    tracker.sameCount = 1
                }
                if(tracker.sameCount >= requiredConsistency) {
                    mainExecutor.execute {
                        onPrediction(label, confidence)
                    }
                }

            } catch (e: Exception) {
                Log.e("CameraFrame", "Analysis error", e)
            } finally {
                isProcessing = false
                imageProxy.close() // Only need to call this ONCE here
            }
        }
        cameraProvider.bindToLifecycle(
            lifecycleOwner,
            cameraSelector,
            preview,
            imageAnalysis
        )
    }, mainExecutor)
}

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    RealtimeImageClassifierTheme {
        CameraView("Android")
    }
}

class ClassificationState {
    var lastLabel: String = ""
    var sameCount: Int = 0
}
