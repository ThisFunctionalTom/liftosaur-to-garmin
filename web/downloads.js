import { zipSync } from 'fflate';
import { convertWorkout } from './fit.js';
import { prepareWorkout } from './generated/Converter.js';

const safeName = name => name.replace(/[^A-Za-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 80) || 'workout';

export function describeRecord(record) {
  const workout = prepareWorkout(record.text);
  const date = new Date((workout.startTime + 631065600) * 1000);
  if (!Number.isFinite(date.getTime())) throw new Error('Invalid workout date');
  return {
    name: workout.name, date,
    sets: workout.sets.filter(set => set.active).length,
    filename: `${date.toISOString().slice(0, 19).replace(/:/g, '-')}_${safeName(workout.name)}_${record.id}.fit`,
  };
}

export function createDownload(records) {
  if (!records.length) throw new Error('Select at least one workout.');
  const files = Object.create(null);
  for (const record of records) {
    const { filename } = describeRecord(record);
    files[filename] = convertWorkout(record.text).bytes;
  }
  if (records.length === 1) {
    const [filename, bytes] = Object.entries(files)[0];
    return { filename, bytes, type: 'application/octet-stream' };
  }
  return { filename: 'liftosaur-workouts.zip', bytes: zipSync(files), type: 'application/zip' };
}
