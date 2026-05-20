/**
 * @file hr_sensor.cpp
 * @brief AD8232 ECG heart rate sensor driver.
 *
 * Performs analog peak detection on the AD8232 output to compute BPM.
 * Uses threshold crossing on the R-wave peak to measure inter-beat
 * interval (IBI). Includes leads-off detection via LO+/LO- pins.
 *
 * Algorithm:
 * 1. Read ADC value at ~200 Hz.
 * 2. When signal crosses above HR_THRESHOLD → mark potential R-wave.
 * 3. When signal drops back below → confirm the peak.
 * 4. Measure time between consecutive peaks = IBI.
 * 5. BPM = 60000 / IBI (with moving average smoothing).
 */

#include "hr_sensor.h"
#include "config.h"

// ── State variables ──
static uint16_t s_bpm = 0;
static bool     s_aboveThreshold = false;
static unsigned long s_lastPeakMs = 0;

// Moving average for BPM smoothing (last 5 readings)
#define BPM_AVG_SIZE  5
static uint16_t s_bpmBuffer[BPM_AVG_SIZE] = {0};
static uint8_t  s_bpmIndex = 0;
static uint8_t  s_bpmCount = 0;  // How many valid readings we have

void hr_init() {
    pinMode(PIN_HR_LO_PLUS, INPUT);
    pinMode(PIN_HR_LO_MINUS, INPUT);
    // GPIO 34 is input-only, no need for pinMode on ADC pins
    analogReadResolution(12);    // 12-bit ADC (0–4095)
    analogSetAttenuation(ADC_11db); // Full 0–3.3V range

    Serial.println("[HR] AD8232 initialized.");
}

bool hr_leads_on() {
    // AD8232: LO+/LO- are HIGH when leads are OFF (disconnected)
    return (digitalRead(PIN_HR_LO_PLUS) == LOW &&
            digitalRead(PIN_HR_LO_MINUS) == LOW);
}

uint16_t hr_update() {
    // Check leads-off first
    if (!hr_leads_on()) {
        s_bpm = 0;
        s_aboveThreshold = false;
        return 0;
    }

    int adcValue = analogRead(PIN_HR_OUTPUT);
    unsigned long now = millis();

    // Peak detection: look for rising edge crossing the threshold
    if (adcValue > HR_THRESHOLD && !s_aboveThreshold) {
        s_aboveThreshold = true;

        // Calculate IBI from the last peak
        if (s_lastPeakMs > 0) {
            unsigned long ibi = now - s_lastPeakMs;

            // Validate IBI is physiologically plausible
            if (ibi >= HR_MIN_IBI_MS && ibi <= HR_MAX_IBI_MS) {
                uint16_t instantBpm = (uint16_t)(60000UL / ibi);

                // Add to moving average buffer
                s_bpmBuffer[s_bpmIndex] = instantBpm;
                s_bpmIndex = (s_bpmIndex + 1) % BPM_AVG_SIZE;
                if (s_bpmCount < BPM_AVG_SIZE) s_bpmCount++;

                // Compute average
                uint32_t sum = 0;
                for (uint8_t i = 0; i < s_bpmCount; i++) {
                    sum += s_bpmBuffer[i];
                }
                s_bpm = (uint16_t)(sum / s_bpmCount);
            }
        }
        s_lastPeakMs = now;
    }
    else if (adcValue < (HR_THRESHOLD - 200)) {
        // Hysteresis: require signal to drop well below threshold before next detection
        s_aboveThreshold = false;
    }

    return s_bpm;
}

uint16_t hr_get_bpm() {
    return s_bpm;
}
