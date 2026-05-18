package com.app.rtmp_stream

import android.app.Activity
import android.content.Context
import android.graphics.ImageFormat
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.hardware.camera2.params.StreamConfigurationMap
import android.media.CamcorderProfile
import android.os.Build
import android.util.Log
import android.util.Size
import androidx.annotation.RequiresApi
import com.app.rtmp_stream.CameraPermissions.ResolutionPreset
import com.pedro.common.secureGet
import java.util.*

/** Provides various utilities for camera.  */
object CameraUtils {
    /**
     * 与 iOS 对齐的预设目标分辨率 (width x height)。
     * 同一 resolutionPreset 在 Android 与 iOS 上得到相同或最接近的分辨率。
     */
    private fun getTargetSizeForPreset(preset: ResolutionPreset): Pair<Int, Int> = when (preset) {
        ResolutionPreset.low -> Pair(352, 288)       // CIF
        ResolutionPreset.medium -> Pair(640, 480)    // VGA
        ResolutionPreset.high -> Pair(1280, 720)      // 720p
        ResolutionPreset.veryHigh -> Pair(1920, 1080) // 1080p
        ResolutionPreset.ultraHigh -> Pair(3840, 2160) // 4K
        ResolutionPreset.max -> Pair(Int.MAX_VALUE, Int.MAX_VALUE) // 取设备最大
    }

    /** 从可用尺寸中选取最接近目标 (targetW, targetH) 的尺寸；max 时取面积最大。 */
    private fun selectClosestSize(available: Array<Size>, preset: ResolutionPreset): Size {
        if (available.isEmpty()) throw IllegalArgumentException("No available sizes")
        val (targetW, targetH) = getTargetSizeForPreset(preset)
        return if (preset == ResolutionPreset.max) {
            available.maxWithOrNull(CompareSizesByArea()) ?: available.first()
        } else {
            available.minByOrNull { size ->
                val dw = size.width - targetW
                val dh = size.height - targetH
                dw * dw + dh * dh
            } ?: available.first()
        }
    }

    /**
     * Escolhe resolução cuja proporção (em retrato) é a mais próxima do ecrã do telemóvel,
     * limitada ao preset, para reduzir esticamento no preview.
     */
    private fun selectClosestSizeForScreen(
        activity: Activity?,
        available: Array<Size>,
        preset: ResolutionPreset,
    ): Size {
        if (available.isEmpty()) throw IllegalArgumentException("No available sizes")
        val (maxW, maxH) = getTargetSizeForPreset(preset)
        val metrics = activity?.resources?.displayMetrics
        val screenAspect = if (metrics != null && metrics.heightPixels > 0) {
            metrics.widthPixels.toFloat() / metrics.heightPixels.toFloat()
        } else {
            9f / 16f
        }
        val candidates = available.filter { s ->
            s.width <= maxW && s.height <= maxH
        }.ifEmpty { available.toList() }
        return candidates.minByOrNull { s ->
            val portraitAspect = if (s.width > s.height) {
                s.height.toFloat() / s.width.toFloat()
            } else {
                s.width.toFloat() / s.height.toFloat()
            }
            val d = portraitAspect - screenAspect
            d * d
        } ?: selectClosestSize(available, preset)
    }

    private fun align16(value: Int): Int = (value + 15) / 16 * 16

    /** Alinha dimensões a múltiplos de 16 (exigência comum em encoders Qualcomm/MediaCodec). */
    fun alignSize16(size: Size): Size = Size(
        align16(size.width),
        align16(size.height),
    )

    /**
     * Resolução para encode/stream: preset padrão (paisagem), sem usar tamanho do ecrã Flutter.
     * Evita falhas do OMX quando o encoder recebe dimensões do widget (ex. 576x1248).
     */
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun computeEncoderSize(
        activity: Activity?,
        cameraName: String,
        presetArg: ResolutionPreset,
    ): Size {
        val sizeList = getCameraResolutions(activity, cameraName)
        val raw = if (sizeList.isNotEmpty()) {
            selectClosestSize(sizeList, presetArg)
        } else {
            var preset = presetArg
            if (preset.ordinal > ResolutionPreset.high.ordinal) {
                preset = ResolutionPreset.high
            }
            val profile = getBestAvailableCamcorderProfileForResolutionPreset(cameraName, preset)
            Size(profile.videoFrameWidth, profile.videoFrameHeight)
        }
        return alignSize16(raw)
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun computeBestPreviewSize(activity: Activity?,cameraName: String, presetArg: ResolutionPreset): Map<String,Any> {
        val sizeList = getCameraResolutions(activity, cameraName)
        val size: Size
        val bitrate: Int
        if (sizeList.isNotEmpty()) {
            size = selectClosestSizeForScreen(activity, sizeList, presetArg)
            bitrate = 1200 * 1000
        } else {
            var preset = presetArg
            if (preset.ordinal > ResolutionPreset.high.ordinal) {
                preset = ResolutionPreset.high
            }
            val profile = getBestAvailableCamcorderProfileForResolutionPreset(cameraName, preset)
            size = Size(profile.videoFrameWidth, profile.videoFrameHeight)
            bitrate = profile.videoBitRate
        }
        val map = HashMap<String, Any>()
        map["size"] = size
        map["bitrate"] = bitrate
        return map
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun computeBestCaptureSize(streamConfigurationMap: StreamConfigurationMap): Size {
        // For still image captures, we use the largest available size.
        return Collections.max(
            Arrays.asList(*streamConfigurationMap.getOutputSizes(ImageFormat.JPEG)),
            CompareSizesByArea())
    }

    @Throws(CameraAccessException::class)
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun getAvailableCameras(activity: Activity): List<Map<String, Any>> {
        val cameraManager = activity.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val cameraNames = cameraManager.cameraIdList
        val cameras: MutableList<Map<String, Any>> = ArrayList()
        for (cameraName in cameraNames) {
            val details = HashMap<String, Any>()
            val characteristics = cameraManager.getCameraCharacteristics(cameraName)
            details["name"] = cameraName
            val sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION)
            details["sensorOrientation"] = sensorOrientation!!
            val lensFacing = characteristics.get(CameraCharacteristics.LENS_FACING)
            when (lensFacing) {
                CameraMetadata.LENS_FACING_FRONT -> details["lensFacing"] = "front"
                CameraMetadata.LENS_FACING_BACK -> details["lensFacing"] = "back"
                CameraMetadata.LENS_FACING_EXTERNAL -> details["lensFacing"] = "external"
            }
            cameras.add(details)
        }
        return cameras
    }
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun getCameraResolutions(activity: Activity?,cameraId: String): Array<Size> {
        try {
            val cameraManager = activity?.getSystemService(Context.CAMERA_SERVICE) as? CameraManager ?: return arrayOf()
            val characteristics = cameraManager.getCameraCharacteristics(cameraId)
            val streamConfigurationMap = characteristics.secureGet(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP) ?: return arrayOf()
            val outputSizes = streamConfigurationMap.getOutputSizes(SurfaceTexture::class.java)
            return outputSizes ?: arrayOf()
        } catch (e: Exception) {
            Log.d("error",e.message ?: "")
            return arrayOf()
        }
    }
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun getBestAvailableCamcorderProfileForResolutionPreset(
        cameraName: String, preset: ResolutionPreset?): CamcorderProfile {
        val cameraId = cameraName.toInt()

        return when (preset) {
            ResolutionPreset.max -> {
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_HIGH)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_HIGH)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_2160P)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_2160P)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_1080P)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_1080P)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_720P)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_720P)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_480P)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_480P)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_QVGA)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_QVGA)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_LOW)) {
                    CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_LOW)
                } else {
                    throw IllegalArgumentException(
                        "No capture session available for current capture session.")
                }
            }
            ResolutionPreset.ultraHigh -> {
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_2160P)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_2160P)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_1080P)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_1080P)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_720P)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_720P)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_480P)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_480P)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_QVGA)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_QVGA)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_LOW)) {
                    CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_LOW)
                } else {
                    throw IllegalArgumentException(
                        "No capture session available for current capture session.")
                }
            }
            ResolutionPreset.veryHigh -> {
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_1080P)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_1080P)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_720P)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_720P)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_480P)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_480P)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_QVGA)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_QVGA)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_LOW)) {
                    CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_LOW)
                } else {
                    throw IllegalArgumentException(
                        "No capture session available for current capture session.")
                }
            }
            ResolutionPreset.high -> {
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_720P)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_720P)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_480P)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_480P)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_QVGA)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_QVGA)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_LOW)) {
                    CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_LOW)
                } else {
                    throw IllegalArgumentException(
                        "No capture session available for current capture session.")
                }
            }
            ResolutionPreset.medium -> {
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_480P)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_480P)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_QVGA)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_QVGA)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_LOW)) {
                    CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_LOW)
                } else {
                    throw IllegalArgumentException(
                        "No capture session available for current capture session.")
                }
            }
            ResolutionPreset.low -> {
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_QVGA)) {
                    return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_QVGA)
                }
                if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_LOW)) {
                    CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_LOW)
                } else {
                    throw IllegalArgumentException(
                        "No capture session available for current capture session.")
                }
            }
            else -> if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_LOW)) {
                CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_LOW)
            } else {
                throw IllegalArgumentException(
                    "No capture session available for current capture session.")
            }
        }
    }

    private class CompareSizesByArea : Comparator<Size> {
        override fun compare(lhs: Size, rhs: Size): Int {
            // We cast here to ensure the multiplications won't overflow.
            return java.lang.Long.signum(
                lhs.width.toLong() * lhs.height - rhs.width.toLong() * rhs.height)
        }
    }
}