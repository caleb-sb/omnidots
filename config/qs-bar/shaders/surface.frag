#version 440

// Floating rounded bar + popout card rendered as one SDF, blended with a circular
// smooth-min so the card grows out of the bar with concave fillets
// (the caelestia "blob" look).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // item size in px
    vec4 bar;       // x, y, w, h
    vec4 card;      // x, y, w, h
    vec4 color;
    float radius;   // card corner radius
    float smoothing;// fillet radius where card meets bar
    vec2 stretch;   // jelly scale (x, y) applied to the card
    vec2 anchor;    // point the stretch is anchored at
    float barRadius;
    float surfaceOpacity; // see-through, blurred behind by Hyprland
};

float sdBox(vec2 p, vec2 c, vec2 h) {
    vec2 d = abs(p - c) - h;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sdRoundedBox(vec2 p, vec2 c, vec2 h, float r) {
    vec2 d = abs(p - c) - h + vec2(r);
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

// Circular smooth min: fillet is a true arc of radius k tangent to both shapes.
float smin(float a, float b, float k) {
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

void main() {
    vec2 p = qt_TexCoord0 * size;

    float d = sdRoundedBox(p, bar.xy + bar.zw * 0.5, bar.zw * 0.5, barRadius);

    if (card.z > 0.5 && card.w > 0.5) {
        vec2 q = anchor + (p - anchor) / stretch;
        float r = min(radius, 0.5 * min(card.z, card.w));
        float dc = sdRoundedBox(q, card.xy + card.zw * 0.5, card.zw * 0.5, r) * min(stretch.x, stretch.y);
        // The card only exists from the bar's middle down, so the bar's own
        // rounded top corners are never covered.
        dc = max(dc, bar.y + bar.w * 0.5 - p.y);
        d = smin(d, dc, smoothing);
    }

    float a = clamp(0.5 - d, 0.0, 1.0);
    float alpha = color.a * surfaceOpacity;
    fragColor = vec4(color.rgb, 1.0) * alpha * a * qt_Opacity;
}
