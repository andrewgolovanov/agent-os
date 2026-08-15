#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { atomicWrite, fail, parseArgs, resolveProjectRoot } from "./lib/common.mjs";

const EVENTS = ["SessionStart", "UserPromptSubmit", "Stop"];
const scriptPath = fileURLToPath(new URL("./hook.mjs", import.meta.url));
const command = `${JSON.stringify(process.execPath)} ${JSON.stringify(scriptPath)}`;

function isContextLoopCommand(value) {
  return typeof value === "string" && /context-loop[/\\].*[/\\]hook\.mjs/u.test(value);
}

function loadDocument(filePath) {
  if (!fs.existsSync(filePath)) return {};
  try {
    const value = JSON.parse(fs.readFileSync(filePath, "utf8"));
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("top-level JSON must be an object");
    return value;
  } catch (error) {
    throw new Error(`Refusing to overwrite invalid ${filePath}: ${error.message}`);
  }
}

function buildDocument(existing) {
  const document = structuredClone(existing);
  const hooks = document.hooks && typeof document.hooks === "object" && !Array.isArray(document.hooks) ? document.hooks : {};
  const changes = [];

  for (const eventName of EVENTS) {
    const existingEntries = Array.isArray(hooks[eventName]) ? hooks[eventName] : [];
    const cleanedEntries = [];
    let foundExact = false;
    let changed = false;

    for (const entry of existingEntries) {
      if (!entry || typeof entry !== "object" || !Array.isArray(entry.hooks)) {
        cleanedEntries.push(entry);
        continue;
      }
      const nextHooks = [];
      for (const hook of entry.hooks) {
        if (hook?.command === command && !foundExact) {
          foundExact = true;
          if (hook.type !== "command" || hook.timeout !== 30) changed = true;
          nextHooks.push({ ...hook, type: "command", command, timeout: 30 });
        } else if (isContextLoopCommand(hook?.command)) {
          changed = true;
        } else {
          nextHooks.push(hook);
        }
      }
      if (nextHooks.length) cleanedEntries.push({ ...entry, hooks: nextHooks });
      else if (entry.hooks.length) changed = true;
    }

    if (!foundExact) {
      cleanedEntries.push({ hooks: [{ type: "command", command, timeout: 30 }] });
      changed = true;
    }
    if (changed) changes.push(eventName);
    hooks[eventName] = cleanedEntries;
  }
  document.hooks = hooks;
  return { document, changes };
}

try {
  const args = parseArgs();
  const projectRoot = resolveProjectRoot(args, { allowMissing: true });
  const hooksPath = path.join(projectRoot, ".codex", "hooks.json");
  const existing = loadDocument(hooksPath);
  const { document, changes } = buildDocument(existing);
  const output = `${JSON.stringify(document, null, 2)}\n`;

  if (args["dry-run"]) {
    process.stdout.write(`${JSON.stringify({ dry_run: true, path: hooksPath, changes, command, document }, null, 2)}\n`);
  } else {
    atomicWrite(hooksPath, output);
    process.stdout.write(`Context Loop hooks configured at ${hooksPath}.\nChanged events: ${changes.length ? changes.join(", ") : "none"}\nReview and trust them with /hooks in Codex.\n`);
  }
} catch (error) {
  fail(error);
}
