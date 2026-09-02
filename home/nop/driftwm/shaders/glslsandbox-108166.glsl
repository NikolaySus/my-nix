// Adapted for DriftWM from https://glslsandbox.com/e#108166.0
// Original GLSL Sandbox shader by its respective author.

precision highp float;

varying vec2 v_coords;

uniform float u_time;
uniform float u_zoom;
uniform vec2 size;

void main() {
    vec4 color = vec4(0.0);
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

        color += 0.001 / max(ring_distance, 0.000001) * halo_falloff * (
            1.0
            + cos(
                i * 0.9
                + u_time
                + length(position) * 6.0
                + vec4(0.0, 1.0, 2.0, 0.0)
            )
        );
    }

    // Keep every rendered frame opaque. Accumulating the original shader's
    // alpha component causes animated frames to brighten over time in DriftWM.
    gl_FragColor = vec4(color.rgb, 1.0);
}
