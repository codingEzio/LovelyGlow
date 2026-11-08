enum GlowShaderSource {
    static let metal = """
        #include <metal_stdlib>
        using namespace metal;

        struct GlowUniforms {
            float4 base;
            float4 highlight;
            float4 warmth;
            float2 resolution;
            float2 holeOrigin;
            float2 holeSize;
            float holeRadius;
            float lineWidth;
            float spread;
            float opacity;
            float travel;
            float breathe;
            float comet;
            float sheen;
            float reduceTransparency;
            float focusWeight;
            float occluderCount;
            float arrive;
            float4 occluders[8];
        };

        struct Varying {
            float4 position [[position]];
        };

        static float sdRoundedBox(float2 p, float2 b, float r) {
            float radius = min(r, min(b.x, b.y));
            float2 q = abs(p) - b + radius;
            return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
        }

        static float wrap01(float value) {
            return value - floor(value);
        }

        static void considerPoint(float2 p, float2 candidate, float arcLen, thread float &bestD, thread float &bestArc) {
            float d = length(p - candidate);
            if (d < bestD) {
                bestD = d;
                bestArc = arcLen;
            }
        }

        static void considerArc(float2 p, float2 center, float start, float end, float origin, float r, thread float &bestD, thread float &bestArc) {
            float2 delta = p - center;
            float angle = atan2(delta.y, delta.x);
            if (angle < 0.0) {
                angle += 6.28318530718;
            }
            float clamped = clamp(angle, start, end);
            float2 candidate = center + float2(cos(clamped), sin(clamped)) * r;
            considerPoint(p, candidate, origin + (clamped - start) * r, bestD, bestArc);
        }

        static float perimeterPhase(float2 p, float2 inner, float r) {
            float halfW = inner.x + r;
            float halfH = inner.y + r;
            float leftLower = inner.y;
            float arc = 1.57079632679 * r;
            float bottom = 2.0 * inner.x;
            float right = 2.0 * inner.y;
            float top = 2.0 * inner.x;
            float total = 4.0 * inner.x + 4.0 * inner.y + 6.28318530718 * r;
            float bestD = 1.0e9;
            float bestArc = 0.0;

            float leftY = clamp(p.y, -inner.y, inner.y);
            float leftArc = leftY <= 0.0
                ? -leftY
                : leftLower + arc + bottom + arc + right + arc + top + arc + (inner.y - leftY);
            considerPoint(p, float2(-halfW, leftY), leftArc, bestD, bestArc);
            considerPoint(p, float2(halfW, clamp(p.y, -inner.y, inner.y)), leftLower + arc + bottom + arc + (inner.y + clamp(p.y, -inner.y, inner.y)), bestD, bestArc);
            considerPoint(p, float2(clamp(p.x, -inner.x, inner.x), -halfH), leftLower + arc + (clamp(p.x, -inner.x, inner.x) + inner.x), bestD, bestArc);
            considerPoint(p, float2(clamp(p.x, -inner.x, inner.x), halfH), leftLower + arc + bottom + arc + right + arc + (inner.x - clamp(p.x, -inner.x, inner.x)), bestD, bestArc);
            considerArc(p, float2(-inner.x, -inner.y), 3.14159265359, 4.71238898038, leftLower, r, bestD, bestArc);
            considerArc(p, float2(inner.x, -inner.y), 4.71238898038, 6.28318530718, leftLower + arc + bottom, r, bestD, bestArc);
            considerArc(p, float2(inner.x, inner.y), 0.0, 1.57079632679, leftLower + arc + bottom + arc + right, r, bestD, bestArc);
            considerArc(p, float2(-inner.x, inner.y), 1.57079632679, 3.14159265359, leftLower + arc + bottom + arc + right + arc + top, r, bestD, bestArc);
            return bestArc / max(total, 0.001);
        }

        vertex Varying glow_vertex(const device float2 *vertices [[buffer(0)]], uint vid [[vertex_id]]) {
            Varying out;
            out.position = float4(vertices[vid], 0.0, 1.0);
            return out;
        }

        fragment float4 glow_fragment(Varying in [[stage_in]], constant GlowUniforms &u [[buffer(1)]]) {
            float2 pixel = in.position.xy;
            int count = int(u.occluderCount + 0.5);
            for (int i = 0; i < 8; ++i) {
                if (i >= count) break;
                float4 box = u.occluders[i];
                if (pixel.x >= box.x && pixel.x <= box.x + box.z && pixel.y >= box.y && pixel.y <= box.y + box.w) {
                    return float4(0.0);
                }
            }

            float2 center = u.holeOrigin + u.holeSize * 0.5;
            float2 halfSize = u.holeSize * 0.5;
            float2 local = pixel - center;
            float radius = min(u.holeRadius, min(halfSize.x, halfSize.y));
            float d = sdRoundedBox(local, halfSize, radius);
            float aa = max(fwidth(d), 1.0);
            float band = max(u.spread, 1.0) + u.lineWidth * 2.0 + 4.0;
            if (d < -aa * 1.6 || d > band + aa) {
                return float4(0.0);
            }

            float2 inner = max(halfSize - radius, float2(0.0005));
            float phase = perimeterPhase(local, inner, radius);
            float delta = abs(wrap01(phase - u.travel));
            delta = min(delta, 1.0 - delta);
            float cometWidth = mix(0.09, 0.012, clamp(u.comet, 0.0, 1.0));
            float head = exp(-(delta * delta) / max(cometWidth, 0.001));

            float sigma = max(u.spread * 0.72, 1.5);
            float halo = exp(-(d * d) / (2.0 * sigma * sigma));
            float filament = exp(-((d - u.lineWidth * 0.12) * (d - u.lineWidth * 0.12)) / max(u.lineWidth * u.lineWidth * 0.26, 0.8));
            if (u.reduceTransparency > 0.5) {
                halo *= 0.22;
                filament = smoothstep(u.lineWidth + 0.8, 0.0, abs(d));
            }

            float travelMix = clamp(u.comet, 0.0, 1.0);
            float edge = smoothstep(-aa * 1.6, aa, d);
            float intensity = (halo * 0.82 + filament * 0.95) * u.opacity * u.breathe * u.focusWeight * clamp(u.arrive, 0.0, 1.0);
            intensity *= mix(1.0, 0.45 + 0.55 * head, travelMix);
            intensity *= edge;

            float hue = wrap01(phase - u.travel);
            float4 rim = mix(u.base, u.warmth, smoothstep(0.0, 0.55, hue));
            rim = mix(rim, u.highlight, head * u.sheen);
            float alpha = saturate(intensity);
            return float4(rim.rgb * alpha, alpha);
        }
        """
}
