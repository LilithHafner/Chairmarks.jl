import { VitestRunner, VitestRunnerImportSource, Suite, Task, CancelReason, Test, Custom, TaskContext, ExtendedContext } from '@vitest/runner';
import { R as ResolvedConfig } from './reporters-MmQN-57K.js';
import * as tinybench from 'tinybench';
import 'vite';
import 'vite-node';
import '@vitest/snapshot';
import '@vitest/expect';
import '@vitest/runner/utils';
import '@vitest/utils';
import 'vite-node/client';
import '@vitest/snapshot/manager';
import 'vite-node/server';
import 'node:worker_threads';
import 'node:fs';
import 'chai';

declare class VitestTestRunner implements VitestRunner {
    config: ResolvedConfig;
    private snapshotClient;
    private workerState;
    private __vitest_executor;
    private cancelRun;
    constructor(config: ResolvedConfig);
    importFile(filepath: string, source: VitestRunnerImportSource): unknown;
    onBeforeRunFiles(): void;
    onAfterRunSuite(suite: Suite): Promise<void>;
    onAfterRunTask(test: Task): void;
    onCancel(_reason: CancelReason): void;
    onBeforeRunTask(test: Task): Promise<void>;
    onBeforeRunSuite(suite: Suite): Promise<void>;
    onBeforeTryTask(test: Task): void;
    onAfterTryTask(test: Task): void;
    extendTaskContext<T extends Test | Custom>(context: TaskContext<T>): ExtendedContext<T>;
}

declare class NodeBenchmarkRunner implements VitestRunner {
    config: ResolvedConfig;
    private __vitest_executor;
    constructor(config: ResolvedConfig);
    importTinybench(): Promise<typeof tinybench>;
    importFile(filepath: string, source: VitestRunnerImportSource): unknown;
    runSuite(suite: Suite): Promise<void>;
    runTask(): Promise<void>;
}

export { NodeBenchmarkRunner, VitestTestRunner };
