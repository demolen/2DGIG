//GI shader
shader_type canvas_item;
render_mode unshaded;
uniform vec2 resolution = vec2(320.0, 180.0);
uniform sampler2D screen_tex:hint_screen_texture;
#define SAMPLES 16.0
#define bayerZoom mix(0.5, 8.0, .1 * 0.5 + 0.5)
#define iterBayerMat 2
#define ViewZoom 8.0
#define iResolution resolution
#define pi 3.14159265359
#define cs(a) vec2(cos(a), sin(a))

float boxSignedDistanceField(vec2 point, vec2 size) {
    vec2 distanceToEdges = abs(point) - size;
    return min(max(distanceToEdges.x, distanceToEdges.y), 0.0) + length(max(distanceToEdges, vec2(0)));
}

void addObject(inout float minDist, inout vec3 objectColor, float dist, vec3 color) {
    if (minDist > dist) {
        minDist = dist;
        objectColor = color;
    }
}

vec4 sceneDescription(vec2 uv, float sdf) {
    float minDist = 1e9;
    vec3 objectColor = vec3(0);
	//taken from godot sdf_texture
	addObject(minDist, objectColor, sdf, vec3(0.1, 0.1, 1.0));
    addObject(minDist, objectColor, boxSignedDistanceField(uv - vec2(-3, 1), vec2(1, 1)), vec3(0.6, 0.8, 1.0));
    addObject(minDist, objectColor, length(uv - vec2(3, 1)) - 1.0, vec3(1.0, 0.9, 0.8));
    addObject(minDist, objectColor, length(uv - vec2(0.3 * sin(TIME), -2)) - 0.5, vec3(0.0, 0.1, 0.0));
    addObject(minDist, objectColor, boxSignedDistanceField(uv, vec2(1.5, 0.1)), vec3(0.9, 0.1, 0.1));
    return vec4(objectColor, minDist);
}

vec4 rayMarch(vec2 startPos, vec2 direction, float sdf) {
    float totalDistance = 0.0;
    for (int i = 55; i > 0; i--) {
        vec4 sceneInfo = sceneDescription(startPos, sdf);
        if (sceneInfo.w < 1e-1) return vec4(sceneInfo.xyz, totalDistance);
        if (sceneInfo.w > 10.0) return vec4(0, 0, 0, totalDistance);
        startPos += direction * sceneInfo.w;
        totalDistance += sceneInfo.w;
    }
    return vec4(0, 0, 0, totalDistance);
}

float getBayerValue(vec2 pixelPos) {
    ivec2 p = ivec2(pixelPos);
    int value = 0;
    for (int i = 0; i < iterBayerMat; i++) {
        int shift = iterBayerMat - 1 - i;
        ivec2 b = (p >> shift) & ivec2(1);
        value += (4 - b.x - (b.y << 1)) % 4 << (2 * i);
    }
    return float(value) / float(1 << (iterBayerMat * 2));
}

void fragment() {
	//texture SDF
	float sdf = texture_sdf(screen_uv_to_sdf(SCREEN_UV));
	//
    float aspectRatio = resolution.x / resolution.y;
    vec2 uv = UV;
    vec2 adjustedUV = (uv - 0.5) * ViewZoom * vec2(aspectRatio, 1.0);
    vec3 finalColor = vec3(0);
    float phi = sqrt(5.0) * 0.5 - 0.5;

    for (float i = 0.0; i < SAMPLES; i++) {
        float scale = 1.0;
        //float angle = i * (2.0 * pi / SAMPLES);
		//float angle = (i + getBayerValue(bayerZoom * adjustedUV * phi * ViewZoom * iResolution.x + i + 1.61) / scale) / SAMPLES * 2.0 * pi * scale;
        float angle = (i + getBayerValue(bayerZoom * adjustedUV * phi * ViewZoom * iResolution.x + i) / scale) / SAMPLES * 2.0 * pi * scale;
		//finalColor += rayMarch(adjustedUV, cs(angle));

		vec4 result = rayMarch(adjustedUV, cs(angle), sdf);


		// Apply distance-based attenuation
		float attenuation = exp(-0.4 * result.w);

        finalColor += result.rgb * attenuation;

    }

    finalColor /= SAMPLES;
    COLOR = vec4(finalColor * 2.0, 1.0);
	//COLOR = sceneDescription(adjustedUV,sdf).wwww;
	//COLOR = vec4((sdf>.001)?1.0:0.0);
}