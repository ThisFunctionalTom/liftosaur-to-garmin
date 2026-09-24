import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { Decoder, Stream } from '@garmin/fitsdk';
import { convertWorkout } from '../fit.js';

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
