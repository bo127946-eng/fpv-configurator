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
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "xfire/dfu"
        private const val ACTION_USB_PERMISSION = "com.example.xfire.USB_DFU_PERMISSION"

        private const val STM32_VID = 0x0483
        private const val STM32_DFU_PID = 0xDF11

        private const val USB_DIR_OUT = 0x00
        private const val USB_DIR_IN = 0x80
        private const val USB_TYPE_CLASS = 0x20
        private const val USB_RECIP_INTERFACE = 0x01

        private const val REQ_DETACH: Byte = 0x00
        private const val REQ_DNLOAD: Byte = 0x01
        private const val REQ_UPLOAD: Byte = 0x02
        private const val REQ_GETSTATUS: Byte = 0x03
        private const val REQ_CLRSTATUS: Byte = 0x04
        private const val REQ_GETSTATE: Byte = 0x05
        private const val REQ_ABORT: Byte = 0x06

        private const val STATE_APP_IDLE = 0
        private const val STATE_APP_DETACH = 1
        private const val STATE_DFU_IDLE = 2
        private const val STATE_DFU_DNLOAD_SYNC = 3
        private const val STATE_DFU_DNBUSY = 4
        private const val STATE_DFU_DNLOAD_IDLE = 5
        private const val STATE_DFU_MANIFEST_SYNC = 6
        private const val STATE_DFU_MANIFEST = 7
        private const val STATE_DFU_MANIFEST_WAIT_RESET = 8
        private const val STATE_DFU_UPLOAD_IDLE = 9
        private const val STATE_DFU_ERROR = 10

        private const val FLASH_START_ADDR = 0x08000000
        private const val DFU_XFER_SIZE = 2048
    }

    private data class DfuStatus(
        val status: Int,
        val pollTimeoutMs: Int,
        val state: Int,
        val iString: Int
    )

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var permissionReceiver: BroadcastReceiver? = null
    private var permissionTimeoutRunnable: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "findDfuDevice" -> handleFindDfuDevice(result)
                "requestDfuPermission" -> handleRequestDfuPermission(result)
                "flashF401" -> {
                    val args = call.arguments as? Map<*, *>
                    val firmware = args?.get("firmware") as? ByteArray
                    val startAddress = (args?.get("startAddress") as? Number)?.toInt() ?: FLASH_START_ADDR
                    if (firmware == null || firmware.isEmpty()) {
                        result.error("INVALID_ARGS", "Пустой буфер прошивки (firmware)", null)
                    } else {
                        handleFlashF401(firmware, startAddress, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun postProgress(status: String, progress: Double) {
        mainHandler.post {
            methodChannel?.invokeMethod(
                "onDfuProgress",
                mapOf(
                    "status" to status,
                    "progress" to progress.coerceIn(0.0, 1.0)
                )
            )
        }
    }

    private fun getUsbManager(): UsbManager =
        getSystemService(Context.USB_SERVICE) as UsbManager

    private fun findStm32DfuDevice(usbManager: UsbManager): UsbDevice? {
        val deviceList = usbManager.deviceList.values
        deviceList.firstOrNull { it.vendorId == STM32_VID && it.productId == STM32_DFU_PID }?.let {
            return it
        }
        return deviceList.firstOrNull { dev ->
            for (i in 0 until dev.interfaceCount) {
                val intf = dev.getInterface(i)
                if (intf.interfaceClass == UsbConstants.USB_CLASS_APP_SPEC &&
                    intf.interfaceSubclass == 0x01
                ) {
                    return@firstOrNull true
                }
            }
            false
        }
    }

    private fun handleFindDfuDevice(result: MethodChannel.Result) {
        executor.execute {
            try {
                val usbManager = getUsbManager()
                val dev = findStm32DfuDevice(usbManager)
                val map = dev?.let {
                    mapOf(
                        "deviceId" to it.deviceId,
                        "deviceName" to it.deviceName,
                        "productName" to (it.productName ?: "STM32 DFU"),
                        "vendorId" to it.vendorId,
                        "productId" to it.productId,
                        "hasPermission" to usbManager.hasPermission(it)
                    )
                }
                mainHandler.post { result.success(map) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("FIND_ERROR", "Ошибка поиска DFU устройства: ${e.message}", null)
                }
            }
        }
    }

    private fun cleanupPermissionReceiver() {
        permissionTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        permissionTimeoutRunnable = null
        permissionReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        permissionReceiver = null
    }

    private fun handleRequestDfuPermission(result: MethodChannel.Result) {
        mainHandler.post {
            val usbManager = getUsbManager()
            val dev = findStm32DfuDevice(usbManager)
            if (dev == null) {
                result.success(false)
                return@post
            }

            if (usbManager.hasPermission(dev)) {
                postProgress("USB-разрешение получено, стабилизация шины...", 0.06)
                result.success(true)
                return@post
            }

            if (pendingPermissionResult != null) {
                result.error("PERMISSION_BUSY", "Запрос USB-разрешения уже выполняется", null)
                return@post
            }

            pendingPermissionResult = result
            cleanupPermissionReceiver()

            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action != ACTION_USB_PERMISSION) return
                    val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                    cleanupPermissionReceiver()
                    val pending = pendingPermissionResult
                    pendingPermissionResult = null
                    if (granted) {
                        postProgress("USB-разрешение получено, стабилизация шины...", 0.06)
                    }
                    pending?.success(granted)
                }
            }
            permissionReceiver = receiver

            val filter = IntentFilter(ACTION_USB_PERMISSION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(receiver, filter)
            }

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val intent = Intent(ACTION_USB_PERMISSION).apply {
                setPackage(packageName)
            }
            val pendingIntent = PendingIntent.getBroadcast(this, 0, intent, flags)

            val timeoutRunnable = Runnable {
                val grantedNow = getUsbManager().hasPermission(dev)
                cleanupPermissionReceiver()
                val pending = pendingPermissionResult
                pendingPermissionResult = null
                pending?.success(grantedNow)
            }
            permissionTimeoutRunnable = timeoutRunnable
            mainHandler.postDelayed(timeoutRunnable, 30_000L)

            usbManager.requestPermission(dev, pendingIntent)
        }
    }

    private fun handleFlashF401(firmware: ByteArray, startAddress: Int, result: MethodChannel.Result) {
        executor.execute {
            var connection: UsbDeviceConnection? = null
            var claimedInterface: UsbInterface? = null
            try {
                val usbManager = getUsbManager()
                val device = findStm32DfuDevice(usbManager)
                    ?: throw IllegalStateException("STM32F401 в режиме DFU не найден")

                if (!usbManager.hasPermission(device)) {
                    throw SecurityException("Нет USB-разрешения для DFU устройства")
                }

                postProgress("Открытие USB соединения с STM32 DFU...", 0.12)
                var dfuInterface: UsbInterface? = null
                for (i in 0 until device.interfaceCount) {
                    val candidate = device.getInterface(i)
                    if (candidate.interfaceClass == UsbConstants.USB_CLASS_APP_SPEC &&
                        candidate.interfaceSubclass == 0x01
                    ) {
                        dfuInterface = candidate
                        break
                    }
                }
                val targetInterface = dfuInterface ?: device.getInterface(0)
                    ?: throw IllegalStateException("DFU интерфейс не найден")

                val conn = usbManager.openDevice(device)
                    ?: throw IllegalStateException("Не удалось открыть UsbDeviceConnection")
                connection = conn

                if (!conn.claimInterface(targetInterface, true)) {
                    throw IllegalStateException("Не удалось захватить DFU интерфейс #${targetInterface.id}")
                }
                claimedInterface = targetInterface
                val interfaceId = targetInterface.id

                Thread.sleep(150)

                var status = getDfuStatus(conn, interfaceId, timeoutMs = 2000)
                if (status.state == STATE_DFU_ERROR) {
                    postProgress("DFU_CLRSTATUS: сброс ошибки DFU...", 0.14)
                    clearDfuStatus(conn, interfaceId)
                    Thread.sleep(100)
                    status = getDfuStatus(conn, interfaceId, timeoutMs = 2000)
                }
                if (status.state == STATE_APP_IDLE) {
                    postProgress("DFU_DETACH: перевод в DFU_IDLE...", 0.15)
                    detachApp(conn, interfaceId)
                    Thread.sleep(300)
                    status = getDfuStatus(conn, interfaceId, timeoutMs = 2000)
                }

                // Стирание секторов STM32F401 (0x08000000..0x0803FFFF) в зависимости от размера прошивки
                val sectorsToErase = getF401SectorsForRange(startAddress, firmware.size)
                val totalSectors = sectorsToErase.size.coerceAtLeast(1)

                for ((idx, sectorAddr) in sectorsToErase.withIndex()) {
                    val eraseProgress = 0.16 + (0.24 * (idx.toDouble() / totalSectors.toDouble()))
                    postProgress(
                        "DFU_ERASE: стирание сектора 0x${sectorAddr.toUInt().toString(16).uppercase()} (${idx + 1}/$totalSectors)...",
                        eraseProgress
                    )
                    erasePage(conn, interfaceId, sectorAddr)
                    waitUntilReady(conn, interfaceId, extraWaitMs = 900, maxWaitMs = 8000)
                }

                // Установка адреса записи (wBlockNum = 0, команда 0x21)
                postProgress("DFU_DNLOAD: установка адреса 0x${startAddress.toUInt().toString(16).uppercase()}...", 0.41)
                setAddressPointer(conn, interfaceId, startAddress)
                waitUntilReady(conn, interfaceId, extraWaitMs = 60, maxWaitMs = 3000)

                // Запись блоков начиная с wBlockNum = 2 (по протоколу AN3156)
                val totalBlocks = ((firmware.size + DFU_XFER_SIZE - 1) / DFU_XFER_SIZE).coerceAtLeast(1)
                var offset = 0
                var blockIndex = 0
                while (offset < firmware.size) {
                    val chunkSize = minOf(DFU_XFER_SIZE, firmware.size - offset)
                    val chunk = firmware.copyOfRange(offset, offset + chunkSize)
                    val wBlockNum = blockIndex + 2

                    val writeProgress = 0.42 + (0.50 * ((blockIndex + 1).toDouble() / totalBlocks.toDouble()))
                    postProgress(
                        "DFU_DNLOAD: запись блока ${blockIndex + 1}/$totalBlocks ($chunkSize Б)...",
                        writeProgress
                    )

                    dnloadBlock(conn, interfaceId, wBlockNum, chunk)
                    waitUntilReady(conn, interfaceId, extraWaitMs = 60, maxWaitMs = 4000)

                    offset += chunkSize
                    blockIndex++
                }

                // Завершение передачи (нулевой пакет DNLOAD) и выход из DFU (Manifest)
                postProgress("DFU_MANIFEST: завершение записи и запуск прошивки...", 0.94)
                dnloadBlock(conn, interfaceId, 2, ByteArray(0))
                try {
                    getDfuStatus(conn, interfaceId, timeoutMs = 2000)
                } catch (_: Exception) {
                }

                postProgress("DFU_MANIFEST: перезагрузка STM32F401...", 0.98)
                try {
                    Thread.sleep(250)
                } catch (_: Exception) {
                }

                postProgress("Прошивка STM32F401 успешно завершена!", 1.0)
                mainHandler.post { result.success(true) }
            } catch (e: Exception) {
                val msg = e.message ?: e.javaClass.simpleName
                postProgress("Ошибка DFU: $msg", 0.0)
                mainHandler.post {
                    result.error("DFU_ERROR", msg, null)
                }
            } finally {
                try {
                    if (connection != null && claimedInterface != null) {
                        connection.releaseInterface(claimedInterface)
                    }
                } catch (_: Exception) {
                }
                try {
                    connection?.close()
                } catch (_: Exception) {
                }
            }
        }
    }

    private fun getF401SectorsForRange(startAddr: Int, length: Int): List<Int> {
        val endAddr = startAddr.toLong() + length.coerceAtLeast(1).toLong() - 1L
        val sectorMap = listOf(
            0x08000000L to 0x08003FFFL, // Sector 0: 16 KB
            0x08004000L to 0x08007FFFL, // Sector 1: 16 KB
            0x08008000L to 0x0800BFFFL, // Sector 2: 16 KB
            0x0800C000L to 0x0800FFFFL, // Sector 3: 16 KB
            0x08010000L to 0x0801FFFFL, // Sector 4: 64 KB
            0x08020000L to 0x0803FFFFL  // Sector 5: 128 KB
        )
        val matched = sectorMap
            .filter { (sStart, sEnd) -> endAddr >= sStart && startAddr.toLong() <= sEnd }
            .map { it.first.toInt() }
        return if (matched.isEmpty()) listOf(0x08000000) else matched
    }

    private fun detachApp(conn: UsbDeviceConnection, interfaceId: Int) {
        val sent = conn.controlTransfer(
            USB_DIR_OUT or USB_TYPE_CLASS or USB_RECIP_INTERFACE,
            REQ_DETACH.toInt(),
            0,
            interfaceId,
            null,
            0,
            1000
        )
        if (sent < 0) throw IllegalStateException("Сбой DFU_DETACH ($sent)")
    }

    private fun clearDfuStatus(conn: UsbDeviceConnection, interfaceId: Int) {
        val sent = conn.controlTransfer(
            USB_DIR_OUT or USB_TYPE_CLASS or USB_RECIP_INTERFACE,
            REQ_CLRSTATUS.toInt(),
            0,
            interfaceId,
            null,
            0,
            1000
        )
        if (sent < 0) throw IllegalStateException("Сбой DFU_CLRSTATUS ($sent)")
    }

    private fun getDfuStatus(conn: UsbDeviceConnection, interfaceId: Int, timeoutMs: Int = 1500): DfuStatus {
        val buf = ByteArray(6)
        val read = conn.controlTransfer(
            USB_DIR_IN or USB_TYPE_CLASS or USB_RECIP_INTERFACE,
            REQ_GETSTATUS.toInt(),
            0,
            interfaceId,
            buf,
            buf.size,
            timeoutMs
        )
        if (read < 6) {
            throw IllegalStateException("Сбой DFU_GETSTATUS (прочитано $read байт)")
        }
        val bStatus = buf[0].toInt() and 0xFF
        val pollTimeout = ((buf[1].toInt() and 0xFF)) or
            ((buf[2].toInt() and 0xFF) shl 8) or
            ((buf[3].toInt() and 0xFF) shl 16)
        val bState = buf[4].toInt() and 0xFF
        val iString = buf[5].toInt() and 0xFF
        return DfuStatus(bStatus, pollTimeout, bState, iString)
    }

    private fun erasePage(conn: UsbDeviceConnection, interfaceId: Int, pageAddr: Int) {
        val cmd = ByteArray(5)
        cmd[0] = 0x41.toByte() // Erase command (AN3156)
        val addrBuf = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(pageAddr).array()
        System.arraycopy(addrBuf, 0, cmd, 1, 4)
        dnloadBlock(conn, interfaceId, 0, cmd)
    }

    private fun setAddressPointer(conn: UsbDeviceConnection, interfaceId: Int, address: Int) {
        val cmd = ByteArray(5)
        cmd[0] = 0x21.toByte() // Set Address Pointer (AN3156)
        val addrBuf = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(address).array()
        System.arraycopy(addrBuf, 0, cmd, 1, 4)
        dnloadBlock(conn, interfaceId, 0, cmd)
    }

    private fun dnloadBlock(conn: UsbDeviceConnection, interfaceId: Int, wBlockNum: Int, data: ByteArray) {
        val sent = conn.controlTransfer(
            USB_DIR_OUT or USB_TYPE_CLASS or USB_RECIP_INTERFACE,
            REQ_DNLOAD.toInt(),
            wBlockNum,
            interfaceId,
            if (data.isEmpty()) null else data,
            data.size,
            3000
        )
        if (sent < 0) {
            throw IllegalStateException("Сбой DFU_DNLOAD (wBlockNum=$wBlockNum, ret=$sent)")
        }
    }

    private fun waitUntilReady(
        conn: UsbDeviceConnection,
        interfaceId: Int,
        extraWaitMs: Long = 50L,
        maxWaitMs: Long = 6000L
    ) {
        val deadline = System.currentTimeMillis() + maxWaitMs
        var lastStatus: DfuStatus? = null

        while (System.currentTimeMillis() < deadline) {
            val st = getDfuStatus(conn, interfaceId, timeoutMs = 2000)
            lastStatus = st

            if (st.state == STATE_DFU_ERROR) {
                try {
                    clearDfuStatus(conn, interfaceId)
                } catch (_: Exception) {
                }
                throw IllegalStateException("Ошибка DFU контроллера (status=0x${st.status.toString(16)})")
            }

            if (st.state != STATE_DFU_DNBUSY && st.state != STATE_DFU_MANIFEST_SYNC && st.state != STATE_DFU_MANIFEST) {
                if (extraWaitMs > 0) {
                    Thread.sleep(extraWaitMs)
                }
                return
            }

            val stepSleep = st.pollTimeoutMs.toLong().coerceIn(25L, 250L)
            val remaining = (deadline - System.currentTimeMillis()).coerceAtLeast(0L)
            if (remaining <= 0L) break
            Thread.sleep(minOf(stepSleep, remaining))
        }

        throw IllegalStateException(
            "Таймаут ожидания готовности STM32 DFU (state=${lastStatus?.state}, status=${lastStatus?.status}, poll=${lastStatus?.pollTimeoutMs}ms)"
        )
    }

    override fun onDestroy() {
        cleanupPermissionReceiver()
        pendingPermissionResult = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        executor.shutdownNow()
        super.onDestroy()
    }
}
