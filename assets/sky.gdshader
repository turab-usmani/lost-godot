shader_type sky;

uniform vec3 bg_color : source_color = vec3(0.02, 0.01, 0.05);
uniform vec3 gas_color_1 : source_color = vec3(0.4, 0.1, 0.6);
uniform vec3 gas_color_2 : source_color = vec3(0.1, 0.3, 0.8);

uniform float drift_speed : hint_range(0.0, 1.0) = 0.02;
uniform float star_density : hint_range(0.0, 1000.0) = 600.0;
uniform sampler2D noise_tex; 

float hash(vec3 p) {
    p = fract(p * vec3(443.897, 441.423, 437.195));
    p += dot(p, p.yzx + 19.19);
    return fract((p.x + p.y) * p.z);
}

void sky() {
    float t = TIME * drift_speed;
    mat3 rotation = mat3(
        vec3(cos(t), 0.0, sin(t)),
        vec3(0.0, 1.0, 0.0),
        vec3(-sin(t), 0.0, cos(t))
    );
    
    vec3 dir = rotation * EYEDIR;
    vec3 final_color = bg_color;

    // 1. Dynamic Gas Clouds
    vec2 gas_uv = dir.xy + dir.z;
    float gas_noise = texture(noise_tex, gas_uv + (TIME * 0.01)).r;
    float gas_mask = smoothstep(0.4, 0.7, gas_noise);
    
    float pulse = sin(TIME * 0.5) * 0.1 + 0.9;
    vec3 nebula = mix(gas_color_1, gas_color_2, dir.y * 0.5 + 0.5) * pulse;
    final_color = mix(final_color, nebula, gas_mask * 0.5);

    // 2. Twinkling Stars
    vec3 star_grid = floor(dir * star_density);
    float star_rand = hash(star_grid);
    if (star_rand > 0.994) {
        float twinkle = sin(TIME * 3.0 + star_rand * 10.0) * 0.5 + 0.5;
        float star_intensity = smoothstep(0.0, 1.0, (star_rand - 0.994) * 150.0);
        final_color += vec3(star_intensity * twinkle);
    }

    // 3. The "Sun" with Flares (FIXED)
    vec3 sun_dir = rotation * LIGHT0_DIRECTION;
    float sun_dist = distance(dir, sun_dir);
    
    // Pulsing Core - Base radius increased to 0.07 so 0.07 - 0.02 = 0.05 (Safe from 0.04)
    float sun_pulse = sin(TIME * 2.0) * 0.02;
    float sun_disc = smoothstep(0.07 + sun_pulse, 0.04, sun_dist);
    final_color = mix(final_color, vec3(1.0, 1.0, 0.8), sun_disc);

    // 4. Roaming Supernova 
    vec3 nova_base_pos = normalize(vec3(0.5, 0.2, -0.8));
    vec3 nova_pos = rotation * nova_base_pos; 
    float nova_dist = distance(dir, nova_pos);
    
    if (nova_dist < 0.3) {
        float nova_core = smoothstep(0.15, 0.0, nova_dist);
        float rings = sin(nova_dist * 50.0 - TIME * 4.0);
        rings = step(0.8, rings); 
        final_color += vec3(0.4, 0.9, 1.0) * nova_core * rings * 0.6;
    }

    COLOR = final_color;
}