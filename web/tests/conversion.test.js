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

test('empty and unrelated input are rejected', () => {
  for (const text of ['', '{}', 'not a workout']) {
    assert.throws(() => convertWorkout(text, 12345));
  }
});
