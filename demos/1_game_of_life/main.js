import { default as seagulls } from '../../gulls.js'
import { Pane } from 'https://cdn.jsdelivr.net/npm/tweakpane@4.0.3/dist/tweakpane.min.js';

const sg      = await seagulls.init(),
    frag    = await seagulls.import('./frag.wgsl'),
    compute = await seagulls.import('./compute.wgsl'),
    render  = seagulls.constants.vertex + frag

const width  = window.innerWidth
const height = window.innerHeight
const cells  = width * height

// RD parameters
const params = {
  dA: 1.0,
  dB: 0.5,
  feed: 0.055,
  kill: 0.062,
  dt: 1.0,
  ox: 0.0,
  oy: 0.0
};

// Uniform buffer
const rdUniform = sg.uniform([
  params.dA,
  params.dB,
  params.feed,
  params.kill,
  params.dt,
  params.ox,
  params.oy
]);

// TweakPane UI
const pane = new Pane();

pane.addBinding(params, 'dA', {min: 0.0, max: 2.0, step: 0.001})
    .on('change', updateUniform);
pane.addBinding(params, 'dB', {min: 0.0, max: 2.0, step: 0.001})
    .on('change', updateUniform);
pane.addBinding(params, 'feed', {min: 0.0, max: 0.1, step: 0.0001})
    .on('change', updateUniform);
pane.addBinding(params, 'kill', {min: 0.0, max: 0.1, step: 0.0001})
    .on('change', updateUniform);
pane.addBinding(params, 'dt', {min: 0.1, max: 5.0, step: 0.01})
    .on('change', updateUniform);
pane.addBinding(params, 'ox', {min: -1.0, max: 1.0, step: 0.01})
    .on('change', updateUniform);
pane.addBinding(params, 'oy', {min: -1.0, max: 1.0, step: 0.01})
    .on('change', updateUniform);

function updateUniform() {
  rdUniform.set([
    params.dA,
    params.dB,
    params.feed,
    params.kill,
    params.dt,
    params.ox,
    params.oy
  ]);
}

// 2 floats per cell: [A, B]
const state = new Float32Array(cells * 2)

// Initialize A = 1, B = 0
for (let i = 0; i < cells; i++) {
  state[2*i + 0] = 1.0
  state[2*i + 1] = 0.0
}

// Seed B = 1 in a small square
const cx = Math.floor(width / 2)
const cy = Math.floor(height / 2)
const r  = 10

for (let dy = -r; dy <= r; dy++) {
  for (let dx = -r; dx <= r; dx++) {
    const px = cx + dx
    const py = cy + dy
    if (px < 0 || px >= width || py < 0 || py >= height) continue
    const idx = py * width + px
    state[2*idx + 0] = 1.0
    state[2*idx + 1] = 1.0
  }
}

const statebuffer1 = sg.buffer(state)
const statebuffer2 = sg.buffer(state)
const res = sg.uniform([width, height])

const renderPass = await sg.render({
  shader: render,
  data: [
    res,
    sg.pingpong(statebuffer1, statebuffer2)
  ]
});

const computePass = sg.compute({
  shader: compute,
  data: [
    res,
    rdUniform,
    sg.pingpong(statebuffer1, statebuffer2)
  ],
  dispatchCount: [Math.ceil(width / 8), Math.ceil(height / 8), 1],
});

// computePass multiple times to speed it up
sg.run(computePass, computePass, computePass, computePass, renderPass)