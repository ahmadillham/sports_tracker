/**
 * @file config.h
 * @brief Central configuration for the ESP32 Sports Tracker.
 *
 * All pin definitions, BLE UUIDs, timing constants, sport mode enums,
 * and shared data structures are defined here.
 */

#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>

// ──────────────────────────────────────────────
//  GPIO Pin Definitions
// ──────────────────────────────────────────────

// AD8232 Heart Rate Sensor
#define PIN_HR_OUTPUT       34   // Analog output (ADC1_CH6)
#define PIN_HR_LO_PLUS      25   // Leads-off detection +
#define PIN_HR_LO_MINUS     26   // Leads-off detection -

// GY-85 IMU (I2C)
#define PIN_I2C_SDA         21
#define PIN_I2C_SCL         22

// NEO-7M GPS (HardwareSerial2)
#define PIN_GPS_RX          16   // ESP32 RX ← GPS TX
#define PIN_GPS_TX          17   // ESP32 TX → GPS RX
#define GPS_BAUD            9600

// Active Buzzer (Active LOW: LOW = ON, HIGH = OFF)
#define PIN_BUZZER          27

// ──────────────────────────────────────────────
//  I2C Addresses (GY-85 Module)
// ──────────────────────────────────────────────
#define ADXL345_ADDR        0x53  // Accelerometer
#define ITG3200_ADDR        0x68  // Gyroscope
#define HMC5883L_ADDR       0x1E  // Magnetometer

// ──────────────────────────────────────────────
//  BLE UUIDs
// ──────────────────────────────────────────────

// Custom Sport Service
#define SERVICE_SPORT_UUID          "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c10"
#define CHAR_SENSOR_DATA_UUID       "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c11"
#define CHAR_GPS_DATA_UUID          "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c12"
#define CHAR_COMMAND_UUID           "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c13"

// BLE Device Name
#define BLE_DEVICE_NAME             "SportTracker"

// ──────────────────────────────────────────────
//  Sport Mode Enum
// ──────────────────────────────────────────────
enum SportMode : uint8_t {
    MODE_IDLE       = 0x00,
    MODE_RUNNING    = 0x01,
    MODE_CYCLING    = 0x02,
    MODE_JUMP_ROPE  = 0x03,
    MODE_PUSHUP     = 0x04,
    MODE_SQUAT      = 0x05,
    MODE_PLANK      = 0x06
};

// ──────────────────────────────────────────────
//  Shared Data Structures
// ──────────────────────────────────────────────

/**
 * @brief Sensor data shared between Core 1 (writer) and Core 0 (BLE reader).
 */
struct SensorData {
    uint16_t heartRate;     // BPM (0 = leads off)
    uint32_t stepCount;     // Running steps
    uint32_t jumpCount;     // Jump rope reps
    float    pitch;         // Posture: pitch in degrees
    float    roll;          // Posture: roll in degrees
};

/**
 * @brief GPS data shared between Core 1 (writer) and Core 0 (BLE reader).
 */
struct GPSData {
    double   latitude;
    double   longitude;
    float    speed;         // km/h
    float    distance;      // km (cumulative)
    uint8_t  satellites;
    uint8_t  fixValid;      // 1 = valid fix, 0 = no fix
};

/**
 * @brief Command data received from the phone via BLE RX characteristic.
 */
struct CommandData {
    SportMode sportMode;
    uint16_t  maxHR;        // Maximum heart rate threshold for warning
};

// ──────────────────────────────────────────────
//  Extern Globals (defined in main.cpp)
// ──────────────────────────────────────────────
extern SemaphoreHandle_t xDataMutex;
extern SensorData        g_sensorData;
extern GPSData           g_gpsData;
extern CommandData       g_commandData;
extern volatile bool     g_bleConnected;
extern volatile bool     g_gpsLockAcquired;

// ──────────────────────────────────────────────
//  Timing Constants (milliseconds)
// ──────────────────────────────────────────────
#define SENSOR_POLL_INTERVAL_MS     20    // 50 Hz for IMU + HR
#define GPS_POLL_INTERVAL_MS        1000  // 1 Hz for GPS
#define BLE_NOTIFY_INTERVAL_MS      500   // 2 Hz BLE notifications
#define BUZZER_TICK_INTERVAL_MS     10    // 100 Hz buzzer state machine

// ──────────────────────────────────────────────
//  Algorithm Constants
// ──────────────────────────────────────────────

// Step detection
#define STEP_THRESHOLD              1.25f   // G-force threshold for step peak
#define STEP_DEBOUNCE_MS            300     // Minimum ms between steps

// Jump detection
#define JUMP_THRESHOLD              1.80f   // G-force threshold for jump peak
#define JUMP_DEBOUNCE_MS            250     // Minimum ms between jumps

// Push-up detection
#define PUSHUP_THRESHOLD            1.25f   // G-force threshold for push-up peak
#define PUSHUP_DEBOUNCE_MS          600     // Minimum ms between push-ups

// Squat detection
#define SQUAT_THRESHOLD             1.15f   // G-force threshold for squat peak
#define SQUAT_DEBOUNCE_MS           800     // Minimum ms between squats

// Plank posture
#define PLANK_ANGLE_TOLERANCE       15.0f   // Max degrees of deviation before warning

// HR detection
#define HR_SAMPLE_RATE_MS           5       // 200 Hz analog sampling
#define HR_THRESHOLD                2200    // ADC threshold for R-wave peak
#define HR_MIN_IBI_MS               300     // Min inter-beat interval (200 BPM max)
#define HR_MAX_IBI_MS               1500    // Max inter-beat interval (40 BPM min)

// Posture complementary filter
#define COMPLEMENTARY_ALPHA         0.96f

// FreeRTOS Task Stack Sizes
#define STACK_SIZE_BLE              4096
#define STACK_SIZE_SENSOR           4096
#define STACK_SIZE_GPS              2048
#define STACK_SIZE_BUZZER           1024

#endif // CONFIG_H
