/*
  @license
	Rollup.js v4.12.1
	Wed, 06 Mar 2024 06:02:59 GMT - commit f44dac3170a671b0978afa3af43818617904f544

	https://github.com/rollup/rollup

	Released under the MIT License.
*/
export { version as VERSION, defineConfig, rollup, watch } from './shared/node-entry.js';
import './shared/parseAst.js';
import '../native.js';
import 'node:path';
import 'path';
import 'node:process';
import 'node:perf_hooks';
import 'node:fs/promises';
import 'tty';
