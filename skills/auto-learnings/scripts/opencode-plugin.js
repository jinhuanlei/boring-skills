// auto-learnings — OpenCode plugin: appends the learnings stores to the system prompt.
// Install by symlinking this file to ~/.config/opencode/plugins/auto-learnings.js.
// One default export serves both plugin APIs: V2 reads `id` + `setup`, V1 calls `server()`.

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Resolve through the symlink so recall.sh is found next to the real file.
const here = path.dirname(fs.realpathSync(fileURLToPath(import.meta.url)));
const script = path.join(here, 'recall.sh');

// Read on every call, so entries captured mid-session show up on the next turn.
function recall(directory) {
  try {
    return execFileSync('/bin/sh', [script], {
      encoding: 'utf8',
      timeout: 5000,
      // The plugin writes into the system prompt, not a hook output, so the hook size warning doesn't apply.
      env: { ...process.env, CLAUDE_PROJECT_DIR: directory || process.cwd(), AUTO_LEARNINGS_NO_SIZE_WARNING: '1' },
    }).trim();
  } catch {
    return '';
  }
}

export default {
  id: 'auto-learnings',

  async setup(ctx) {
    const add = (event) => {
      const text = recall(ctx.location?.directory);
      if (text) event.system.push({ type: 'text', text });
    };
    await ctx.session.hook('context', add);
    await ctx.session.hook('compaction', add);
  },

  async server({ directory } = {}) {
    return {
      'experimental.chat.system.transform': async (_input, output) => {
        const text = recall(directory);
        if (!text) return;
        if (output.system.length > 0) output.system[output.system.length - 1] += '\n\n' + text;
        else output.system.push(text);
      },
    };
  },
};
