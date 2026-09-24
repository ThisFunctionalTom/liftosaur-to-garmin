import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { Decoder, Stream } from '@garmin/fitsdk';
import { convertWorkout } from '../fit.js';
import { exerciseMappings, exerciseMapping, exerciseMetadata } from '../exercise-mappings.js';

function decode(bytes) {
  const decoder = new Decoder(Stream.fromByteArray(bytes));
  assert.equal(decoder.isFIT(), true);
  assert.equal(decoder.checkIntegrity(), true, 'FIT CRC and size must be valid');
  const { messages, errors } = decoder.read({
    convertTypesToStrings: false, convertDateTimesToDates: false,
    expandSubFields: false, expandComponents: false, mergeHeartRates: false,
  });
  assert.deepEqual(errors, []);
  // Each encoder generates its own serial number. All other fields must match.
  for (const group of Object.values(messages)) {
    for (const message of group) delete message.serialNumber;
  }
  return messages;
}

const fixtures = new URL('../../tests/fixtures/', import.meta.url);
const assistedNames = new Set([
  'assisted squat', 'chest dip, assisted', 'chin up, assisted',
  'chin up, leverage machine', 'pull up, assisted', 'pull up, band',
  'pull up, leverage machine', 'triceps dip, leverage machine',
  'pistol squat, leverage machine',
]);
for (const name of readdirSync(fixtures).filter(name => name.endsWith('.txt'))) {
  test(`Fable/JavaScript FIT matches .NET: ${name}`, () => {
    const source = readFileSync(new URL(name, fixtures), 'utf8');
    const actual = decode(convertWorkout(source, 12345).bytes);
    const expected = decode(readFileSync(new URL(`../../tests/output/${name.replace('.txt', '.fit')}`, import.meta.url)));
    assert.deepEqual(actual, expected);
  });
}

test('recent missing exercises encode Garmin category and subtype on steps and sets', () => {
  // Explicit FIT profile IDs, independent of the converter's mapping lookup.
  const cases = [
    ['Hanging Knee Raise', 16, 0],
    ['Hanging Leg Raise', 16, 1],
    ['Lat Pulldown', 21, 13],
    ['Pull Up, Leverage Machine', 21, 38],
    ['Chin Up, Leverage Machine', 21, 39],
    ['Triceps Dip, Leverage Machine', 30, 2],
    ['Seated Row', 23, 18],
    ['Lunge, Dumbbell', 17, 21],
    ['Incline Push Up', 22, 27],
  ];
  for (const [name, category, subtype] of cases) {
    const text = `2026-03-01T10:00:00Z / duration: 60s / exercises: {\n  ${name.toUpperCase()} / 1x5 10kg\n}`;
    const messages = decode(convertWorkout(text, 12345).bytes);
    assert.equal(messages.workoutStepMesgs[0].exerciseCategory, category, name);
    assert.equal(messages.workoutStepMesgs[0].exerciseName, subtype, name);
    const active = messages.setMesgs.find(set => set.setType === 1);
    assert.deepEqual(active.category, [category], name);
    assert.deepEqual(active.categorySubtype, [subtype], name);
  }
});

test('audited exercise names have categories except the unsupported leg extension machine', () => {
  const steps = readdirSync(fixtures).filter(name => name.startsWith('exercise-coverage-')).flatMap(name => {
    const source = readFileSync(new URL(name, fixtures), 'utf8');
    return decode(convertWorkout(source, 12345).bytes).workoutStepMesgs;
  });
  assert.equal(steps.length, 53);
  const unknown = steps.filter(step => step.exerciseCategory === undefined);
  assert.deepEqual(unknown.map(step => step.wktStepName), ['Leg Extension, Machine']);
  const machinePress = steps.find(step => step.wktStepName === 'Chest Press, Machine');
  assert.equal(machinePress.exerciseCategory, 0);
  assert.equal(machinePress.exerciseName, undefined, 'Do not mislabel a machine press as a barbell press');
});

test('empty and unrelated input are rejected', () => {
  for (const text of ['', '{}', 'not a workout']) {
    assert.throws(() => convertWorkout(text, 12345));
  }
});

test('every built-in exercise has an explicit, documented mapping decision', () => {
  const catalog = JSON.parse(readFileSync(new URL('../../tests/liftosaur-exercises.json', import.meta.url), 'utf8'));
  assert.equal(catalog.names.length, 364);
  for (const name of catalog.names) assert.ok(exerciseMapping(name), `Missing mapping decision: ${name}`);
  const seen = new Set();
  for (const entry of exerciseMappings) {
    assert.ok(['exact', 'generic', 'category', 'unsupported'].includes(entry.quality));
    assert.ok(entry.names.length > 0);
    for (const name of entry.names) {
      const key = name.trim().toLowerCase();
      assert.equal(seen.has(key), false, `Duplicate: ${name}`);
      seen.add(key);
      assert.equal(exerciseMapping(`  ${name.toUpperCase()}  `), entry);
    }
    assert.equal(entry.category === null, entry.quality === 'unsupported');
    assert.equal(entry.subtype === null, ['category', 'unsupported'].includes(entry.quality));
    if (entry.quality !== 'exact') assert.ok(entry.note.length > 0, `Explain the limitation: ${entry.names}`);
  }
});

test('all shared mappings encode the same exercise fields as the .NET SDK', () => {
  const reference = JSON.parse(readFileSync(new URL('../../tests/output/exercise-mappings.json', import.meta.url), 'utf8'));
  assert.equal(reference.length, exerciseMappings.reduce((count, entry) => count + entry.names.length, 0));
  for (const expected of reference) {
    const name = expected.name;
    const text = `2026-03-01T10:00:00Z / duration: 60s / exercises: {\n${name} / 1x5 10kg\n}`;
    const messages = decode(convertWorkout(text, 12345).bytes);
    const step = messages.workoutStepMesgs[0];
    const set = messages.setMesgs.find(set => set.setType === 1);
    assert.deepEqual({
      name: step.wktStepName,
      stepCategory: step.exerciseCategory ?? -1,
      stepSubtype: step.exerciseName ?? -1,
      setCategory: set.category[0],
      setSubtype: set.categorySubtype?.[0] ?? -1,
    }, expected, name);
    assert.equal(step.notes, assistedNames.has(name) ? `${name}; Assistance by set: 10 kg` : name);
    assert.equal(set.repetitions, 5);
    assert.equal(set.weight, assistedNames.has(name) ? 0 : 10, name);
  }
});

test('assistance exports zero load with ordered weights and warmups in notes', () => {
  const source = readFileSync(new URL('assistance.txt', fixtures), 'utf8');
  const messages = decode(convertWorkout(source, 12345).bytes);
  const active = messages.setMesgs.filter(set => set.setType === 1);
  assert.deepEqual(active.map(set => set.weight), [0, 0, 0, 0, 0, 0, 50]);
  assert.deepEqual(active.map(set => set.repetitions), [8, 5, 6, 5, 5, 5, 5]);
  assert.equal(messages.workoutStepMesgs[0].notes,
    'Chin Up, Leverage Machine; Assistance by set: 60 kg (warmup), 50 kg, 40 kg');
  assert.equal(messages.workoutStepMesgs[1].notes,
    'Pull Up, Band; Assistance by set: 9.072 kg');
  assert.equal(messages.workoutStepMesgs[4].notes, 'Chest Press, Leverage Machine');
});

test('explicit assisted names are case insensitive; resistance bands keep their load', () => {
  for (const [name, weight] of [['CUSTOM ASSISTED DIP', 0], ['Chin Up, Band', 0],
    ['Push Up, Band', 50], ['Squat, Leverage Machine', 50], ['Chin Up', 50]]) {
    const source = `2026-03-01T10:00:00Z / duration: 60s / exercises: {\n${name} / 1x5 50kg\n}`;
    const messages = decode(convertWorkout(source, 12345).bytes);
    assert.equal(messages.setMesgs.find(set => set.setType === 1).weight, weight, name);
    assert.equal(messages.workoutStepMesgs[0].notes,
      weight === 0 ? `${name}; Assistance by set: 50 kg` : name);
  }
});

test('equipment variants remain distinct and unsupported names never receive guessed subtypes', () => {
  assert.notDeepEqual(exerciseMetadata('Bench Press'), exerciseMetadata('Bench Press, Dumbbell'));
  assert.notDeepEqual(exerciseMetadata('Squat'), exerciseMetadata('Squat, Bodyweight'));
  assert.notDeepEqual(exerciseMetadata('Bicep Curl'), exerciseMetadata('Bicep Curl, Barbell'));
  assert.equal(exerciseMapping('Skullcrusher').subtype, 'lyingEzBarTricepsExtension');
  assert.equal(exerciseMapping('Face Pull').subtype, 'bandedFacePulls');
  assert.equal(exerciseMapping('Snatch').subtype, 'dumbbellSnatch');
  assert.equal(exerciseMapping('Leg Extension, Band').subtype, 'legExtension');
  assert.equal(exerciseMetadata('Leg Extension'), undefined);
  assert.equal(exerciseMetadata('Dead Hang'), undefined);
  assert.equal(exerciseMetadata('Bench Press, Invented Equipment'), undefined);
  assert.equal(exerciseMetadata('Unlisted Custom Exercise'), undefined);
  assert.equal(exerciseMapping('Pull Up, Leverage Machine').quality, 'generic');
  assert.equal(exerciseMapping('Chest Press, Machine').quality, 'category');
});
