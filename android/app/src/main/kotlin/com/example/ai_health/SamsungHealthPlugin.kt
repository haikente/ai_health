package com.example.ai_health

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.text.SimpleDateFormat
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.Instant
import java.util.*

// Samsung Health Data SDK Imports
import com.samsung.android.sdk.health.data.HealthDataService
import com.samsung.android.sdk.health.data.HealthDataStore
import com.samsung.android.sdk.health.data.permission.AccessType
import com.samsung.android.sdk.health.data.permission.Permission
import com.samsung.android.sdk.health.data.request.DataType
import com.samsung.android.sdk.health.data.request.DataType.StepsType
import com.samsung.android.sdk.health.data.request.DataType.HeartRateType
import com.samsung.android.sdk.health.data.request.DataType.SleepType
import com.samsung.android.sdk.health.data.request.DataType.SleepType.StageType
import com.samsung.android.sdk.health.data.request.DataType.ActivitySummaryType
import com.samsung.android.sdk.health.data.request.DataType.BloodPressureType
import com.samsung.android.sdk.health.data.request.DataType.BloodGlucoseType
import com.samsung.android.sdk.health.data.request.DataType.BloodOxygenType
import com.samsung.android.sdk.health.data.request.DataType.BodyTemperatureType
import com.samsung.android.sdk.health.data.request.DataType.BodyCompositionType
import com.samsung.android.sdk.health.data.request.DataType.UserProfileDataType
import com.samsung.android.sdk.health.data.request.DataTypes
import com.samsung.android.sdk.health.data.request.LocalTimeFilter
import com.samsung.android.sdk.health.data.request.Ordering
import com.samsung.android.sdk.health.data.response.DataResponse
import com.samsung.android.sdk.health.data.data.HealthDataPoint

class SamsungHealthPlugin(
    private val activity: Activity,
    private val context: Context
) : MethodCallHandler {

    companion object {
        const val CHANNEL      = "com.example.ai_health/samsung_health"
        const val EVENT_CHANNEL = "com.example.ai_health/samsung_health_events"
        private const val TAG  = "SamsungHealthPlugin"
        const val SAMSUNG_HEALTH_PKG = "com.sec.android.app.shealth"
    }

    // Store
    private var healthStore: HealthDataStore? = null

    // State
    private var isConnected   = false
    private var hasPermission = false
    private var isDemo        = false

    // EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var hrRunnable: Runnable? = null
    private val handler = Handler(Looper.getMainLooper())

    private fun getHealthStore(): HealthDataStore {
        if (healthStore == null) {
            healthStore = HealthDataService.getStore(context)
        }
        return healthStore!!
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "→ ${call.method}")
        when (call.method) {
            "isSamsungHealthInstalled" -> result.success(isSamsungHealthInstalled())
            "connect"                  -> connect(result)
            "requestPermission"        -> requestPermission(result)
            "getSteps"                 -> getSteps(result)
            "getHeartRate"             -> getHeartRate(result)
            "getSleep"                 -> getSleep(result)
            "getCalories"              -> getCalories(result)
            "getBloodPressure"         -> getBloodPressure(result)
            "getBloodGlucose"          -> getBloodGlucose(result)
            "getSpO2"                  -> getSpO2(result)
            "getBodyTemperature"       -> getBodyTemperature(result)
            "getWeight"                -> getWeight(result)
            "getHeight"                -> getHeight(result)
            "getDeviceManufacturer"    -> result.success(android.os.Build.MANUFACTURER)
            "openSamsungHealth"        -> openSamsungHealth(result)
            "disconnect"               -> disconnect(result)
            else                       -> result.notImplemented()
        }
    }

    private fun isSamsungHealthInstalled(): Boolean {
        return try {
            context.packageManager.getPackageInfo(SAMSUNG_HEALTH_PKG, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) { false }
    }

    private fun connect(result: Result) {
        try {
            if (!isSamsungHealthInstalled()) {
                isDemo = false
                isConnected = false
                result.success(mapOf(
                    "success" to false,
                    "mode" to "NOT_INSTALLED",
                    "message" to "Samsung Health chưa được cài đặt trên thiết bị."
                ))
                return
            }

            // Khởi tạo SDK Store
            val store = getHealthStore()
            isConnected = true
            isDemo = false

            // Tập quyền cần kiểm tra
            val permissions = setOf(
                Permission.of(DataTypes.STEPS, AccessType.READ),
                Permission.of(DataTypes.HEART_RATE, AccessType.READ),
                Permission.of(DataTypes.SLEEP, AccessType.READ),
                Permission.of(DataTypes.BLOOD_GLUCOSE, AccessType.READ),
                Permission.of(DataTypes.BLOOD_PRESSURE, AccessType.READ),
                Permission.of(DataTypes.BLOOD_OXYGEN, AccessType.READ),
                Permission.of(DataTypes.BODY_TEMPERATURE, AccessType.READ),
                Permission.of(DataTypes.BODY_COMPOSITION, AccessType.READ),
                Permission.of(DataTypes.USER_PROFILE, AccessType.READ)
            )

            store.getGrantedPermissionsAsync(permissions).setCallback(
                Looper.getMainLooper(),
                { granted ->
                    val hasAny = granted.isNotEmpty()
                    hasPermission = hasAny
                    val mode = if (hasAny) "REAL" else "NEED_PERM"
                    result.success(mapOf(
                        "success" to true,
                        "mode" to mode,
                        "message" to if (hasAny) "Đã kết nối trực tiếp với Samsung Health SDK!" else "Kết nối thành công. Cần cấp quyền truy cập."
                    ))
                },
                { error ->
                    Log.w(TAG, "getGrantedPermissions failed", error)
                    isDemo = false
                    isConnected = false
                    result.success(mapOf(
                        "success" to false,
                        "mode" to "ERROR",
                        "message" to "Không thể lấy quyền từ Samsung Health: ${error.message}"
                    ))
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "connect exception", e)
            isDemo = false
            isConnected = false
            result.success(mapOf(
                "success" to false,
                "mode" to "ERROR",
                "message" to "Lỗi khởi tạo SDK (${e.message})."
            ))
        }
    }

    private fun requestPermission(result: Result) {
        if (!isConnected) {
            result.error("NOT_CONNECTED", "Hãy gọi connect() trước", null)
            return
        }
        if (isDemo) {
            hasPermission = true
            result.success(mapOf(
                "granted" to true,
                "mode" to "DEMO",
                "permissions" to listOf("STEPS", "HEART_RATE", "SLEEP", "BLOOD_GLUCOSE", "BLOOD_PRESSURE", "BLOOD_OXYGEN", "BODY_TEMPERATURE", "BODY_COMPOSITION")
            ))
            return
        }

        try {
            val store = getHealthStore()
            val permissions = setOf(
                Permission.of(DataTypes.STEPS, AccessType.READ),
                Permission.of(DataTypes.HEART_RATE, AccessType.READ),
                Permission.of(DataTypes.SLEEP, AccessType.READ),
                Permission.of(DataTypes.BLOOD_GLUCOSE, AccessType.READ),
                Permission.of(DataTypes.BLOOD_PRESSURE, AccessType.READ),
                Permission.of(DataTypes.BLOOD_OXYGEN, AccessType.READ),
                Permission.of(DataTypes.BODY_TEMPERATURE, AccessType.READ),
                Permission.of(DataTypes.BODY_COMPOSITION, AccessType.READ),
                Permission.of(DataTypes.USER_PROFILE, AccessType.READ)
            )

            store.requestPermissionsAsync(permissions, activity).setCallback(
                Looper.getMainLooper(),
                { granted ->
                    hasPermission = true
                    val anyGranted = granted.isNotEmpty()
                    result.success(mapOf(
                        "granted" to anyGranted,
                        "mode" to "REAL",
                        "permissions" to granted.map { it.dataType.name }
                    ))
                    // Start live stream if eventSink registered
                    eventSink?.let { startHrStream() }
                },
                { error ->
                    Log.e(TAG, "requestPermissions failed", error)
                    result.error("PERMISSION_FAILED", error.message, null)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "requestPermission exception", e)
            result.error("PERMISSION_EXCEPTION", e.message, null)
        }
    }

    private fun getSteps(result: Result) {
        if (!checkReady(result)) return
        if (isDemo) {
            val demoMidnight = LocalDateTime.now().withHour(0).withMinute(0).withSecond(0).withNano(0)
                .atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
            result.success(buildStepMap((7500..13000).random(), demoMidnight, "DEMO (Chế độ mô phỏng)"))
            return
        }

        try {
            val now = LocalDateTime.now()
            val todayMidnight = now.withHour(0).withMinute(0).withSecond(0).withNano(0)
            // Dùng timestamp của midnight hôm nay làm khoá ổn định để SQLite REPLACE hoạt động đúng
            val todayMidnightMs = todayMidnight.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()

            val builder = StepsType.TOTAL.requestBuilder
            val request = builder
                .setLocalTimeFilter(LocalTimeFilter.of(todayMidnight, now))
                .build()

            getHealthStore().aggregateDataAsync(request).setCallback(
                Looper.getMainLooper(),
                { response ->
                    var totalSteps = 0
                    val list = response.dataList
                    if (list != null && !list.isEmpty()) {
                        val total = list[0].value
                        if (total != null) {
                            totalSteps = total.toInt()
                        }
                    }
                    result.success(buildStepMap(totalSteps, todayMidnightMs, "Samsung Health SDK (Real)"))
                },
                { error ->
                    Log.e(TAG, "getSteps aggregate error", error)
                    result.error("STEPS_ERROR", "Không thể đọc bước chân: ${error.message}", null)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getSteps exception", e)
            result.error("STEPS_EXCEPTION", "Lỗi đọc bước chân: ${e.message}", null)
        }
    }

    private fun buildStepMap(steps: Int, dateMs: Long, source: String): Map<String, Any> {
        val distance = steps * 0.78 / 1000.0
        val calories = (steps * 0.04).toInt()
        return mapOf(
            "steps"       to steps,
            "distance_km" to String.format(Locale.US, "%.2f", distance).toDouble(),
            "calories"    to calories,
            "date"        to dateMs,
            "source"      to source
        )
    }

    private fun getHeartRate(result: Result) {
        if (!checkReady(result)) return
        if (isDemo) {
            val bpm = (65..92).random()
            result.success(mapOf(
                "bpm"       to bpm,
                "status"    to getHrStatus(bpm),
                "timestamp" to System.currentTimeMillis(),
                "source"    to "DEMO (Simulated)"
            ))
            return
        }

        try {
            val now = LocalDateTime.now()
            val start = now.minusDays(90)
            val request = DataTypes.HEART_RATE.readDataRequestBuilder
                .setLocalTimeFilter(LocalTimeFilter.of(start, now))
                .setLimit(1)
                .setOrdering(Ordering.DESC)
                .build()

            getHealthStore().readDataAsync(request).setCallback(
                Looper.getMainLooper(),
                { response ->
                    val list = response.dataList
                    if (list != null && !list.isEmpty()) {
                        val point = list[0]
                        val bpmVal = point.getValue(HeartRateType.HEART_RATE) ?: 72.0f
                        val bpm = bpmVal.toInt()
                        val timestamp = point.startTime?.toEpochMilli() ?: System.currentTimeMillis()
                        //Log.d(TAG, "getHeartRate: bpm=$bpm recordTime=${point.startTime} queriedAt=$now")  // ← thêm dòng này
                        result.success(mapOf(
                            "bpm" to bpm,
                            "status" to getHrStatus(bpm),
                            "timestamp" to timestamp,
                            "source" to "Samsung Health SDK (Real)"
                        ))
                    } else {
                        Log.d(TAG, "getHeartRate: no data found")
                        result.success(null)
                    }
                },
                { error ->
                    Log.e(TAG, "getHeartRate error", error)
                    result.error("HEART_RATE_ERROR", error.message, null)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getHeartRate exception", e)
            result.error("HEART_RATE_EXCEPTION", e.message, null)
        }
    }

    private fun getSleep(result: Result) {
        if (!checkReady(result)) return
        if (isDemo) {
            val total = (380..510).random()
            val deep  = (total * 0.15).toInt()
            val rem   = (total * 0.20).toInt()
            result.success(mapOf(
                "total_minutes" to total,
                "deep_minutes"  to deep,
                "rem_minutes"   to rem,
                "light_minutes" to (total - deep - rem),
                "quality"       to getSleepQuality(total),
                "source"        to "DEMO (Simulated)"
            ))
            return
        }

        try {
            val now = LocalDateTime.now()
            val start = now.minusDays(90)
            val request = DataTypes.SLEEP.readDataRequestBuilder
                .setLocalTimeFilter(LocalTimeFilter.of(start, now))
                .setLimit(1)
                .setOrdering(Ordering.DESC)
                .build()

            getHealthStore().readDataAsync(request).setCallback(
                Looper.getMainLooper(),
                { response ->
                    val list = response.dataList
                    if (list != null && !list.isEmpty()) {
                        val point = list[0]
                        val duration = point.getValue(SleepType.DURATION)
                        val totalMinutes = duration?.toMinutes()?.toInt() ?: 0

                        val sessions = point.getValue(SleepType.SESSIONS)
                        var deepMinutes = 0
                        var remMinutes = 0
                        var lightMinutes = 0

                        if (sessions != null && !sessions.isEmpty()) {
                            val session = sessions[0]
                            val stages = session.stages
                            if (stages != null) {
                                for (stage in stages) {
                                    val stageType = stage.stage
                                    val stageDur = java.time.Duration.between(stage.startTime, stage.endTime).toMinutes().toInt()
                                    when (stageType) {
                                        StageType.DEEP -> deepMinutes += stageDur
                                        StageType.REM -> remMinutes += stageDur
                                        StageType.LIGHT -> lightMinutes += stageDur
                                        else -> {}
                                    }
                                }
                            }
                        }

                        if (deepMinutes == 0 && remMinutes == 0) {
                            deepMinutes = (totalMinutes * 0.15).toInt()
                            remMinutes = (totalMinutes * 0.20).toInt()
                            lightMinutes = totalMinutes - deepMinutes - remMinutes
                        }

                        result.success(mapOf(
                            "total_minutes" to totalMinutes,
                            "deep_minutes"  to deepMinutes,
                            "rem_minutes"   to remMinutes,
                            "light_minutes" to lightMinutes,
                            "quality"       to getSleepQuality(totalMinutes),
                            "source"        to "Samsung Health SDK (Real)"
                        ))
                    } else {
                        Log.d(TAG, "getSleep: no data found")
                        result.success(null)
                    }
                },
                { error ->
                    Log.e(TAG, "getSleep error", error)
                    result.error("SLEEP_ERROR", error.message, null)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getSleep exception", e)
            result.error("SLEEP_EXCEPTION", e.message, null)
        }
    }

    private fun getCalories(result: Result) {
        if (!checkReady(result)) return
        if (isDemo) {
            val active = (50..300).random()
            val bmr    = (1500..2000).random()
            result.success(mapOf(
                "total_calories"  to (active + bmr),
                "active_calories" to active,
                "bmr_calories"    to bmr,
                "source"          to "DEMO (Simulated)"
            ))
            return
        }

        try {
            val now = LocalDateTime.now()
            val todayMidnight = now.withHour(0).withMinute(0).withSecond(0).withNano(0)

            val builder = ActivitySummaryType.TOTAL_ACTIVE_CALORIES_BURNED.requestBuilder
            val request = builder
                .setLocalTimeFilter(LocalTimeFilter.of(todayMidnight, now))
                .build()

            getHealthStore().aggregateDataAsync(request).setCallback(
                Looper.getMainLooper(),
                { response ->
                    var activeCalories = 0
                    val list = response.dataList
                    if (list != null && !list.isEmpty()) {
                        val valFloat = list[0].value
                        if (valFloat != null) {
                            activeCalories = valFloat.toInt()
                        }
                    }
                    val bmr = 1800 // Static standard BMR instead of random
                    result.success(mapOf(
                        "total_calories"  to (activeCalories + bmr),
                        "active_calories" to activeCalories,
                        "bmr_calories"    to bmr,
                        "source"          to "Samsung Health SDK (Real)"
                    ))
                },
                { error ->
                    Log.e(TAG, "getCalories error", error)
                    result.error("CALORIES_ERROR", error.message, null)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getCalories exception", e)
            result.error("CALORIES_EXCEPTION", e.message, null)
        }
    }

    private fun getBloodPressure(result: Result) {
        if (!checkReady(result)) return
        if (isDemo) {
            val systolic = (110..135).random()
            val diastolic = (70..85).random()
            result.success(mapOf(
                "systolic"  to systolic,
                "diastolic" to diastolic,
                "timestamp" to System.currentTimeMillis(),
                "source"    to "DEMO (Simulated)"
            ))
            return
        }

        try {
            val now = LocalDateTime.now()
            val start = now.minusDays(90)
            val request = DataTypes.BLOOD_PRESSURE.readDataRequestBuilder
                .setLocalTimeFilter(LocalTimeFilter.of(start, now))
                .setLimit(1)
                .setOrdering(Ordering.DESC)
                .build()

            getHealthStore().readDataAsync(request).setCallback(
                Looper.getMainLooper(),
                { response ->
                    val list = response.dataList
                    if (list != null && !list.isEmpty()) {
                        val point = list[0]
                        val sysVal = point.getValue(BloodPressureType.SYSTOLIC) ?: 120.0f
                        val diaVal = point.getValue(BloodPressureType.DIASTOLIC) ?: 80.0f
                        val timestamp = point.startTime?.toEpochMilli() ?: System.currentTimeMillis()
                        result.success(mapOf(
                            "systolic"  to sysVal.toInt(),
                            "diastolic" to diaVal.toInt(),
                            "timestamp" to timestamp,
                            "source"    to "Samsung Health SDK (Real)"
                        ))
                    } else {
                        Log.d(TAG, "getBloodPressure: no data found")
                        result.success(null)
                    }
                },
                { error ->
                    Log.e(TAG, "getBloodPressure error", error)
                    result.error("BLOOD_PRESSURE_ERROR", error.message, null)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getBloodPressure exception", e)
            result.error("BLOOD_PRESSURE_EXCEPTION", e.message, null)
        }
    }

    private fun getBloodGlucose(result: Result) {
        if (!checkReady(result)) return
        if (isDemo) {
            val glucose = (4.4 + (0.1 * (0..24).random()))
            result.success(mapOf(
                "glucose"   to String.format(Locale.US, "%.1f", glucose).toDouble(),
                "timestamp" to System.currentTimeMillis(),
                "source"    to "DEMO (Simulated)"
            ))
            return
        }

        try {
            val now = LocalDateTime.now()
            val start = now.minusDays(90)
            Log.d(TAG, "getBloodGlucose query: start=$start, end=$now")
            val request = DataTypes.BLOOD_GLUCOSE.readDataRequestBuilder
                .setLocalTimeFilter(LocalTimeFilter.of(start, now))
                .setLimit(1)
                .setOrdering(Ordering.DESC)
                .build()

            getHealthStore().readDataAsync(request).setCallback(
                Looper.getMainLooper(),
                { response ->
                    val list = response.dataList
                    Log.d(TAG, "getBloodGlucose response: count=${list?.size ?: 0}")
                    if (list != null && !list.isEmpty()) {
                        val point = list[0]
                        val gluVal = point.getValue(BloodGlucoseType.GLUCOSE_LEVEL)
                        Log.d(TAG, "getBloodGlucose point: value=$gluVal, startTime=${point.startTime}")
                        val finalGlu = gluVal ?: 5.5f
                        val timestamp = point.startTime?.toEpochMilli() ?: System.currentTimeMillis()
                        result.success(mapOf(
                            "glucose"   to String.format(Locale.US, "%.1f", finalGlu).toDouble(),
                            "timestamp" to timestamp,
                            "source"    to "Samsung Health SDK (Real)"
                        ))
                    } else {
                        Log.d(TAG, "getBloodGlucose: dataList is empty or null")
                        result.success(null)
                    }
                },
                { error ->
                    Log.e(TAG, "getBloodGlucose error: message=${error.message}", error)
                    result.error("BLOOD_GLUCOSE_ERROR", error.message, null)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getBloodGlucose exception", e)
            result.error("BLOOD_GLUCOSE_EXCEPTION", e.message, null)
        }
    }

    private fun getSpO2(result: Result) {
        if (!checkReady(result)) return
        if (isDemo) {
            val spo2 = (95..99).random()
            result.success(mapOf(
                "spo2"      to spo2,
                "timestamp" to System.currentTimeMillis(),
                "source"    to "DEMO (Simulated)"
            ))
            return
        }

        try {
            val now = LocalDateTime.now()
            val start = now.minusDays(90)
            val request = DataTypes.BLOOD_OXYGEN.readDataRequestBuilder
                .setLocalTimeFilter(LocalTimeFilter.of(start, now))
                .setLimit(1)
                .setOrdering(Ordering.DESC)
                .build()

            getHealthStore().readDataAsync(request).setCallback(
                Looper.getMainLooper(),
                { response ->
                    val list = response.dataList
                    if (list != null && !list.isEmpty()) {
                        val point = list[0]
                        val spo2Val = point.getValue(BloodOxygenType.OXYGEN_SATURATION) ?: 97.0f
                        val timestamp = point.startTime?.toEpochMilli() ?: System.currentTimeMillis()
                        result.success(mapOf(
                            "spo2"      to spo2Val.toInt(),
                            "timestamp" to timestamp,
                            "source"    to "Samsung Health SDK (Real)"
                        ))
                    } else {
                        Log.d(TAG, "getSpO2: no data found")
                        result.success(null)
                    }
                },
                { error ->
                    Log.e(TAG, "getSpO2 error", error)
                    result.error("SPO2_ERROR", error.message, null)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getSpO2 exception", e)
            result.error("SPO2_EXCEPTION", e.message, null)
        }
    }

    private fun getBodyTemperature(result: Result) {
        if (!checkReady(result)) return
        if (isDemo) {
            val temp = (36.1 + (0.1 * (0..11).random()))
            result.success(mapOf(
                "temperature" to String.format(Locale.US, "%.1f", temp).toDouble(),
                "timestamp"   to System.currentTimeMillis(),
                "source"      to "DEMO (Simulated)"
            ))
            return
        }

        try {
            val now = LocalDateTime.now()
            val start = now.minusDays(90)
            val request = DataTypes.BODY_TEMPERATURE.readDataRequestBuilder
                .setLocalTimeFilter(LocalTimeFilter.of(start, now))
                .setLimit(1)
                .setOrdering(Ordering.DESC)
                .build()

            getHealthStore().readDataAsync(request).setCallback(
                Looper.getMainLooper(),
                { response ->
                    val list = response.dataList
                    if (list != null && !list.isEmpty()) {
                        val point = list[0]
                        val tempVal = point.getValue(BodyTemperatureType.BODY_TEMPERATURE) ?: 36.6f
                        val timestamp = point.startTime?.toEpochMilli() ?: System.currentTimeMillis()
                        result.success(mapOf(
                            "temperature" to String.format(Locale.US, "%.1f", tempVal).toDouble(),
                            "timestamp"   to timestamp,
                            "source"      to "Samsung Health SDK (Real)"
                        ))
                    } else {
                        Log.d(TAG, "getBodyTemperature: no data found")
                        result.success(null)
                    }
                },
                { error ->
                    Log.e(TAG, "getBodyTemperature error", error)
                    result.error("BODY_TEMPERATURE_ERROR", error.message, null)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getBodyTemperature exception", e)
            result.error("BODY_TEMPERATURE_EXCEPTION", e.message, null)
        }
    }

    private fun getWeight(result: Result) {
        if (!checkReady(result)) return
        if (isDemo) {
            val weight = (62.0 + (0.1 * (0..80).random()))
            result.success(mapOf(
                "weight"    to String.format(Locale.US, "%.1f", weight).toDouble(),
                "timestamp" to System.currentTimeMillis(),
                "source"    to "DEMO (Simulated)"
            ))
            return
        }

        try {
            val now = LocalDateTime.now()
            val start = now.minusDays(180)
            val request = DataTypes.BODY_COMPOSITION.readDataRequestBuilder
                .setLocalTimeFilter(LocalTimeFilter.of(start, now))
                .setLimit(1)
                .setOrdering(Ordering.DESC)
                .build()

            getHealthStore().readDataAsync(request).setCallback(
                Looper.getMainLooper(),
                { response ->
                    val list = response.dataList
                    if (list != null && !list.isEmpty()) {
                        val point = list[0]
                        val weightVal = point.getValue(BodyCompositionType.WEIGHT) ?: 60.0f
                        val timestamp = point.startTime?.toEpochMilli() ?: System.currentTimeMillis()
                        result.success(mapOf(
                            "weight"    to String.format(Locale.US, "%.1f", weightVal).toDouble(),
                            "timestamp" to timestamp,
                            "source"    to "Samsung Health SDK (Real)"
                        ))
                    } else {
                        getUserProfileWeight(result)
                    }
                },
                { error ->
                    Log.e(TAG, "getWeight error", error)
                    getUserProfileWeight(result)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getWeight exception", e)
            result.error("WEIGHT_EXCEPTION", e.message, null)
        }
    }

    private fun getUserProfileWeight(result: Result) {
        try {
            val request = DataTypes.USER_PROFILE.readDataRequestBuilder.build()
            getHealthStore().readDataAsync(request).setCallback(
                Looper.getMainLooper(),
                { response ->
                    val list = response.dataList
                    if (list != null && !list.isEmpty()) {
                        val profile = list[0]
                        val weightVal = profile.getValue(UserProfileDataType.WEIGHT) ?: 60.0f
                        result.success(mapOf(
                            "weight"    to String.format(Locale.US, "%.1f", weightVal).toDouble(),
                            "timestamp" to System.currentTimeMillis(),
                            "source"    to "Samsung Health SDK Profile (Real)"
                        ))
                    } else {
                        Log.d(TAG, "getUserProfileWeight: no profile data found")
                        result.success(null)
                    }
                },
                { error ->
                    Log.e(TAG, "getUserProfileWeight error", error)
                    result.error("PROFILE_WEIGHT_ERROR", error.message, null)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getUserProfileWeight exception", e)
            result.error("PROFILE_WEIGHT_EXCEPTION", e.message, null)
        }
    }

    private fun getHeight(result: Result) {
        if (!checkReady(result)) return
        if (isDemo) {
            val height = 172.0
            result.success(mapOf(
                "height"    to height,
                "timestamp" to System.currentTimeMillis(),
                "source"    to "DEMO (Simulated)"
            ))
            return
        }

        try {
            val now = LocalDateTime.now()
            val start = now.minusDays(365)
            val request = DataTypes.BODY_COMPOSITION.readDataRequestBuilder
                .setLocalTimeFilter(LocalTimeFilter.of(start, now))
                .setLimit(1)
                .setOrdering(Ordering.DESC)
                .build()

            getHealthStore().readDataAsync(request).setCallback(
                Looper.getMainLooper(),
                { response ->
                    val list = response.dataList
                    if (list != null && !list.isEmpty()) {
                        val point = list[0]
                        val heightVal = point.getValue(BodyCompositionType.HEIGHT) ?: 170.0f
                        val timestamp = point.startTime?.toEpochMilli() ?: System.currentTimeMillis()
                        result.success(mapOf(
                            "height"    to String.format(Locale.US, "%.1f", heightVal).toDouble(),
                            "timestamp" to timestamp,
                            "source"    to "Samsung Health SDK (Real)"
                        ))
                    } else {
                        getUserProfileHeight(result)
                    }
                },
                { error ->
                    Log.e(TAG, "getHeight error", error)
                    getUserProfileHeight(result)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getHeight exception", e)
            result.error("HEIGHT_EXCEPTION", e.message, null)
        }
    }

    private fun getUserProfileHeight(result: Result) {
        try {
            val request = DataTypes.USER_PROFILE.readDataRequestBuilder.build()
            getHealthStore().readDataAsync(request).setCallback(
                Looper.getMainLooper(),
                { response ->
                    val list = response.dataList
                    if (list != null && !list.isEmpty()) {
                        val profile = list[0]
                        val heightVal = profile.getValue(UserProfileDataType.HEIGHT) ?: 170.0f
                        result.success(mapOf(
                            "height"    to String.format(Locale.US, "%.1f", heightVal).toDouble(),
                            "timestamp" to System.currentTimeMillis(),
                            "source"    to "Samsung Health SDK Profile (Real)"
                        ))
                    } else {
                        Log.d(TAG, "getUserProfileHeight: no profile data found")
                        result.success(null)
                    }
                },
                { error ->
                    Log.e(TAG, "getUserProfileHeight error", error)
                    result.error("PROFILE_HEIGHT_ERROR", error.message, null)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "getUserProfileHeight exception", e)
            result.error("PROFILE_HEIGHT_EXCEPTION", e.message, null)
        }
    }

    private fun openSamsungHealth(result: Result) {
        try {
            val intent = context.packageManager.getLaunchIntentForPackage(SAMSUNG_HEALTH_PKG)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(mapOf("success" to true, "message" to "Samsung Health đã được mở"))
            } else {
                result.success(mapOf("success" to false, "message" to "Samsung Health chưa được cài"))
            }
        } catch (e: Exception) {
            result.error("OPEN_FAILED", e.message, null)
        }
    }

    private fun disconnect(result: Result) {
        stopHrStream()
        isConnected   = false
        hasPermission = false
        result.success(mapOf("success" to true))
        Log.d(TAG, "Disconnected")
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        if (sink != null) {
            startHrStream()
        } else {
            stopHrStream()
        }
    }

    private fun startHrStream() {
        stopHrStream()
        val runnable = object : Runnable {
            override fun run() {
                val sink = eventSink ?: return
                if (isDemo || !isConnected || !hasPermission) {
                    val bpm = (65..92).random()
                    sink.success(mapOf(
                        "type"      to "HEART_RATE",
                        "bpm"       to bpm,
                        "status"    to getHrStatus(bpm),
                        "timestamp" to System.currentTimeMillis(),
                        "source"    to "DEMO (Live Stream)"
                    ))
                    handler.postDelayed(this, 3000)
                } else {
                    try {
                        val now = LocalDateTime.now()
                        val start = now.minusMinutes(5)
                        val request = DataTypes.HEART_RATE.readDataRequestBuilder
                            .setLocalTimeFilter(LocalTimeFilter.of(start, now))
                            .setLimit(1)
                            .setOrdering(Ordering.DESC)
                            .build()

                        getHealthStore().readDataAsync(request).setCallback(
                            Looper.getMainLooper(),
                            { response ->
                                val list = response.dataList
                                if (list != null && !list.isEmpty()) {
                                    val point = list[0]
                                    val bpmVal = point.getValue(HeartRateType.HEART_RATE) ?: 72.0f
                                    val bpm = bpmVal.toInt()
                                    val timestamp = point.startTime?.toEpochMilli() ?: System.currentTimeMillis()
                                    sink.success(mapOf(
                                        "type"      to "HEART_RATE",
                                        "bpm"       to bpm,
                                        "status"    to getHrStatus(bpm),
                                        "timestamp" to timestamp,
                                        "source"    to "Samsung Health SDK (Live Stream)"
                                    ))
                                } else {
                                    Log.d(TAG, "Live HR stream: no real data in last 5 mins")
                                }
                                handler.postDelayed(this, 3000)
                            },
                            { error ->
                                Log.e(TAG, "Live HR stream SDK error", error)
                                handler.postDelayed(this, 3000)
                            }
                        )
                    } catch (e: Exception) {
                        Log.e(TAG, "Live HR stream exception", e)
                        handler.postDelayed(this, 3000)
                    }
                }
            }
        }
        hrRunnable = runnable
        handler.post(runnable)
    }

    private fun stopHrStream() {
        hrRunnable?.let { handler.removeCallbacks(it) }
        hrRunnable = null
    }

    private fun checkReady(result: Result): Boolean {
        if (!isConnected)   { result.error("NOT_CONNECTED", "Hãy gọi connect() trước", null);        return false }
        if (!hasPermission) { result.error("NO_PERMISSION", "Hãy gọi requestPermission() trước", null); return false }
        return true
    }

    private fun getHrStatus(bpm: Int) = when {
        bpm < 60   -> "THẤP"
        bpm <= 100 -> "BÌNH THƯỜNG"
        bpm <= 140 -> "CAO"
        else       -> "RẤT CAO"
    }

    private fun getSleepQuality(m: Int) = when {
        m < 360 -> "KÉM"
        m < 420 -> "TRUNG BÌNH"
        m < 480 -> "TỐT"
        else    -> "XUẤT SẮC"
    }
}
