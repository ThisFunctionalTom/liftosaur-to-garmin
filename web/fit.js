import { Encoder, Profile } from '@garmin/fitsdk';
import { prepareWorkout } from './generated/Converter.js';

function enumValue(type, name) {
  const entry = Object.entries(Profile.types[type]).find(([, value]) => value === name);
  if (!entry) throw new Error(`Unknown FIT ${type}: ${name}`);
  return Number(entry[0]);
}

// These mirror garminFit.fsx; cross-runtime fixture tests cover every mapping.
const mappings = [
  [['bench press', 'bench press, barbell'], 'benchPress', 'barbellBenchPress'],
  [['squat', 'squat, barbell'], 'squat', 'barbellBackSquat'],
  [['deadlift', 'deadlift, barbell'], 'deadlift', 'barbellDeadlift'],
  [['overhead press', 'overhead press, barbell'], 'shoulderPress', 'overheadBarbellPress'],
  [['bent over row', 'bent over row, barbell'], 'row', 'bentOverRowWithBarbell'],
  [['push up', 'push-up'], 'pushUp', 'pushUp'],
  // Assisted variants use the base movement: FIT has no machine-assistance subtype.
  // Category-only entries deliberately avoid inventing equipment-specific matches.
  [["lat pulldown","lat pulldown, machine"], 'pullUp', 'latPulldown'],
  [["hanging leg raise"], 'legRaise', 'hangingLegRaise'],
  [["hanging knee raise"], 'legRaise', 'hangingKneeRaise'],
  [["pull up, assisted","pull up, leverage machine"], 'pullUp', 'pullUp'],
  [["chin up, assisted","chin up, leverage machine"], 'pullUp', 'chinUp'],
  [["triceps dip","triceps dip, leverage machine","chest dip, assisted"], 'tricepsExtension', 'bodyWeightDip'],
  [["seated row"], 'row', 'seatedCableRow'],
  [["seated row, machine"], 'row', 'row'],
  [["lunge, dumbbell"], 'lunge', 'dumbbellLunge'],
  [["incline push up"], 'pushUp', 'inclinePushUp'],
  [["bench press, smith machine"], 'benchPress', 'smithMachineBenchPress'],
  [["incline bench press"], 'benchPress', 'inclineBarbellBenchPress'],
  [["incline bench press, dumbbell"], 'benchPress', 'inclineDumbbellBenchPress'],
  [["overhead press, dumbbell"], 'shoulderPress', 'overheadDumbbellPress'],
  [["overhead press, smith machine"], 'shoulderPress', 'smithMachineOverheadPress'],
  [["strict military press"], 'shoulderPress', 'militaryPress'],
  [["stiff leg deadlift"], 'deadlift', 'barbellStraightLegDeadlift'],
  [["zercher squat"], 'squat', 'zercherSquat'],
  [["squat, machine"], 'squat', 'squat'],
  [["leg press"], 'squat', 'legPress'],
  [["lying leg curl, machine"], 'legCurl', 'legCurl'],
  [["seated calf raise, machine"], 'calfRaise', 'seatedCalfRaise'],
  [["crunch, machine","decline crunch"], 'crunch', 'crunch'],
  [["bicep curl"], 'curl', 'dumbbellBicepsCurl'],
  [["lateral raise"], 'lateralRaise', 'dumbbellLateralRaise'],
  [["back extension","back extension, machine"], 'hyperextension'],
  [["bicep curl, machine"], 'curl'],
  [["chest fly"], 'flye'],
  [["chest press, machine","iso-lateral chest press, machine","incline chest press"], 'benchPress'],
  [["shoulder press, machine"], 'shoulderPress'],
  [["lateral raise, machine"], 'lateralRaise'],
  [["hip thrust"], 'hipRaise'],
  [["hip abductor, machine","hip adductor, machine","glute kickback, machine"], 'hipStability'],
  [["skullcrusher"], 'tricepsExtension'],
  [["triceps pushdown, cable, straight bar"], 'tricepsExtension', 'tricepsPressdown'],
];

function exerciseMetadata(name) {
  const mapping = mappings.find(([names]) => names.includes(name.trim().toLowerCase()));
  if (!mapping) return undefined;
  const [, category, subtype] = mapping;
  return {
    category: enumValue('exerciseCategory', category),
    subtype: subtype === undefined ? undefined : enumValue(`${category}ExerciseName`, subtype),
  };
}

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
      messageIndex, wktStepName: exercise, notes: exercise,
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
        category: [metadata?.category ?? enumValue('exerciseCategory', 'unknown')],
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
