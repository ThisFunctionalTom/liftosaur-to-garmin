import { readFileSync, writeFileSync } from 'node:fs';

const catalog = JSON.parse(readFileSync(new URL('../../tests/liftosaur-exercises.json', import.meta.url), 'utf8'));
const shared = JSON.parse(readFileSync(new URL('../../shared/exercise-mappings.json', import.meta.url), 'utf8'));
const byName = new Map(shared.mappings.flatMap(entry => entry.names.map(name => [name.toLowerCase(), entry])));
const groups = ['exact', 'generic', 'category', 'unsupported'];
const entries = catalog.names.map(name => {
  const mapping = byName.get(name.toLowerCase());
  if (!mapping) throw new Error(`Missing mapping decision for ${name}`);
  return { name, ...mapping };
});
const counts = Object.fromEntries(groups.map(group => [group, entries.filter(entry => entry.quality === group).length]));
const cell = text => (text ?? '—').replaceAll('|', '\\|');
const lines = [
  '# Liftosaur exercise mapping coverage', '',
  `Catalog snapshot: ${catalog.date}, from Liftosaur MCP \`list_exercises\`.`,
  `Garmin FIT profile: ${shared.fitProfileVersion}. Equipment variants count separately.`,
  'This report is generated from [the shared mappings](../shared/exercise-mappings.json)',
  'and [the catalog snapshot](../tests/liftosaur-exercises.json).', '',
  '| Decision | Built-in names |', '| --- | ---: |',
  ...groups.map(group => `| ${group} | ${counts[group]} |`),
  `| Total | ${entries.length} |`, '',
  'Every built-in name has an explicit decision. Exact and generic entries include',
  'a Garmin category and subtype. Generic entries lose the detail stated below.',
  'Category-only and unsupported entries may still display as Unknown in Garmin.',
  'Unknown custom names also remain unknown; no fuzzy matching is used.', '',
  'Defaults were checked against [Liftosaur exercise definitions](https://github.com/astashov/liftosaur/blob/master/src/models/exercise.ts).',
  'SDK symbol validity and numeric agreement are checked against both installed Garmin SDKs.',
  'This validates FIT metadata, not Garmin Connect display behavior for every exercise.', '',
];
for (const group of groups) {
  lines.push(`## ${group}`, '', '| Liftosaur name | Garmin category | Garmin subtype | Limitation |', '| --- | --- | --- | --- |');
  for (const entry of entries.filter(entry => entry.quality === group)) {
    lines.push(`| ${cell(entry.name)} | ${cell(entry.category)} | ${cell(entry.subtype)} | ${cell(entry.note)} |`);
  }
  lines.push('');
}
const catalogKeys = new Set(catalog.names.map(name => name.toLowerCase()));
const extraNames = shared.mappings.flatMap(entry => entry.names).filter(name => !catalogKeys.has(name.toLowerCase()));
lines.push('## Additional aliases and imported names', '',
  `The catalog also retains ${extraNames.length} names outside the built-in snapshot:`, '',
  ...extraNames.map(name => `- ${name}`), '',
  'Regenerate with `npm run audit:mappings --prefix web` after editing the shared mappings.', '');
writeFileSync(new URL('../../docs/exercise-catalog-audit.md', import.meta.url), lines.join('\n'));
console.log(`Audited ${entries.length} built-in names: ${JSON.stringify(counts)}; ${extraNames.length} additional aliases/imported names.`);
