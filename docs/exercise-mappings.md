# Garmin exercise mappings

Mappings live in `web/fit.js` (PWA) and `garminFit.fsx` (CLI). Keep both in sync.
Names are matched exactly after trimming and lowercasing; equipment suffixes matter.

The September 2026 mapping audit used Liftosaur MCP workout history and custom
exercise definitions: 68 workouts, 53 distinct names, 45 previously unmapped names.
The fixture uses those names with synthetic dates, weights, and repetitions.

The additions and completed subtype mappings are listed below. Base movement
matches intentionally lose some detail: assisted pull-ups/chin-ups and dips use
the unassisted movement code (not a band-assisted code); machine rows/squats,
machine crunches, and decline crunches use a generic movement subtype.
The original name remains in the FIT workout step name and notes.

| Liftosaur names | Garmin category | Garmin subtype |
| --- | --- | --- |
| lat pulldown; lat pulldown, machine | Pull Up | Lat Pulldown |
| hanging leg raise | Leg Raise | Hanging Leg Raise |
| hanging knee raise | Leg Raise | Hanging Knee Raise |
| pull up, assisted; pull up, leverage machine | Pull Up | Pull Up |
| chin up, assisted; chin up, leverage machine | Pull Up | Chin Up |
| triceps dip; triceps dip, leverage machine; chest dip, assisted | Triceps Extension | Body Weight Dip |
| seated row | Row | Seated Cable Row |
| seated row, machine | Row | Row |
| lunge, dumbbell | Lunge | Dumbbell Lunge |
| incline push up | Push Up | Incline Push Up |
| bench press, smith machine | Bench Press | Smith Machine Bench Press |
| incline bench press | Bench Press | Incline Barbell Bench Press |
| incline bench press, dumbbell | Bench Press | Incline Dumbbell Bench Press |
| overhead press, dumbbell | Shoulder Press | Overhead Dumbbell Press |
| overhead press, smith machine | Shoulder Press | Smith Machine Overhead Press |
| strict military press | Shoulder Press | Military Press |
| stiff leg deadlift | Deadlift | Barbell Straight Leg Deadlift |
| zercher squat | Squat | Zercher Squat |
| squat, machine | Squat | Squat |
| leg press | Squat | Leg Press |
| lying leg curl, machine | Leg Curl | Leg Curl |
| seated calf raise, machine | Calf Raise | Seated Calf Raise |
| crunch, machine; decline crunch | Crunch | Crunch |
| bicep curl | Curl | Dumbbell Biceps Curl |
| lateral raise | Lateral Raise | Dumbbell Lateral Raise |
| back extension; back extension, machine | Hyperextension | Category only |
| bicep curl, machine | Curl | Category only |
| chest fly | Flye | Category only |
| chest press, machine; iso-lateral chest press, machine; incline chest press | Bench Press | Category only |
| shoulder press, machine | Shoulder Press | Category only |
| lateral raise, machine | Lateral Raise | Category only |
| hip thrust | Hip Raise | Category only |
| hip abductor, machine; hip adductor, machine; glute kickback, machine | Hip Stability | Category only |
| skullcrusher | Triceps Extension | Category only |
| triceps pushdown, cable, straight bar | Triceps Extension | Triceps Pressdown |

Category-only entries can still appear as Unknown in Garmin Connect. The installed
FIT SDK has no matching machine variant, or the source name lacks enough detail
to choose a specific subtype safely. These are not claimed as exact matches.

**Leg Extension, Machine** remains unmapped: the installed SDK has no seated knee
extension machine exercise. Its `crunch / legExtensions` and banded leg-extension
entries describe different movements/equipment and are not substituted.

Run `npm test --prefix web` to compare both encoders' FIT output and check the
numeric exercise metadata. Reconvert workouts to include changed mappings;
activities already imported into Garmin are not updated automatically.
