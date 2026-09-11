import { createHash } from 'node:crypto';
import { readFile, readdir, writeFile } from 'node:fs/promises';
import { join, relative, resolve } from 'node:path';

// Build an explicit static-asset precache; no runtime caching or API responses.
export function offlineApp() {
  let outDir;
  return {
    name: 'liftosaur-offline-app',
    apply: 'build',
    configResolved(config) { outDir = resolve(config.root, config.build.outDir); },
    async closeBundle() {
      async function files(dir) {
        const entries = await readdir(dir, { withFileTypes: true });
        const paths = await Promise.all(entries.map(entry => entry.isDirectory()
          ? files(join(dir, entry.name)) : [join(dir, entry.name)]));
        return paths.flat();
      }
      const assets = (await files(outDir)).filter(path => path !== join(outDir, 'sw.js')).sort();
      const source = await readFile(new URL('./service-worker.js', import.meta.url), 'utf8');
      const hash = createHash('sha256').update(source);
      for (const path of assets) hash.update(relative(outDir, path)).update(await readFile(path));
      const script = source
        .replace('__APP_VERSION__', JSON.stringify(hash.digest('hex').slice(0, 16)))
        .replace('__APP_ASSETS__', JSON.stringify(assets.map(path => relative(outDir, path).replaceAll('\\', '/'))));
      await writeFile(join(outDir, 'sw.js'), script);
    },
  };
}
