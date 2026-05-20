/**
 * @file main.cpp
 * @brief Entry point for the ESP32 Sports Tracker firmware.
 *
 * Creates FreeRTOS tasks pinned to specific cores:
 *   Core 0: BLE task (GATT notifications)
 *   Core 1: Sensor task (IMU + HR), GPS task, Buzzer task
 *
 * Shared data protected by xDataMutex.
 */

#include <Arduino.h>
#include "config.h"
#include "ble_server.h"
#include "imu_sensor.h"
#include "gps_sensor.h"
#include "hr_sensor.h"
#include "sport_algo.h"
#include "buzzer.h"

// ──────────────────────────────────────────────
//  Global Shared Data (declared extern in config.h)
// ──────────────────────────────────────────────
SemaphoreHandle_t xDataMutex    = nullptr;
SensorData        g_sensorData  = {0, 0, 0, 0.0f, 0.0f};
GPSData           g_gpsData     = {0.0, 0.0, 0.0f, 0.0f, 0, 0};
CommandData       g_commandData = {MODE_IDLE, 180};
volatile bool     g_bleConnected    = false;
volatile bool     g_gpsLockAcquired = false;

// Track if GPS lock buzzer has already fired
static bool s_gpsLockBuzzed = false;

// ──────────────────────────────────────────────
//  Task: Sensor Polling (Core 1, 50 Hz)
//  Reads IMU + HR, runs sport algorithms,
//  writes to shared data under mutex.
// ──────────────────────────────────────────────
void taskSensor(void *param) {
    (void)param;
    TickType_t xLastWake = xTaskGetTickCount();
    unsigned long lastSensorUs = micros();

    for (;;) {
        unsigned long nowUs = micros();
        float dt = (nowUs - lastSensorUs) / 1000000.0f;
        lastSensorUs = nowUs;

        // ── Read IMU ──
        IMURawData imuRaw;
        bool imuOk = imu_read(imuRaw);

        // ── Read HR ──
        uint16_t bpm = hr_update();

        // ── Run algorithms based on sport mode ──
        SportMode currentMode;
        uint16_t  currentMaxHR;
        if (xSemaphoreTake(xDataMutex, pdMS_TO_TICKS(5)) == pdTRUE) {
            currentMode  = g_commandData.sportMode;
            currentMaxHR = g_commandData.maxHR;
            xSemaphoreGive(xDataMutex);
        } else {
            currentMode  = MODE_IDLE;
            currentMaxHR = 180;
        }

        PostureData posture = {0.0f, 0.0f};

        if (imuOk && currentMode != MODE_IDLE) {
            // Step detection (Running mode)
            if (currentMode == MODE_RUNNING) {
                algo_detect_step(imuRaw);
            }

            // Jump detection (Jump Rope mode)
            if (currentMode == MODE_JUMP_ROPE) {
                algo_detect_jump(imuRaw);
            }

            // Posture (Running + Cycling)
            if (currentMode == MODE_RUNNING || currentMode == MODE_CYCLING) {
                posture = algo_update_posture(imuRaw, dt);
            }
        }

        // ── HR Warning Check ──
        if (bpm > 0 && currentMaxHR > 0 && bpm > currentMaxHR) {
            if (!buzzer_is_playing()) {
                buzzer_trigger(BUZZ_HR_WARNING);
            }
        } else {
            // Stop HR warning if heart rate drops back
            // (only if the current pattern IS the HR warning)
            // We don't stop other patterns
        }

        // ── Update shared sensor data ──
        if (xSemaphoreTake(xDataMutex, pdMS_TO_TICKS(5)) == pdTRUE) {
            g_sensorData.heartRate = bpm;
            g_sensorData.stepCount = algo_get_steps();
            g_sensorData.jumpCount = algo_get_jumps();
            g_sensorData.pitch     = posture.pitch;
            g_sensorData.roll      = posture.roll;
            xSemaphoreGive(xDataMutex);
        }

        vTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(SENSOR_POLL_INTERVAL_MS));
    }
}

// ──────────────────────────────────────────────
//  Task: GPS Polling (Core 1, 1 Hz)
// ──────────────────────────────────────────────
void taskGPS(void *param) {
    (void)param;
    TickType_t xLastWake = xTaskGetTickCount();

    for (;;) {
        GPSOutput gpsOut;
        gps_update(gpsOut);

        // GPS lock buzzer (once)
        if (gpsOut.fixValid && !s_gpsLockBuzzed) {
            s_gpsLockBuzzed = true;
            g_gpsLockAcquired = true;
            buzzer_trigger(BUZZ_GPS_LOCK);
            Serial.println("[GPS] Fix acquired!");
        }

        // Update shared GPS data
        if (xSemaphoreTake(xDataMutex, pdMS_TO_TICKS(5)) == pdTRUE) {
            g_gpsData.latitude   = gpsOut.latitude;
            g_gpsData.longitude  = gpsOut.longitude;
            g_gpsData.speed      = gpsOut.speedKmh;
            g_gpsData.distance   = gpsOut.distanceKm;
            g_gpsData.satellites = gpsOut.satellites;
            g_gpsData.fixValid   = gpsOut.fixValid ? 1 : 0;
            xSemaphoreGive(xDataMutex);
        }

        vTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(GPS_POLL_INTERVAL_MS));
    }
}

// ──────────────────────────────────────────────
//  Task: BLE Notifications (Core 0, 2 Hz)
// ──────────────────────────────────────────────
void taskBLE(void *param) {
    (void)param;
    TickType_t xLastWake = xTaskGetTickCount();
    for (;;) {
        // Notify sensor + GPS data
        ble_notify_sensors();
        ble_notify_gps();

        vTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(BLE_NOTIFY_INTERVAL_MS));
    }
}

// ──────────────────────────────────────────────
//  Task: Buzzer State Machine (Core 1, 100 Hz)
// ──────────────────────────────────────────────
void taskBuzzer(void *param) {
    (void)param;
    TickType_t xLastWake = xTaskGetTickCount();

    for (;;) {
        buzzer_update();
        vTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(BUZZER_TICK_INTERVAL_MS));
    }
}

// ──────────────────────────────────────────────
//  Arduino Setup
// ──────────────────────────────────────────────
void setup() {
    Serial.begin(115200);
    delay(500);
    Serial.println("\n========================================");
    Serial.println("   ESP32 Sports Tracker - Booting...");
    Serial.println("========================================\n");

    // Create mutex
    xDataMutex = xSemaphoreCreateMutex();

    // Initialize all peripherals
    buzzer_init();
    buzzer_trigger(BUZZ_POWER_ON);

    bool imuOk = imu_init();
    if (!imuOk) {
        Serial.println("[MAIN] WARNING: IMU init failed!");
    }

    gps_init();
    hr_init();
    algo_init();
    ble_init();

    Serial.println("\n[MAIN] All systems initialized.");
    Serial.println("[MAIN] Creating FreeRTOS tasks...\n");

    // ── Create tasks pinned to cores ──

    // Core 0: BLE (priority 1)
    xTaskCreatePinnedToCore(
        taskBLE, "TaskBLE",
        STACK_SIZE_BLE, nullptr, 1, nullptr,
        0  // Core 0
    );

    // Core 1: Sensor polling (priority 2 — highest on this core)
    xTaskCreatePinnedToCore(
        taskSensor, "TaskSensor",
        STACK_SIZE_SENSOR, nullptr, 2, nullptr,
        1  // Core 1
    );

    // Core 1: GPS polling (priority 1)
    xTaskCreatePinnedToCore(
        taskGPS, "TaskGPS",
        STACK_SIZE_GPS, nullptr, 1, nullptr,
        1  // Core 1
    );

    // Core 1: Buzzer (priority 3 — highest, for timing accuracy)
    xTaskCreatePinnedToCore(
        taskBuzzer, "TaskBuzzer",
        STACK_SIZE_BUZZER, nullptr, 3, nullptr,
        1  // Core 1
    );

    Serial.println("[MAIN] All tasks started. Entering idle loop.");
}

// ──────────────────────────────────────────────
//  Arduino Loop (empty — all work in tasks)
// ──────────────────────────────────────────────
void loop() {
    vTaskDelay(pdMS_TO_TICKS(1000));
}
