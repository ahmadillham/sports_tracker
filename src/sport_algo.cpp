/**
 * @file sport_algo.cpp
 * @brief Sport algorithms: step/jump counting and posture.
 */

#include "sport_algo.h"
#include "config.h"
#include <math.h>

static uint32_t s_stepCount = 0;
static float    s_stepFiltered = 1.0f;
static bool     s_stepAbove = false;
static unsigned long s_lastStepMs = 0;

static uint32_t s_jumpCount = 0;
static float    s_jumpFiltered = 1.0f;
static bool     s_jumpAbove = false;
static unsigned long s_lastJumpMs = 0;

static float s_pitch = 0.0f;
static float s_roll  = 0.0f;
static bool  s_postureInit = false;

#define EMA_ALPHA  0.3f

void algo_init() {
    s_stepCount = 0; s_jumpCount = 0;
    s_stepFiltered = 1.0f; s_jumpFiltered = 1.0f;
    s_stepAbove = false; s_jumpAbove = false;
    s_lastStepMs = 0; s_lastJumpMs = 0;
    s_pitch = 0.0f; s_roll = 0.0f;
    s_postureInit = false;
}

bool algo_detect_step(const IMURawData &data) {
    float ax = imu_accel_to_g(data.ax);
    float ay = imu_accel_to_g(data.ay);
    float az = imu_accel_to_g(data.az);
    float mag = sqrtf(ax*ax + ay*ay + az*az);
    s_stepFiltered = EMA_ALPHA * mag + (1.0f - EMA_ALPHA) * s_stepFiltered;

    unsigned long now = millis();
    if (s_stepFiltered > STEP_THRESHOLD && !s_stepAbove) {
        s_stepAbove = true;
    } else if (s_stepFiltered < (STEP_THRESHOLD - 0.15f) && s_stepAbove) {
        s_stepAbove = false;
        if (now - s_lastStepMs >= STEP_DEBOUNCE_MS) {
            s_stepCount++;
            s_lastStepMs = now;
            return true;
        }
    }
    return false;
}

bool algo_detect_jump(const IMURawData &data) {
    float ax = imu_accel_to_g(data.ax);
    float ay = imu_accel_to_g(data.ay);
    float az = imu_accel_to_g(data.az);
    float mag = sqrtf(ax*ax + ay*ay + az*az);
    s_jumpFiltered = EMA_ALPHA * mag + (1.0f - EMA_ALPHA) * s_jumpFiltered;

    unsigned long now = millis();
    if (s_jumpFiltered > JUMP_THRESHOLD && !s_jumpAbove) {
        s_jumpAbove = true;
    } else if (s_jumpFiltered < (JUMP_THRESHOLD - 0.2f) && s_jumpAbove) {
        s_jumpAbove = false;
        if (now - s_lastJumpMs >= JUMP_DEBOUNCE_MS) {
            s_jumpCount++;
            s_lastJumpMs = now;
            return true;
        }
    }
    return false;
}

PostureData algo_update_posture(const IMURawData &data, float dt) {
    float ax = imu_accel_to_g(data.ax);
    float ay = imu_accel_to_g(data.ay);
    float az = imu_accel_to_g(data.az);
    float gx = imu_gyro_to_dps(data.gx);
    float gy = imu_gyro_to_dps(data.gy);

    float accelPitch = atan2f(ax, sqrtf(ay*ay + az*az)) * 180.0f / M_PI;
    float accelRoll  = atan2f(ay, sqrtf(ax*ax + az*az)) * 180.0f / M_PI;

    if (!s_postureInit) {
        s_pitch = accelPitch;
        s_roll  = accelRoll;
        s_postureInit = true;
    } else {
        s_pitch = COMPLEMENTARY_ALPHA * (s_pitch + gx * dt) +
                  (1.0f - COMPLEMENTARY_ALPHA) * accelPitch;
        s_roll  = COMPLEMENTARY_ALPHA * (s_roll  + gy * dt) +
                  (1.0f - COMPLEMENTARY_ALPHA) * accelRoll;
    }

    PostureData p;
    p.pitch = s_pitch;
    p.roll  = s_roll;
    return p;
}

uint32_t algo_get_steps() { return s_stepCount; }
uint32_t algo_get_jumps() { return s_jumpCount; }

void algo_reset_counters() {
    s_stepCount = 0; s_jumpCount = 0;
    s_stepFiltered = 1.0f; s_jumpFiltered = 1.0f;
    s_stepAbove = false; s_jumpAbove = false;
}
