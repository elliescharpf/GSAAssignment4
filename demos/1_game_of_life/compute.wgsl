struct RDParams {
    dA:   f32,
    dB:   f32,
    feed: f32,
    kill: f32,
    dt:   f32,
    ox:   f32,
    oy:   f32
};

@group(0) @binding(0) var<uniform> res: vec2f;
@group(0) @binding(1) var<uniform> rd: RDParams;
@group(0) @binding(2) var<storage> statein: array<vec2f>;
@group(0) @binding(3) var<storage, read_write> stateout: array<vec2f>;

fn wrapCoord(x: i32, maxVal: i32) -> i32 {
    var r = x % maxVal;
    if (r < 0) { r += maxVal; }
    return r;
}

fn index(x: i32, y: i32) -> u32 {
    let w = i32(res.x);
    let h = i32(res.y);
    let xx = wrapCoord(x, w);
    let yy = wrapCoord(y, h);
    return u32(yy * w + xx);
}

@compute
@workgroup_size(8, 8)
fn cs(@builtin(global_invocation_id) gid: vec3u) {
    let x = i32(gid.x);
    let y = i32(gid.y);

    let w = i32(res.x);
    let h = i32(res.y);

    if (x >= w || y >= h) { return; }

    let idx = index(x, y);
    let ab = statein[idx];
    let a = ab.x;
    let b = ab.y;

    // Laplacian
    var lapA: f32 = 0.0;
    var lapB: f32 = 0.0;

    // Center
    {
        let c = statein[index(x, y)];
        lapA += -1.0 * c.x;
        lapB += -1.0 * c.y;
    }

    // Orthogonal
    {
        let n = statein[index(x, y - 1)];
        let s = statein[index(x, y + 1)];
        let e = statein[index(x + 1, y)];
        let wv = statein[index(x - 1, y)];

        lapA += 0.2 * (n.x + s.x + e.x + wv.x);
        lapB += 0.2 * (n.y + s.y + e.y + wv.y);
    }

    // Diagonal
    {
        let nw = statein[index(x - 1, y - 1)];
        let ne = statein[index(x + 1, y - 1)];
        let sw = statein[index(x - 1, y + 1)];
        let se = statein[index(x + 1, y + 1)];

        lapA += 0.05 * (nw.x + ne.x + sw.x + se.x);
        lapB += 0.05 * (nw.y + ne.y + sw.y + se.y);
    }

    // Orientation
    lapA += rd.ox * 0.1;
    lapB += rd.oy * 0.1;

    // Parameters
    let dA   = rd.dA;
    let dB   = rd.dB;
    let feed = rd.feed;
    let kill = rd.kill;
    let dt   = rd.dt;

    let reaction = a * b * b;

    let aNext = a + (dA * lapA - reaction + feed * (1.0 - a)) * dt;
    let bNext = b + (dB * lapB + reaction - (kill + feed) * b) * dt;

    stateout[idx] = vec2f(
        clamp(aNext, 0.0, 1.0),
        clamp(bNext, 0.0, 1.0)
    );
}