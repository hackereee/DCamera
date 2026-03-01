package com.dcamera.demo

import android.Manifest
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.view.TextureView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import com.dcamera.SuperCamera
import com.dcamera.ui.BasicCameraView

class MainActivity : AppCompatActivity() {
    private lateinit var controller: DemoController
    private lateinit var previewDisplay: PreviewDisplayPort

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { result ->
        val cameraGranted = result[Manifest.permission.CAMERA] == true
        val micGranted = result[Manifest.permission.RECORD_AUDIO] == true
        controller.onPermissionResult(cameraGranted, micGranted)
        refreshResult()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        val previewView = findViewById<TextureView>(R.id.tvPreview)
        previewDisplay = Camera2TexturePreviewDisplay(this, previewView)
        controller = DemoController(
            camera = SuperCamera(),
            basicCameraView = BasicCameraView(),
            previewDisplay = previewDisplay,
        )

        permissionLauncher.launch(arrayOf(
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO,
        ))

        findViewById<Button>(R.id.btnPreview).setOnClickListener {
            controller.startPreview(1L)
            refreshResult()
        }

        findViewById<Button>(R.id.btnStopPreview).setOnClickListener {
            controller.stopPreview()
            refreshResult()
        }

        findViewById<Button>(R.id.btnPhoto).setOnClickListener {
            controller.takePhoto("/tmp/demo_photo.jpg")
            refreshResult()
        }

        findViewById<Button>(R.id.btnRecord).setOnClickListener {
            controller.toggleRecord("/tmp/demo_video.mp4")
            refreshResult()
        }

        findViewById<Button>(R.id.btnUi).setOnClickListener {
            controller.toggleUiRecordBadge()
            refreshResult()
        }

        refreshResult()
    }

    override fun onDestroy() {
        previewDisplay.stopPreview()
        super.onDestroy()
    }

    private fun refreshResult() {
        findViewById<TextView>(R.id.tvUiBadge).text = controller.uiBadge()
        findViewById<TextView>(R.id.tvResult).text = controller.lastMessage
    }
}
