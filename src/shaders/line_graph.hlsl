// D3D11 pixel shader — line graph renderer

cbuffer PSConstants : register(b0)
{
    float u_time;         // Seconds since playback started
    float2 u_resolution;  // Render target resolution in pixels
    float lineWidth;      // e.g. 2.75, range [0, 10]
                           // ---- 16 bytes ----
    float3 lineColor;     // e.g. (1, 0.5, 0.5), range [0, 1]
    uint pointCount;      // Number of valid entries in g_points
                           // ---- 16 bytes ----
};

// (x, y) pairs normalized to [0, 1], sorted ascending by x.
// Originally authored as 64-bit doubles on the CPU; converted to 32-bit
// float on upload since SM5 structured buffers don't reliably support
// double, and float32 precision is more than sufficient at [0,1] scale.
StructuredBuffer<float2> g_points : register(t0);

// Piecewise-linear height lookup over the supplied points, replacing the
// original texture-based height() function. Takes and returns pixel-space
// values to match the rest of the shader; internally converts to/from the
// normalized [0,1] space the points are stored in.
float height(float x)
{
    uint count = pointCount;
    if (count == 0)
        return 0.0;

    float xNorm = x / u_resolution.x;

    float yNorm;
    if (count == 1 || xNorm <= g_points[0].x)
    {
        yNorm = g_points[0].y;
    }
    else if (xNorm >= g_points[count - 1].x)
    {
        yNorm = g_points[count - 1].y;
    }
    else
    {
        // Linear scan to find the bracketing segment. Fine for typical
        // chart-sized point counts; for very large arrays, precompute a
        // per-pixel height buffer instead.
        yNorm = g_points[count - 1].y; // fallback, overwritten below
        for (uint i = 0; i < count - 1; i++)
        {
            float2 p0 = g_points[i];
            float2 p1 = g_points[i + 1];
            if (xNorm >= p0.x && xNorm <= p1.x)
            {
                float span = p1.x - p0.x;
                float t = (span > 0.0001) ? (xNorm - p0.x) / span : 0.0;
                yNorm = lerp(p0.y, p1.y, t);
                break;
            }
        }
    }

    return yNorm * u_resolution.y;
}

float distanceToLine(float2 a, float2 b, float2 p)
{
    float squaredLineLength = dot(b - a, b - a);
    float t = saturate(dot(p - a, b - a) / squaredLineLength);
    return distance(p, a + t * (b - a));
}

float4 main(float4 fragCoord : SV_Position) : SV_Target
{
    float lineHalfWidth = lineWidth / 2.0;
    float loopBound = ceil(lineHalfWidth) + 1.0;
    float dist = lineHalfWidth + 1.0;

    float2 previousPoint = float2(fragCoord.x - lineHalfWidth, height(fragCoord.x - lineHalfWidth));

    for (float i = -loopBound + 1.0; i <= loopBound; i += 1.0)
    {
        float2 currentPoint = float2(fragCoord.x + i, height(fragCoord.x + i));
        dist = min(dist, distanceToLine(previousPoint, currentPoint, fragCoord.xy));
        previousPoint = currentPoint;
    }

    float alpha = saturate(lineHalfWidth + 0.5 - dist);

    if (fragCoord.y < height(fragCoord.x))
        alpha = max(alpha, 0.3);

    return float4(lineColor * alpha, 1.0);
}
