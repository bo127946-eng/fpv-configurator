package com.example.xfire

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val DFU_CHANNEL_NAME = "xfire/dfu"
        private const val ACTION_USB_PERMISSION = "com.example.xfire.DFU_USB_PERMISSION"
        private const val STM32_VID = 0x0483
        private const val STM32_DFU_PID = 0xDF11

        private const val DFU_DNLOAD: Byte = 0x01
        private const val DFU_GETSTATUS: Byte = 0x03
        private const val DFU_CLRSTATUS: Byte = 0x04

        private const val STATE_DFU_IDLE = 2
        private const val STATE_DFU_DNLOAD_SYNC = 3
        private const val STATE_DFU_DNBUSY = 4
        private const val STATE_DFU_MANIFEST_WAIT_RESET = 8
        private const val STATE_DFU_ERROR = 10
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val dfuExecutor = Executors.newSingleThreadExecutor()
    private var dfuChannel: MethodChannel? = null

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var permissionReceiverRegistered = false

    private val permissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != ACTION_USB_PERMISSION) return
            val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
            }
            val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false) ||
                (device != null && getUsbManager().hasPermission(device))

            val callback = pendingPermissionResult
            pendingPermissionResult = null
            if (callback != null) {
                mainHandler.post { callback.success(granted) }
            }
        }
    }

    private fun getUsbManager(): UsbManager {
        return getSystemService(Context.USB_SERVICE) as UsbManager
    }

    private fun findTargetDfuDevice(usbManager: UsbManager): UsbDevice? {
        return usbManager.deviceList.values.firstOrNull { dev ->
            dev.vendorId == STM32_VID && dev.productId == STM32_DFU_PID
        }
    }

    private fun ensurePermissionReceiver() {
        if (permissionReceiverRegistered) return
        val filter = IntentFilter(ACTION_USB_PERMISSION)
        ContextCompat.registerReceiver(
            this,
            permissionReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
        permissionReceiverRegistered = true
    }

    private fun reportProgress(status: String, progress: Double) {
        mainHandler.post {
            dfuChannel?.invokeMethod(
                "onDfuProgress",
                mapOf(
                    "status" to status,
                    "progress" to progress.coerceIn(0.0, 1.0)
                )
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ensurePermissionReceiver()

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DFU_CHANNEL_NAME)
        dfuChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "findDfuDevice" -> {
                    val dev = findTargetDfuDevice(getUsbManager())
                    if (dev == null) {
                        result.success(null)
                    } else {
                        result.success(
                            mapOf(
                                "deviceName" to dev.deviceName,
                                "vendorId" to dev.vendorId,
                                "productId" to dev.productId,
                                "deviceId" to dev.deviceId
                            )
                        )
                    }
                }

                "requestDfuPermission" -> {
                    val usbManager = getUsbManager()
                    val dev = findTargetDfuDevice(usbManager)
                    if (dev == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    if (usbManager.hasPermission(dev)) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    if (pendingPermissionResult != null) {
                        result.error("PERMISSION_IN_PROGRESS", "Запрос USB-разрешения уже выполняется", null)
                        return@setMethodCallHandler
                    }

                    pendingPermissionResult = result
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                    val intent = Intent(ACTION_USB_PERMISSION).apply { setPackage(packageName) }
                    val pendingIntent = PendingIntent.getBroadcast(this, 0, intent, flags)
                    usbManager.requestPermission(dev, pendingIntent)
                }

                "flashF401" -> {
                    val firmware = call.argument<ByteArray>("firmware")
                    val startAddress = call.argument<Int>("startAddress") ?: 0x08000000
                    if (firmware == null || firmware.isEmpty()) {
                        result.error("NO_FIRMWARE", "Пустой буфер прошивки", null)
                        return@setMethodCallHandler
                    }

                    dfuExecutor.execute {
                        try {
                            flashStm32Dfu(firmware, startAddress.toLong() and 0xFFFFFFFFL)
                            mainHandler.post { result.success(true) }
                        } catch (ex: Exception) {
                            mainHandler.post {
                                result.error("DFU_ERROR", ex.message ?: "Ошибка прошивки DFU", null)
                            }
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        dfuChannel?.setMethodCallHandler(null)
        dfuChannel = null
        pendingPermissionResult = null
        if (permissionReceiverRegistered) {
            try {
                unregisterReceiver(permissionReceiver)
            } catch (_: Exception) {
            }
            permissionReceiverRegistered = false
        }
        dfuExecutor.shutdownNow()
        super.onDestroy()
    }

    private data class DfuStatus(
        val status: Int,
        val pollTimeoutMs: Int,
        val state: Int
    )

    private fun flashStm32Dfu(firmware: ByteArray, startAddress: Long) {
        val usbManager = getUsbManager()
        val device = findTargetDfuDevice(usbManager)
            ?: throw IllegalStateException("STM32F401 в режиме DFU не найден")

        if (!usbManager.hasPermission(device)) {
            throw SecurityException("Нет USB-разрешения для DFU-устройства")
        }

        var dfuInterface: UsbInterface? = null
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            if (intf.interfaceClass == 0xFE && intf.interfaceSubclass == 0x01) {
                dfuInterface = intf
                break
            }
        }
        val targetInterface = dfuInterface ?: device.getInterface(0)
        val interfaceId = targetInterface.id

        val connection: UsbDeviceConnection = usbManager.openDevice(device)
            ?: throw IllegalStateException("Не удалось открыть USB-соединение с DFU")

        try {
            if (!connection.claimInterface(targetInterface, true)) {
                throw IllegalStateException("Не удалось захватить DFU-интерфейс")
            }

            val st = dfuGetStatus(connection, interfaceId)
            if (st.state == STATE_DFU_ERROR) {
                dfuClrStatus(connection, interfaceId)
                dfuGetStatus(connection, interfaceId)
            }

            reportProgress("Стирание Flash STM32F401...", 0.12)
            dfuSetAddressPointer(connection, interfaceId, startAddress)
            dfuEraseSector(connection, interfaceId, startAddress)

            val blockSize = 1024
            var offset = 0
            var blockNum = 2
            val totalBytes = firmware.size

            while (offset < totalBytes) {
                val chunkLen = minOf(blockSize, totalBytes - offset)
                val chunk = firmware.copyOfRange(offset, offset + chunkLen)

                dfuDnload(connection, interfaceId, blockNum, chunk)
                waitUntilNotBusy(connection, interfaceId)

                val statusAfterWrite = dfuGetStatus(connection, interfaceId)
                if (statusAfterWrite.state == STATE_DFU_ERROR) {
                    throw IllegalStateException("Ошибка записи DFU на блоке $blockNum (status=${statusAfterWrite.status})")
                }

                offset += chunkLen
                blockNum++
                val writeRatio = offset.toDouble() / totalBytes.toDouble()
                reportProgress(
                    "Запись прошивки: ${offset / 1024}/${totalBytes / 1024} КБ...",
                    0.18 + writeRatio * 0.72
                )
            }

            reportProgress("Завершение и перезапуск STM32F401...", 0.95)
            dfuDnload(connection, interfaceId, 0, ByteArray(0))
            for (_ in 0..5) {
                try {
                    val endStatus = dfuGetStatus(connection, interfaceId)
                    val waitMs = endStatus.pollTimeoutMs.coerceIn(10, 500).toLong()
                    Thread.sleep(waitMs)
                    if (endStatus.state == STATE_DFU_MANIFEST_WAIT_RESET || endStatus.state == STATE_DFU_IDLE) {
                        break
                    }
                } catch (_: Exception) {
                    break
                }
            }

            reportProgress("Прошивка STM32F401 завершена!", 1.0)
        } finally {
            try {
                connection.releaseInterface(targetInterface)
            } catch (_: Exception) {
            }
            try {
                connection.close()
            } catch (_: Exception) {
            }
        }
    }

    private fun dfuSetAddressPointer(connection: UsbDeviceConnection, interfaceId: Int, address: Long) {
        val cmd = ByteBuffer.allocate(5).order(ByteOrder.LITTLE_ENDIAN).apply {
            put(0x21.toByte())
            put((address and 0xFFL).toByte())
            put(((address ushr 8) and 0xFFL).toByte())
            put(((address ushr 16) and 0xFFL).toByte())
            put(((address ushr 24) and 0xFFL).toByte())
        }.array()
        dfuDnload(connection, interfaceId, 0, cmd)
        waitUntilNotBusy(connection, interfaceId)
    }

    private fun dfuEraseSector(connection: UsbDeviceConnection, interfaceId: Int, sectorAddress: Long) {
        val cmd = ByteBuffer.allocate(5).order(ByteOrder.LITTLE_ENDIAN).apply {
            put(0x41.toByte())
            put((sectorAddress and 0xFFL).toByte())
            put(((sectorAddress ushr 8) and 0xFFL).toByte())
            put(((sectorAddress ushr 16) and 0xFFL).toByte())
            put(((sectorAddress ushr 24) and 0xFFL).toByte())
        }.array()
        dfuDnload(connection, interfaceId, 0, cmd)
        waitUntilNotBusy(connection, interfaceId)
    }

    private fun dfuDnload(
        connection: UsbDeviceConnection,
        interfaceId: Int,
        blockNum: Int,
        data: ByteArray
    ) {
        val requestType = UsbConstants.USB_TYPE_CLASS or UsbConstants.USB_DIR_OUT
        val sent = connection.controlTransfer(
            requestType,
            DFU_DNLOAD.toInt(),
            blockNum,
            interfaceId,
            if (data.isEmpty()) null else data,
            data.size,
            2500
        )
        if (sent < 0) {
            throw IllegalStateException("Сбой DFU_DNLOAD (block=$blockNum)")
        }
    }

    private fun dfuClrStatus(connection: UsbDeviceConnection, interfaceId: Int) {
        val requestType = UsbConstants.USB_TYPE_CLASS or UsbConstants.USB_DIR_OUT
        connection.controlTransfer(
            requestType,
            DFU_CLRSTATUS.toInt(),
            0,
            interfaceId,
            null,
            0,
            1500
        )
    }

    private fun dfuGetStatus(connection: UsbDeviceConnection, interfaceId: Int): DfuStatus {
        val buf = ByteArray(6)
        val requestType = UsbConstants.USB_TYPE_CLASS or UsbConstants.USB_DIR_IN
        val read = connection.controlTransfer(
            requestType,
            DFU_GETSTATUS.toInt(),
            0,
            interfaceId,
            buf,
            buf.size,
            1500
        )
        if (read < 6) {
            throw IllegalStateException("Сбой DFU_GETSTATUS (read=$read)")
        }
        val statusCode = buf[0].toInt() and 0xFF
        val pollTimeoutMs = (buf[1].toInt() and 0xFF) or
            ((buf[2].toInt() and 0xFF) shl 8) or
            ((buf[3].toInt() and 0xFF) shl 16)
        val state = buf[4].toInt() and 0xFF
        return DfuStatus(statusCode, pollTimeoutMs, state)
    }

    private fun waitUntilNotBusy(connection: UsbDeviceConnection, interfaceId: Int) {
        for (_ in 0..120) {
            val st = dfuGetStatus(connection, interfaceId)
            val sleepMs = st.pollTimeoutMs.coerceIn(5, 300).toLong()
            Thread.sleep(sleepMs)
            if (st.state != STATE_DFU_DNBUSY && st.state != STATE_DFU_DNLOAD_SYNC) {
                return
            }
        }
        throw IllegalStateException("Таймаут ожидания готовности STM32 DFU")
    }
}
