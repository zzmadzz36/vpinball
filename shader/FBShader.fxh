#ifdef GLSL
uniform sampler2D tex_tonemap_lut; // Precomputed Tonemapping LUT

#else // HLSL

texture Texture6; // Precomputed Tonemapping LUT
sampler2D tex_tonemap_lut : TEXUNIT6 = sampler_state
{
    Texture = (Texture6);
    MIPFILTER = NONE;
    MAGFILTER = LINEAR;
    MINFILTER = LINEAR;
    ADDRESSU = Clamp;
    ADDRESSV = Clamp;
    SRGBTexture = false;
};

#endif

// //////////////////////////////////////////////////////////////////////////////////////////////////
// Tonemapping

#define MAX_BURST 1000.0

float ReinhardToneMap(const float l)
{
    // The clamping (to an arbitrary high value) prevents overflow leading to nan/inf in turn rendered as black blobs (at least on NVidia hardware)
    return min(l * ((l * BURN_HIGHLIGHTS + 1.0) / (l + 1.0)), MAX_BURST); // overflow is handled by bloom
}
float2 ReinhardToneMap(const float2 color)
{
    // The clamping (to an arbitrary high value) prevents overflow leading to nan/inf in turn rendered as black blobs (at least on NVidia hardware)
    const float l = min(dot(color, float2(0.176204 + 0.0108109 * 0.5, 0.812985 + 0.0108109 * 0.5)), MAX_BURST); // CIE RGB to XYZ, Y row (relative luminance)
    return color * ((l * BURN_HIGHLIGHTS + 1.0) / (l + 1.0)); // overflow is handled by bloom
}
float3 ReinhardToneMap(const float3 color)
{
    // The clamping (to an arbitrary high value) prevents overflow leading to nan/inf in turn rendered as black blobs (at least on NVidia hardware)
    const float l = min(dot(color, float3(0.176204, 0.812985, 0.0108109)), MAX_BURST); // CIE RGB to XYZ, Y row (relative luminance)
    return color * ((l * BURN_HIGHLIGHTS + 1.0) / (l + 1.0)); // overflow is handled by bloom
}

#if 0
float3 FilmicToneMap(const float3 hdr, const float whitepoint) //!! test/experimental
{
    const float4 vh = float4(hdr,whitepoint);
    const float4 va = 1.425*vh + 0.05;
    const float4 vf = (vh*va + 0.004)/(vh*(va+0.55) + 0.0491) - 0.0821;
    return vf.rgb/vf.aaa;
}

// sRGB => XYZ => D65_2_D60 => AP1 => RRT_SAT
const mat3 ACESInputMat = mat3(
    0.59719, 0.35458, 0.04823,
    0.07600, 0.90834, 0.01566,
    0.02840, 0.13383, 0.83777
);

// ODT_SAT => XYZ => D60_2_D65 => sRGB
const mat3 ACESOutputMat = mat3(
     1.60475, -0.53108, -0.07367,
    -0.10208,  1.10813, -0.00605,
    -0.00327, -0.07276,  1.07602
);

vec3 RRTAndODTFit(vec3 v)
{
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return a / b;
}

vec3 ACESFitted(vec3 color)
{
    color = color * ACESInputMat;
    // Apply RRT and ODT
    color = RRTAndODTFit(color);
    color = color * ACESOutputMat;
    return color;
}
#endif

// Filmic Tonemapping Operators http://filmicworlds.com/blog/filmic-tonemapping-operators/
float3 FilmicToneMap(float3 color)
{
    //color = pow(color, float3(1.0 / 2.2, 1.0 / 2.2, 1.0 / 2.2));
    //color = ACESFitted(color);
    //color = pow(color, float3(2.2, 2.2, 2.2));

    // The clamping (to an arbitrary high value) prevents overflow leading to nan/inf in turn rendered as black blobs (at least on NVidia hardware)
    color = min(color, float3(MAX_BURST, MAX_BURST, MAX_BURST));
    const float3 x = max(float3(0., 0., 0.), color - 0.004); // Filmic Curve
    color = (x * (6.2 * x + .5)) / (x * (6.2 * x + 1.7) + 0.06);
    color = pow(color, float3(2.2, 2.2, 2.2));
    return color;
}

// Tony Mc MapFace Tonemapping (MIT licensed): see https://github.com/h3r2tic/tony-mc-mapface
// This tonemapping is similar to Reinhard but handles better highly saturated over powered colors
// (for these, it looks somewhat similar to AGX by desaturating them)
// It is more or less a Reinhard tonemapping followed by a color grade color correction
float3 TonyMcMapfaceToneMap(float3 color)
{
    const float LUT_DIMS = 48.0;

    // The clamping (to an arbitrary high value) prevents overflow leading to nan/inf in turn rendered as black blobs (at least on NVidia hardware)
    color = min(color, float3(MAX_BURST, MAX_BURST, MAX_BURST));

    // Apply a non-linear transform that the LUT is encoded with.
    float3 encoded = color / (color + float3(1.0, 1.0, 1.0));

    // Align the encoded range to texel centers.
    encoded.xy = encoded.xy * ((LUT_DIMS - 1.0) / LUT_DIMS) + 1.0 / (2.0 * LUT_DIMS);
    encoded.z *= (LUT_DIMS - 1.0);

    // We use a 2D texture so we need to do the linear filtering ourself.
    // This is fairly inefficient but needed until 3D textures are supported.
    const float y = (1.0 - encoded.y + floor(encoded.z)) / LUT_DIMS;
    const float3 a = texNoLod(tex_tonemap_lut, float2(encoded.x, y)).rgb;
    const float3 b = texNoLod(tex_tonemap_lut, float2(encoded.x, y + 1.0 / LUT_DIMS)).rgb;
    return lerp(a, b, frac(encoded.z));
}