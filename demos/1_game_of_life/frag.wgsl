struct RDParams {
    dA: f32,
    dB: f32,
    feed: f32,
    kill: f32,
    dt: f32,
    ox: f32,
    oy: f32
};

@group(0) @binding(0) var<uniform> res: vec2f;
@group(0) @binding(1) var<storage> state: array<vec2f>;

@fragment
fn fs(@builtin(position) pos: vec4f) -> @location(0) vec4f {
    let x = i32(pos.x);
    let y = i32(pos.y);
    let w = i32(res.x);

    let idx: u32 = u32(y * w + x);
    let ab = state[idx];
    let b = ab.y;

    // Dark blue and light blue colors
    let color = vec3f(
        0.0,
        b * 0.8 + 0.2,
        0.5 + b * 0.5
    );
    return vec4f(color, 1.0);
}