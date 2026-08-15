import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const sourceRoot = path.resolve(import.meta.dirname, "..");
const marketplacePath = path.join(sourceRoot, ".agents", "plugins", "marketplace.json");
const marketplace = JSON.parse(fs.readFileSync(marketplacePath, "utf8"));
const pluginDirectories = fs.readdirSync(path.join(sourceRoot, "plugins"), { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => path.join(sourceRoot, "plugins", entry.name));

assert.equal(marketplace.name, "agent-os");

for (const pluginRoot of pluginDirectories) {
  const manifest = JSON.parse(fs.readFileSync(path.join(pluginRoot, ".codex-plugin", "plugin.json"), "utf8"));
  assert.equal(manifest.name, path.basename(pluginRoot));
  assert.match(manifest.version, /^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/u);
  assert.equal(manifest.license, "MIT");
  assert.equal(manifest.skills, "./skills/");
  assert(Array.isArray(manifest.interface?.defaultPrompt));
  assert(manifest.interface.defaultPrompt.length <= 3);

  const entry = marketplace.plugins.find((plugin) => plugin.name === manifest.name);
  assert(entry, `Missing marketplace entry for ${manifest.name}`);
  assert.equal(entry.source.path, `./plugins/${manifest.name}`);
  assert.equal(entry.policy.installation, "AVAILABLE");
  assert.equal(entry.policy.authentication, "ON_INSTALL");

  const skillPath = path.join(pluginRoot, "skills", manifest.name, "SKILL.md");
  const skill = fs.readFileSync(skillPath, "utf8");
  assert.match(skill, new RegExp(`^---\\nname: ${manifest.name}\\ndescription: .+\\n---\\n`, "u"));
  assert(!skill.includes("[TODO:"), `TODO placeholder remains in ${skillPath}`);
}

process.stdout.write(`${pluginDirectories.length} Agent OS plugin packages validated.\n`);
