#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fail, parseArgs, resolveProjectRoot } from "./lib/common.mjs";

const EVENTS = ["SessionStart", "UserPromptSubmit", "Stop"];

function readJsonStrict(filePath) {
  if (!fs.existsSync(filePath)) return { exists: false, value: {} };
  try {
    return { exists: true, value: JSON.parse(fs.readFileSync(filePath, "utf8")) };
  } catch (error) {
    return { exists: true, error: error.message, value: null };
  }
}

function commandIsContextLoop(command) {
  return typeof command === "string" && /context-loop[/\\].*[/\\]hook\.mjs/u.test(command);
}

function inspectHooks(hooksPath) {
  const parsed = readJsonStrict(hooksPath);
  if (parsed.error) return { path: hooksPath, exists: true, valid: false, error: parsed.error, installed: false, missing_events: EVENTS };
  const hooks = parsed.value?.hooks && typeof parsed.value.hooks === "object" ? parsed.value.hooks : {};
  const missing = EVENTS.filter((eventName) => {
    const entries = Array.isArray(hooks[eventName]) ? hooks[eventName] : [];
    return !entries.some((entry) => Array.isArray(entry?.hooks) && entry.hooks.some((hook) => commandIsContextLoop(hook?.command)));
  });
  return { path: hooksPath, exists: parsed.exists, valid: true, installed: missing.length === 0, missing_events: missing };
}

function hooksFeature(projectRoot) {
  const paths = [path.join(projectRoot, ".codex", "config.toml"), path.join(os.homedir(), ".codex", "config.toml")];
  const inspected = [];
  let detected = false;
  for (const filePath of paths) {
    if (!fs.existsSync(filePath)) continue;
    const content = fs.readFileSync(filePath, "utf8");
    const enabled = /^\s*(?:hooks|codex_hooks)\s*=\s*true\s*(?:#.*)?$/mu.test(content);
    detected ||= enabled;
    inspected.push({ path: filePath, enabled_line_detected: enabled });
  }
  return { enabled_line_detected: detected, inspected };
}

try {
  const args = parseArgs();
  const projectRoot = resolveProjectRoot(args, { allowMissing: true });
  const hooks = inspectHooks(path.join(projectRoot, ".codex", "hooks.json"));
  const feature = hooksFeature(projectRoot);
  let codexVersion = null;
  try {
    codexVersion = execFileSync("codex", ["--version"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
  } catch {
    // Codex Desktop may still host the skill even when no CLI is on PATH.
  }
  const result = {
    ready: hooks.valid && hooks.installed && feature.enabled_line_detected,
    project_root: projectRoot,
    node: process.version,
    codex_version: codexVersion,
    hooks,
    hooks_feature: feature,
    notes: [
      ...(hooks.installed ? [] : ["Project-local Context Loop hooks are not installed."]),
      ...(feature.enabled_line_detected ? [] : ["No hooks = true or codex_hooks = true line was detected in the inspected Codex config files."]),
      "Hook trust and whether the current thread loaded new hooks must be reviewed inside Codex with /hooks.",
    ],
  };
  process.stdout.write(args.json ? `${JSON.stringify(result, null, 2)}\n` : `${result.ready ? "ready" : "setup-required"}\n`);
} catch (error) {
  fail(error);
}
