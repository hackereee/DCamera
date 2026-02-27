package com.dcamera.render

/**
 * JNI bindings for the native bgfx render pipeline.
 *
 * These are method declarations only -- the actual native implementation
 * will be provided when the .so is built in a later task.
 */
object NativeRenderBindings {

    init {
        try {
            System.loadLibrary("supercamera_render")
        } catch (_: UnsatisfiedLinkError) {
            // Native library not yet available; stubs will throw at call site.
        }
    }

    /** Attach a platform surface (ANativeWindow handle) to the bgfx renderer. */
    @JvmStatic
    external fun nativeAttachSurface(surfaceHandle: Long): Boolean

    /** Submit a YUV frame to the bgfx render queue. */
    @JvmStatic
    external fun nativeSubmitFrame(
        y: ByteArray,
        u: ByteArray,
        v: ByteArray,
        width: Int,
        height: Int,
        timestampNs: Long,
    ): Boolean

    /** Detach the current surface from the bgfx renderer and release resources. */
    @JvmStatic
    external fun nativeDetachSurface()
}
