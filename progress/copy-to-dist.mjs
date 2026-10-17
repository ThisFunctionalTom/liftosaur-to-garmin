import { cp, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const source = resolve(here, 'site');
const target = resolve(here, '../web/dist/progress');

await mkdir(target, { recursive: true });
await cp(source, target, { recursive: true, force: true });
console.log(`Copied progress page into ${target}`);
