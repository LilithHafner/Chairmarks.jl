import v8 from 'node:v8';
import { c as createForksRpcOptions, u as unwrapForksConfig } from '../vendor/utils.GbToHGHI.js';
import { r as runBaseTests } from '../vendor/base.Z38YsPLm.js';
import '@vitest/utils';
import 'vite-node/client';
import '../vendor/global.CkGT_TMy.js';
import '../vendor/execute.27Kk4lQF.js';
import 'node:vm';
import 'node:url';
import 'vite-node/utils';
import 'pathe';
import '@vitest/utils/error';
import '../path.js';
import 'node:fs';
import '../vendor/base.N3JkKp7j.js';

class ForksBaseWorker {
  getRpcOptions() {
    return createForksRpcOptions(v8);
  }
  async runTests(state) {
    const exit = process.exit;
    state.ctx.config = unwrapForksConfig(state.ctx.config);
    try {
      await runBaseTests(state);
    } finally {
      process.exit = exit;
    }
  }
}
var forks = new ForksBaseWorker();

export { forks as default };
