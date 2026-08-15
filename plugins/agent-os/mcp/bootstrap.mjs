import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, realpathSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const modulePath = fileURLToPath(import.meta.url);
const pluginRoot = resolve(dirname(modulePath), "..");

function absolutePath(value) {
  return typeof value === "string" && isAbsolute(value) && value !== "/" ? resolve(value) : null;
}

function readPointer(path) {
  if (!existsSync(path)) return null;
  return absolutePath(readFileSync(path, "utf8").trim());
}

function validSource(path) {
  return Boolean(path)
    && existsSync(path)
    && existsSync(join(path, "bin", "agent-os"))
    && existsSync(join(path, "tools", "task-board"))
    && statSync(join(path, "tools", "task-board")).isFile();
}

export function ensureAgentOSRuntime(environment = process.env) {
  const userHome = absolutePath(environment.HOME) || homedir();
  const activeHomePointer = absolutePath(environment.AGENT_OS_HOME_POINTER)
    || join(userHome, ".config", "agent-os", "home");
  const activeHome = readPointer(activeHomePointer);
  const legacyRoot = absolutePath(environment.WORKSPACE_CONSOLE_ROOT);
  const configuredHome = absolutePath(environment.AGENT_OS_HOME)
    || legacyRoot
    || activeHome
    || join(userHome, ".agent-os");
  const bundledSource = realpathSync(join(pluginRoot, "runtime"));
  const explicitSource = absolutePath(environment.AGENT_OS_SOURCE_ROOT)
    || absolutePath(environment.WORKSPACE_CONSOLE_SOURCE_ROOT)
    || legacyRoot;
  const requestedSource = validSource(explicitSource) ? explicitSource : bundledSource;

  const executable = join(requestedSource, "bin", "agent-os");
  const result = spawnSync("/usr/bin/ruby", [
    executable,
    "bootstrap",
    "--source", requestedSource,
    "--home", configuredHome,
    "--apply",
    "--json",
  ], {
    encoding: "utf8",
    env: environment,
    stdio: ["ignore", "pipe", "pipe"],
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(result.stderr.trim() || `Agent OS bootstrap exited ${result.status}`);
  }

  if (!existsSync(activeHomePointer)) {
    mkdirSync(dirname(activeHomePointer), { recursive: true, mode: 0o700 });
    writeFileSync(activeHomePointer, `${configuredHome}\n`, { encoding: "utf8", flag: "wx", mode: 0o600 });
  }

  const selectedSource = validSource(explicitSource)
    ? explicitSource
    : readPointer(join(configuredHome, "source-path"));
  if (!validSource(selectedSource)) throw new Error("Agent OS bootstrap did not produce a valid source runtime");

  return {
    homeRoot: realpathSync(configuredHome),
    sourceRoot: realpathSync(selectedSource),
  };
}

if (process.argv[1] && resolve(process.argv[1]) === modulePath) {
  try {
    process.stdout.write(`${JSON.stringify(ensureAgentOSRuntime())}\n`);
  } catch (error) {
    process.stderr.write(`agent-os bootstrap: ${error.message}\n`);
    process.exitCode = 1;
  }
}
