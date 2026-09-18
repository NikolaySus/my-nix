// Adapted for DriftWM from https://glslsandbox.com/e#108166.0
// Original GLSL Sandbox shader by its respective author.

precision highp float;

varying vec2 v_coords;

uniform float u_time;
uniform float u_zoom;
uniform float u_locked;
uniform float u_lock_event_age;
uniform vec2 size;

const float EFFECT_DURATION = 2.0;
const float OPENING_DURATION = 0.4;
const float LOCK_VOLTAGE = 0.45;
const float UNLOCK_VOLTAGE = 1.35;
const float DROPOUT_DEPTH = 0.85;
const float DROPOUT_HOLD = 0.2;
const float FLICKER_PERIOD = 0.7;
const float FLICKER_EDGE_FADE = 0.07;

float ring_hash(float seed) {
    return fract(sin(seed * 127.1 + 311.7) * 43758.5453);
}

float soft_transition(float start, float end, float value) {
    float t = clamp((value - start) / (end - start), 0.0, 1.0);
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float dropout(float age, float center, float width) {
    float half_hold = DROPOUT_HOLD * 0.5;
    return 1.0 - soft_transition(half_hold, half_hold + width * 0.5, abs(age - center));
}

float ring_dropout(float ring, float age) {
    float seed = ring * 19.7 + u_locked * 73.1;
    // Apply the opening delay once, then stagger rings across the full cycle.
    float width = mix(0.08, 0.14, ring_hash(seed + 2.0));
    float elapsed = max(age - OPENING_DURATION, 0.0);
    float phase = ring_hash(seed) * FLICKER_PERIOD;
    // Fade partial pulses at the effect boundaries instead of cutting them off.
    float envelope = soft_transition(0.0, FLICKER_EDGE_FADE, elapsed)
        * (1.0 - soft_transition(EFFECT_DURATION - FLICKER_EDGE_FADE, EFFECT_DURATION, age));
    return DROPOUT_DEPTH * envelope * dropout(
        mod(elapsed + phase, FLICKER_PERIOD), FLICKER_PERIOD * 0.5, width
    );
}

void main() {
    vec4 color = vec4(0.0);
    vec3 missing_light = vec3(0.0);
    bool event_active = u_lock_event_age >= 0.0 && u_lock_event_age < EFFECT_DURATION;
    float max_coord = max(size.x, size.y);
    float aspect = size.y / size.x;

    vec2 position = (v_coords * size) / max_coord
        - vec2(0.5, aspect * 0.5);
    position *= 4.0 / u_zoom;

    for (float i = 0.0; i < 100.0; i += 0.9) {
        float ring_distance = abs(
            length(
                position
                + vec2(cos(i / 4.0 + u_time), sin(i * 0.45 + u_time))
                    * sin(u_time * 0.6 + i * 0.76)
            )
            - sin(i + u_time * 0.5) / 60.0
            - 0.01
        );

        // Leave the bright ring core untouched, then gently tighten the halo.
        // Beyond this radius the original inverse-distance glow falls at
        // roughly distance^-1.45: visible, but less broad than the original.
        float halo_ratio = 0.006 / max(ring_distance, 0.000001);
        float halo_falloff = min(1.0, pow(halo_ratio, 0.45));

        vec4 ring_light = 0.001 / max(ring_distance, 0.000001) * halo_falloff * (
            1.0
            + cos(
                i * 0.9
                + u_time
                + length(position) * 6.0
                + vec4(0.0, 1.0, 2.0, 0.0)
            )
        );
        color += ring_light;
        if (event_active) {
            missing_light += ring_light.rgb * ring_dropout(i, u_lock_event_age);
        }
    }

    if (event_active) {
        // Attenuate display-range light, not unbounded shader radiance: this
        // makes saturated ring cores falter too, while preserving overlapping light.
        vec3 retained = vec3(1.0) - missing_light / max(color.rgb, vec3(0.000001));
        float opening = 1.0 - soft_transition(0.0, OPENING_DURATION, u_lock_event_age);
        float voltage = mix(1.0, mix(UNLOCK_VOLTAGE, LOCK_VOLTAGE, u_locked), opening);
        color.rgb = min(color.rgb, vec3(1.0)) * retained * voltage;
    }

    // Keep every rendered frame opaque. Accumulating the original shader's
    // alpha component causes animated frames to brighten over time in DriftWM.
    gl_FragColor = vec4(color.rgb, 1.0);
}
