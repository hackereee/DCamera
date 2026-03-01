package com.dcamera.demo

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.os.Handler
import android.os.HandlerThread
import android.view.Surface
import android.view.TextureView

@Suppress("DEPRECATION")
class Camera2TexturePreviewDisplay(
    context: Context,
    private val textureView: TextureView,
) : PreviewDisplayPort {
    private val cameraManager: CameraManager? = context.getSystemService(CameraManager::class.java)
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var previewSurface: Surface? = null
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    @Volatile private var starting: Boolean = false

    @SuppressLint("MissingPermission")
    override fun startPreview(): Boolean {
        if (cameraDevice != null || captureSession != null || starting) return true
        val manager = cameraManager ?: return false
        val surfaceTexture = textureView.surfaceTexture ?: return false
        val cameraId = selectBackCameraId(manager) ?: return false

        val width = textureView.width.takeIf { it > 0 } ?: 1280
        val height = textureView.height.takeIf { it > 0 } ?: 720
        surfaceTexture.setDefaultBufferSize(width, height)
        previewSurface = Surface(surfaceTexture)

        startBackgroundThread()
        val handler = backgroundHandler ?: return false

        return try {
            starting = true
            manager.openCamera(cameraId, stateCallback, handler)
            true
        } catch (_: SecurityException) {
            cleanupOnStartFailure()
            false
        } catch (_: Exception) {
            cleanupOnStartFailure()
            false
        }
    }

    override fun stopPreview(): Boolean {
        starting = false
        try {
            captureSession?.stopRepeating()
        } catch (_: Exception) {
        }
        captureSession?.close()
        captureSession = null

        cameraDevice?.close()
        cameraDevice = null

        previewSurface?.release()
        previewSurface = null

        stopBackgroundThread()
        return true
    }

    private val stateCallback = object : CameraDevice.StateCallback() {
        override fun onOpened(camera: CameraDevice) {
            starting = false
            cameraDevice = camera
            val surface = previewSurface
            if (surface == null) {
                camera.close()
                cameraDevice = null
                return
            }
            val handler = backgroundHandler
            camera.createCaptureSession(
                listOf(surface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        val device = cameraDevice ?: return
                        captureSession = session
                        val request = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                            addTarget(surface)
                            set(
                                CaptureRequest.CONTROL_AF_MODE,
                                CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE,
                            )
                        }.build()
                        session.setRepeatingRequest(request, null, handler)
                    }

                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        session.close()
                        captureSession = null
                    }
                },
                handler,
            )
        }

        override fun onDisconnected(camera: CameraDevice) {
            starting = false
            camera.close()
            cameraDevice = null
            releaseSessionAndSurface()
        }

        override fun onError(camera: CameraDevice, error: Int) {
            starting = false
            camera.close()
            cameraDevice = null
            releaseSessionAndSurface()
        }
    }

    private fun selectBackCameraId(manager: CameraManager): String? {
        val backId = manager.cameraIdList.firstOrNull { cameraId ->
            val chars = manager.getCameraCharacteristics(cameraId)
            val lens = chars.get(CameraCharacteristics.LENS_FACING)
            val hasTextureOutput = chars
                .get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                ?.getOutputSizes(SurfaceTexture::class.java)
                ?.isNotEmpty() == true
            lens == CameraCharacteristics.LENS_FACING_BACK && hasTextureOutput
        }
        if (backId != null) return backId
        return manager.cameraIdList.firstOrNull()
    }

    private fun cleanupOnStartFailure() {
        starting = false
        releaseSessionAndSurface()
        stopBackgroundThread()
    }

    private fun releaseSessionAndSurface() {
        captureSession?.close()
        captureSession = null
        previewSurface?.release()
        previewSurface = null
    }

    private fun startBackgroundThread() {
        if (backgroundThread != null) return
        backgroundThread = HandlerThread("DemoCamera2Preview").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
    }

    private fun stopBackgroundThread() {
        val thread = backgroundThread ?: return
        thread.quitSafely()
        try {
            thread.join(500)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        backgroundThread = null
        backgroundHandler = null
    }
}
