import { Encoder, Profile } from '@garmin/fitsdk';
import { prepareWorkout } from './generated/Converter.js';
import { exerciseMetadata, unknownExerciseCategory } from './exercise-mappings.js';

export function convertWorkout(text, serial = crypto.getRandomValues(new Uint32Array(1))[0] || 1) {
  const workout = prepareWorkout(text);
  const encoder = new Encoder();
  const write = (type, message) => encoder.onMesg(Profile.MesgNum[type], message);
  const sport = { sport: 'training', subSport: 'strengthTraining' };
  write('FILE_ID', {
    type: 'activity', manufacturer: 'development', product: 1,
    serialNumber: serial, timeCreated: workout.startTime,
  });
  write('DEVICE_INFO', {
    deviceIndex: 'creator', manufacturer: 'development', product: 1,
    productName: 'Liftosaur Import', serialNumber: serial,
    softwareVersion: 1, timestamp: workout.startTime,
  });
  write('WORKOUT', {
    wktName: workout.name, wktDescription: workout.description,
    ...sport, numValidSteps: workout.exercises.length,
  });
  workout.exercises.forEach((exercise, messageIndex) => {
    const metadata = exerciseMetadata(exercise);
    write('WORKOUT_STEP', {
      messageIndex, wktStepName: exercise, notes: workout.exerciseNotes[messageIndex],
      durationType: 'open', targetType: 'open',
      ...(metadata ? { exerciseCategory: metadata.category } : {}),
      ...(metadata?.subtype !== undefined ? { exerciseName: metadata.subtype } : {}),
    });
  });
  write('EVENT', { timestamp: workout.startTime, event: 'timer', eventType: 'start' });
  workout.sets.forEach((set, messageIndex) => {
    const metadata = exerciseMetadata(set.exercise);
    write('SET', {
      messageIndex, startTime: set.startTime, timestamp: set.timestamp,
      duration: set.duration, setType: set.active ? 'active' : 'rest',
      ...(set.active ? {
        repetitions: set.repetitions, weight: set.weight,
        category: [metadata?.category ?? unknownExerciseCategory],
        ...(metadata?.subtype !== undefined ? { categorySubtype: [metadata.subtype] } : {}),
      } : {}),
    });
  });
  write('EVENT', { timestamp: workout.timestamp, event: 'timer', eventType: 'stopAll' });
  const summary = {
    messageIndex: 0, timestamp: workout.timestamp, startTime: workout.startTime,
    totalElapsedTime: workout.duration, totalTimerTime: workout.duration, ...sport,
  };
  write('LAP', summary);
  write('SESSION', {
    ...summary, sportProfileName: workout.name, firstLapIndex: 0, numLaps: 1,
  });
  write('ACTIVITY', {
    timestamp: workout.timestamp, numSessions: 1, totalTimerTime: workout.duration,
  });
  return { bytes: encoder.close(), name: workout.name, sets: workout.sets.filter(s => s.active).length };
}
