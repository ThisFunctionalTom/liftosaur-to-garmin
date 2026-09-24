import { Profile } from '@garmin/fitsdk';
import catalog from '../shared/exercise-mappings.json' with { type: 'json' };

export const exerciseMappings = catalog.mappings;

function enumValue(type, name) {
  const entry = Object.entries(Profile.types[type] ?? {}).find(([, value]) => value === name);
  if (!entry) throw new Error(`Unknown FIT ${type}: ${name}`);
  return Number(entry[0]);
}

export const unknownExerciseCategory = enumValue('exerciseCategory', 'unknown');

const byName = new Map();
for (const mapping of exerciseMappings) {
  const metadata = mapping.category === null ? undefined : {
    category: enumValue('exerciseCategory', mapping.category),
    subtype: mapping.subtype === null ? undefined : enumValue(`${mapping.category}ExerciseName`, mapping.subtype),
  };
  for (const name of mapping.names) {
    const key = name.trim().toLowerCase();
    if (byName.has(key)) throw new Error(`Duplicate exercise mapping: ${name}`);
    byName.set(key, { mapping, metadata });
  }
}

export function exerciseMetadata(name) {
  return byName.get(name.trim().toLowerCase())?.metadata;
}

export function exerciseMapping(name) {
  return byName.get(name.trim().toLowerCase())?.mapping;
}
