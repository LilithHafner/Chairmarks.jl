import { setSafeTimers } from '@vitest/utils';
import { addSerializer } from '@vitest/snapshot';
import { r as resetRunOnceCounter } from './run-once.Olz_Zkd8.js';

let globalSetup = false;
async function setupCommonEnv(config) {
  resetRunOnceCounter();
  setupDefines(config.defines);
  if (globalSetup)
    return;
  globalSetup = true;
  setSafeTimers();
  if (config.globals)
    (await import('../chunks/integrations-globals.THajbSRg.js')).registerApiGlobally();
}
function setupDefines(defines) {
  for (const key in defines)
    globalThis[key] = defines[key];
}
async function loadDiffConfig(config, executor) {
  if (typeof config.diff !== "string")
    return;
  const diffModule = await executor.executeId(config.diff);
  if (diffModule && typeof diffModule.default === "object" && diffModule.default != null)
    return diffModule.default;
  else
    throw new Error(`invalid diff config file ${config.diff}. Must have a default export with config object`);
}
async function loadSnapshotSerializers(config, executor) {
  const files = config.snapshotSerializers;
  const snapshotSerializers = await Promise.all(
    files.map(async (file) => {
      const mo = await executor.executeId(file);
      if (!mo || typeof mo.default !== "object" || mo.default === null)
        throw new Error(`invalid snapshot serializer file ${file}. Must export a default object`);
      const config2 = mo.default;
      if (typeof config2.test !== "function" || typeof config2.serialize !== "function" && typeof config2.print !== "function")
        throw new Error(`invalid snapshot serializer in ${file}. Must have a 'test' method along with either a 'serialize' or 'print' method.`);
      return config2;
    })
  );
  snapshotSerializers.forEach((serializer) => addSerializer(serializer));
}

export { loadSnapshotSerializers as a, loadDiffConfig as l, setupCommonEnv as s };
