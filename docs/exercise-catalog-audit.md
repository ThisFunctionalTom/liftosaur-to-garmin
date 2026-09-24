# Liftosaur exercise mapping coverage

Catalog snapshot: 2026-09-24, from Liftosaur MCP `list_exercises`.
Garmin FIT profile: 21.214.0. Equipment variants count separately.
This report is generated from [the shared mappings](../shared/exercise-mappings.json)
and [the catalog snapshot](../tests/liftosaur-exercises.json).

| Decision | Built-in names |
| --- | ---: |
| exact | 173 |
| generic | 76 |
| category | 107 |
| unsupported | 8 |
| Total | 364 |

Every built-in name has an explicit decision. Exact and generic entries include
a Garmin category and subtype. Generic entries lose the detail stated below.
Category-only and unsupported entries may still display as Unknown in Garmin.
Unknown custom names also remain unknown; no fuzzy matching is used.

Defaults were checked against [Liftosaur exercise definitions](https://github.com/astashov/liftosaur/blob/master/src/models/exercise.ts).
SDK symbol validity and numeric agreement are checked against both installed Garmin SDKs.
This validates FIT metadata, not Garmin Connect display behavior for every exercise.

## exact

| Liftosaur name | Garmin category | Garmin subtype | Limitation |
| --- | --- | --- | --- |
| Arnold Press | shoulderPress | arnoldPress |  |
| Ball Slams | plyo | medicineBallSlam |  |
| Bench Dip | tricepsExtension | benchDip |  |
| Bench Press | benchPress | barbellBenchPress |  |
| Bench Press, Dumbbell | benchPress | dumbbellBenchPress |  |
| Bench Press, Smith Machine | benchPress | smithMachineBenchPress |  |
| Bench Press, Band | bandedExercises | chestPress |  |
| Bench Press, Kettlebell | benchPress | kettlebellChestPress |  |
| Bench Press Close Grip | benchPress | closeGripBarbellBenchPress |  |
| Bench Press Wide Grip | benchPress | wideGripBarbellBenchPress |  |
| Bent Over One Arm Row | row | oneArmBentOverRow |  |
| Bent Over Row | row | bentOverRowWithBarbell |  |
| Bent Over Row, Dumbbell | row | bentOverRowWithDumbell |  |
| Bicep Curl, Barbell | curl | barbellBicepsCurl |  |
| Bicep Curl, Cable | curl | cableBicepsCurl |  |
| Bicep Curl | curl | dumbbellBicepsCurl |  |
| Bicep Curl, Band | bandedExercises | curl |  |
| Bicep Curl, EZ Bar | curl | standingEzBarBicepsCurl |  |
| Bicycle Crunch | crunch | bicycleCrunch |  |
| Box Squat | squat | barbellBoxSquat |  |
| Bulgarian Split Squat | lunge | dumbbellBulgarianSplitSquat |  |
| Cable Crossover | flye | cableCrossover |  |
| Cable Crunch | crunch | cableCrunch |  |
| Cable Kickback | tricepsExtension | cableKickback |  |
| Cable Pull Through | chop | cablePullThrough |  |
| Cable Twist, Band | bandedExercises | abTwist |  |
| Chest Fly | flye | dumbbellFlye |  |
| Chest Press, Band | bandedExercises | chestPress |  |
| Chin Up | pullUp | chinUp |  |
| Clean | olympicLift | clean |  |
| Clean and Jerk | olympicLift | cleanAndJerk |  |
| Concentration Curl | curl | oneArmConcentrationCurl |  |
| Cross Body Crunch | crunch | elbowToKneeCrunch |  |
| Crunch, Cable | crunch | cableCrunch |  |
| Crunch | crunch | crunch |  |
| Deadlift | deadlift | barbellDeadlift |  |
| Deadlift, Dumbbell | deadlift | dumbbellDeadlift |  |
| Deadlift, Band | bandedExercises | deadlift |  |
| Deadlift, Kettlebell | deadlift | kettlebellDeadlift |  |
| Deadlift High Pull | olympicLift | barbellHighPull |  |
| Decline Bench Press, Dumbbell | benchPress | declineDumbbellBenchPress |  |
| Diamond Push Up | pushUp | diamondPushUp |  |
| Elliptical Machine | elliptical | elliptical |  |
| Face Pull | row | bandedFacePulls |  |
| Flat Leg Raise | legRaise | lyingStraightLegRaise |  |
| Front Raise, Cable | lateralRaise | cableFrontRaise |  |
| Front Raise | shoulderPress | dumbbellFrontRaise |  |
| Front Raise, Band | bandedExercises | frontRaise |  |
| Front Squat | squat | barbellFrontSquat |  |
| Front Squat, Dumbbell | squat | dumbbellFrontSquat |  |
| Goblet Squat | squat | gobletSquat |  |
| Goblet Squat, Kettlebell | squat | gobletSquat |  |
| Good Morning | legCurl | goodMorning |  |
| Glute Bridge, Barbell | hipRaise | barbellHipThrustOnFloor |  |
| Glute Bridge, Band | bandedExercises | gluteBridge |  |
| Glute Bridge March | hipRaise | marchingHipRaise |  |
| Glute Kickback, Band | bandedExercises | donkeyKick |  |
| Hack Squat | squat | barbellHackSquat |  |
| Hammer Curl, Cable | curl | cableHammerCurl |  |
| Hammer Curl | curl | dumbbellHammerCurl |  |
| Handstand Push Up | pushUp | handstandPushUp |  |
| Hanging Knee Raise | legRaise | hangingKneeRaise |  |
| Hanging Leg Raise | legRaise | hangingLegRaise |  |
| Hip Abductor, Cable | hipStability | standingCableHipAbduction |  |
| Hip Abductor, Band | bandedExercises | legAbduction |  |
| Hip Thrust | hipRaise | barbellHipThrustWithBench |  |
| Incline Bench Press | benchPress | inclineBarbellBenchPress |  |
| Incline Bench Press, Dumbbell | benchPress | inclineDumbbellBenchPress |  |
| Incline Bench Press, Smith Machine | benchPress | inclineSmithMachineBenchPress |  |
| Incline Chest Fly | flye | inclineDumbbellFlye |  |
| Incline Chest Press | benchPress | inclineDumbbellBenchPress |  |
| Incline Curl | curl | inclineDumbbellBicepsCurl |  |
| Incline Push Up | pushUp | inclinePushUp |  |
| Incline Row | row | chestSupportedDumbbellRow |  |
| Inverted Row | row | invertedRow |  |
| Jump Squat, Bodyweight | plyo | jumpSquat |  |
| Kettlebell Swing | hipRaise | kettlebellSwing |  |
| Knee Push Up | pushUp | kneelingPushUp |  |
| Knees to Elbows | crunch | kneesToElbow |  |
| Lat Pulldown | pullUp | latPulldown |  |
| Lateral Raise | lateralRaise | dumbbellLateralRaise |  |
| Lateral Raise, Band | bandedExercises | lateralRaise |  |
| Leg Extension, Band | bandedExercises | legExtension |  |
| Leg Press | squat | legPress |  |
| Lunge | lunge | barbellLunge |  |
| Lunge, Dumbbell | lunge | dumbbellLunge |  |
| Lunge, Bodyweight | lunge | lunge |  |
| Lying Leg Curl, Band | bandedExercises | hamstringCurls |  |
| Muscle Up | lateralRaise | muscleUp |  |
| Overhead Press | shoulderPress | overheadBarbellPress |  |
| Overhead Press, Dumbbell | shoulderPress | overheadDumbbellPress |  |
| Overhead Squat | squat | overheadBarbellSquat |  |
| Overhead Squat, Dumbbell | squat | overheadDumbbellSquat |  |
| Pike Push Up | pushUp | pikePushUp |  |
| Pistol Squat | squat | pistolSquat |  |
| Plank | plank | plank |  |
| Preacher Curl | curl | oneArmPreacherCurl |  |
| Preacher Curl, EZ Bar | curl | ezBarPreacherCurl |  |
| Pull Up, Band | pullUp | bandAssistedPullUp |  |
| Pull Up | pullUp | pullUp |  |
| Push Press, Barbell | shoulderPress | barbellPushPress |  |
| Push Press, Dumbbell | shoulderPress | dumbbellPushPress |  |
| Push Up, Band | bandedExercises | pushUps |  |
| Push Up | pushUp | pushUp |  |
| Reverse Crunch | crunch | reverseCrunch |  |
| Reverse Curl, Barbell | curl | reverseGripBarbellBicepsCurl |  |
| Renegade Row | row | renegadeRow |  |
| Reverse Lunge, Barbell | lunge | barbellReverseLunge |  |
| Reverse Lunge | lunge | dumbbellReverseLunge |  |
| Reverse Wrist Curl | curl | barbellReverseWristCurl |  |
| Reverse Wrist Curl, Dumbbell | curl | dumbbellReverseWristCurl |  |
| Ring Dip | lateralRaise | ringDip |  |
| Ring Row | row | ringRow |  |
| Romanian Deadlift, Barbell | deadlift | romanianDeadlift |  |
| Russian Twist | core | russianTwist |  |
| Seated Overhead Press | shoulderPress | seatedBarbellShoulderPress |  |
| Seated Palms Up Wrist Curl | curl | dumbbellWristCurl |  |
| Seated Row | row | seatedCableRow |  |
| Seated Wide Grip Row | row | wideGripSeatedCableRow |  |
| Shoulder Press | shoulderPress | dumbbellShoulderPress |  |
| Shoulder Press, Smith Machine | shoulderPress | smithMachineOverheadPress |  |
| Shrug, Barbell | shrug | barbellShrug |  |
| Shrug | shrug | dumbbellShrug |  |
| Side Bend, Cable | core | cableSideBend |  |
| Side Hip Abductor | hipStability | sideLyingLegRaise |  |
| Side Lying Clam | hipRaise | clams |  |
| Side Plank | plank | sidePlank |  |
| Single Leg Bridge | hipRaise | singleLegHipRaise |  |
| Sit Up, Kettlebell | sitUp | kettlebellSitUp |  |
| Sit Up | sitUp | sitUp |  |
| Skullcrusher, Cable | tricepsExtension | cableLyingTricepsExtension |  |
| Skullcrusher, Dumbbell | tricepsExtension | dumbbellLyingTricepsExtension |  |
| Skullcrusher | tricepsExtension | lyingEzBarTricepsExtension |  |
| Snatch | olympicLift | dumbbellSnatch |  |
| Split Squat, Barbell | lunge | barbellSplitSquat |  |
| Split Squat | squat | dumbbellSplitSquat |  |
| Squat | squat | barbellBackSquat |  |
| Squat, Dumbbell | squat | dumbbellSquat |  |
| Squat, Bodyweight | squat | airSquat |  |
| Standing Calf Raise, Barbell | calfRaise | standingBarbellCalfRaise |  |
| Standing Calf Raise | calfRaise | standingDumbbellCalfRaise |  |
| Standing Calf Raise, Bodyweight | calfRaise | standingCalfRaise |  |
| Standing Row | row | cableRowStanding |  |
| Standing Row Rear Delt With Rope | row | facePull |  |
| Step up, Barbell | squat | barbellStepUp |  |
| Step up | squat | dumbbellStepUp |  |
| Step up, Bodyweight | squat | stepUp |  |
| Stiff Leg Deadlift | deadlift | barbellStraightLegDeadlift |  |
| Stiff Leg Deadlift, Dumbbell | deadlift | dumbbellStraightLegDeadlift |  |
| Straight Leg Deadlift | deadlift | barbellStraightLegDeadlift |  |
| Straight Leg Deadlift, Dumbbell | deadlift | dumbbellStraightLegDeadlift |  |
| Sumo Deadlift | deadlift | sumoDeadlift |  |
| Sumo Deadlift High Pull | deadlift | sumoDeadliftHighPull |  |
| Superman, Dumbbell | hyperextension | weightedSupermanFromFloor |  |
| Superman | hyperextension | supermanFromFloor |  |
| T Bar Row | row | tBarRow |  |
| Thruster | squat | thrusters |  |
| Toes To Bar | crunch | toesToBar |  |
| Trap Bar Deadlift | deadlift | trapBarDeadlift |  |
| Triceps Dip | tricepsExtension | bodyWeightDip |  |
| Triceps Extension, Cable | tricepsExtension | cableOverheadTricepsExtension |  |
| Triceps Extension | tricepsExtension | overheadDumbbellTricepsExtension |  |
| Triceps Extension, Band | bandedExercises | tricepExtension |  |
| Triceps Pushdown | tricepsExtension | tricepsPressdown |  |
| Upright Row, Barbell | shrug | barbellUprightRow |  |
| Upright Row | shrug | dumbbellUprightRow |  |
| Upright Row, Band | bandedExercises | uprightRow |  |
| V Up | sitUp | vUp |  |
| Wall Push Up | pushUp | wallPushUp |  |
| Wide Pull Up | pullUp | wideGripPullUp |  |
| Wrist Curl | curl | barbellWristCurl |  |
| Wrist Curl, Dumbbell | curl | dumbbellWristCurl |  |
| Zercher Squat | squat | zercherSquat |  |

## generic

| Liftosaur name | Garmin category | Garmin subtype | Limitation |
| --- | --- | --- | --- |
| Ab Wheel | core | kneelingAbWheel | Uses kneeling ab-wheel subtype; standing versus kneeling is unspecified. |
| Assisted Squat | squat | squat | Exports 0 kg with assistance in step notes. |
| Back Extension, Bodyweight | hyperextension | spineExtension | Uses generic spine extension; bench angle is not represented. |
| Bent Over Row, Band | bandedExercises | row | Banded row code does not distinguish torso position. |
| Chest Dip | tricepsExtension | bodyWeightDip | FIT dip subtype does not distinguish chest emphasis. |
| Chest Fly, Cable | flye | cableCrossover | FIT cable fly is named Cable Crossover. |
| Chin Up, Leverage Machine | pullUp | chinUp | FIT has no machine-assisted subtype; exports 0 kg with assistance in step notes. |
| Concentration Curl, Band | bandedExercises | curl | Concentration posture is not represented. |
| Crunch, Leverage Machine | crunch | crunch | Generic crunch code does not describe the machine. |
| Deficit Deadlift | deadlift | barbellDeadlift | Deficit height is not represented. |
| Deficit Deadlift, Trap Bar | deadlift | trapBarDeadlift | Deficit height is not represented. |
| Flat Knee Raise | core | openKneeTucks | Uses the generic knee-tuck movement. |
| Front Raise, Barbell | lateralRaise | frontRaise | Generic front raise does not encode barbell equipment. |
| Front Raise, Bodyweight | lateralRaise | frontRaise | Generic front raise does not encode equipment. |
| Glute Bridge | hipRaise | weightedHipRaise | Generic weighted hip raise; dumbbell equipment is not encoded. |
| Glute Kickback | hipStability | weightedStandingRearLegRaise | Uses weighted rear-leg raise; cable and support position are not represented. |
| Hammer Curl, Band | bandedExercises | curl | Hammer grip is not represented. |
| Hanging Leg Raise, Cable | legRaise | weightedHangingLegRaise | Generic weighted hanging raise does not specify cable. |
| Hip Abductor, Bodyweight | hipStability | standingHipAbduction | Standing variant is used; body position is not specified. |
| Hip Thrust, Band | bandedExercises | gluteBridge | Banded glute bridge is the closest movement; bench support is not represented. |
| Hip Thrust, Bodyweight | hipRaise | hipRaise | Generic hip raise does not specify bench support. |
| Hip Thrust, Leverage Machine | hipRaise | weightedHipRaise | Bench support and machine equipment are not represented. |
| Incline Chest Press, Band | bandedExercises | chestPress | Incline angle is not represented. |
| Jackknife Sit Up | sitUp | vUp | Uses the V-up movement; exact jackknife variant is unspecified. |
| Jump Squat | plyo | jumpSquat | Barbell loading is not represented by the generic jump squat code. |
| Lat Pulldown, Leverage Machine | pullUp | latPulldown | Generic lat pulldown does not describe the lever machine. |
| Lateral Raise, Cable | lateralRaise | oneArmCableLateralRaise | Uses the one-arm cable variant. |
| Lunge, Cable | lunge | weightedLunge | Generic weighted lunge does not specify cable. |
| Lying Leg Curl | legCurl | legCurl | Generic leg curl does not specify lying position. |
| Negative Dip | tricepsExtension | bodyWeightDip | Eccentric-only execution is not represented. |
| Negative Pull Up | pullUp | pullUp | Eccentric-only execution is not represented. |
| Nordic Curl | legCurl | legCurl | Generic leg curl does not specify bodyweight Nordic technique. |
| Pendlay Row | row | barbellRow | Dead-stop Pendlay technique is not represented. |
| Pistol Squat, Kettlebell | squat | weightedPistolSquat | Generic weighted pistol squat does not specify kettlebell. |
| Pistol Squat, Leverage Machine | squat | pistolSquat | Exports 0 kg with machine assistance in step notes. |
| Pull Up, Leverage Machine | pullUp | pullUp | FIT has no machine-assisted subtype; exports 0 kg with assistance in step notes. |
| Reverse Curl, Band | bandedExercises | curl | Reverse grip is not represented. |
| Reverse Lunge, Kettlebell | lunge | weightedLunge | Backward direction and kettlebell equipment are not represented. |
| Reverse Lunge, Bodyweight | lunge | lunge | Generic lunge does not specify backward direction. |
| Romanian Deadlift | deadlift | romanianDeadlift | Generic Romanian deadlift code does not specify dumbbells. |
| Romanian Deadlift, Bodyweight | deadlift | romanianDeadlift | No-load variant is not represented in the exercise code. |
| Russian Twist, Dumbbell | core | russianTwist | Added dumbbell load is not represented in the exercise subtype. |
| Seated Calf Raise | calfRaise | seatedCalfRaise | Generic seated calf raise does not specify barbell. |
| Seated Calf Raise, Dumbbell | calfRaise | seatedCalfRaise | Generic seated calf raise does not specify dumbbells. |
| Seated Calf Raise, Leverage Machine | calfRaise | seatedCalfRaise | Generic seated calf raise does not specify machine. |
| Seated Front Raise, Barbell | lateralRaise | frontRaise | Seated posture and barbell equipment are not represented. |
| Seated Front Raise | shoulderPress | dumbbellFrontRaise | Seated posture is not represented. |
| Seated Leg Curl | legCurl | legCurl | Generic leg curl does not specify seated position. |
| Seated Leg Press | squat | legPress | Generic leg press does not specify machine angle. |
| Seated Row, Band | bandedExercises | row | Banded row code does not specify seated position. |
| Seated Row, Leverage Machine | row | row | Generic row does not describe the machine. |
| Side Bend | core | weightedSideBend | Generic weighted side bend does not specify dumbbells. |
| Side Hip Abductor, Barbell | hipStability | weightedSideLyingLegRaise | Barbell equipment is not represented. |
| Single Leg Deadlift | deadlift | singleLegRomanianDeadliftWithDumbbell | Uses single-leg dumbbell Romanian deadlift; exact knee bend is not represented. |
| Single Leg Glute Bridge On Bench | hipRaise | singleLegHipRaise | Bench support position is not represented. |
| Single Leg Glute Bridge Straight Leg | hipRaise | singleLegHipRaise | Free-leg position is not represented. |
| Single Leg Glute Bridge Bent Knee | hipRaise | singleLegHipRaise | Free-leg position is not represented. |
| Single Leg Hip Thrust, Barbell | hipRaise | weightedSingleLegHipRaise | Bench support and barbell equipment are not represented. |
| Single Leg Hip Thrust | hipRaise | singleLegHipRaise | Generic single-leg hip raise does not specify bench support. |
| Single Leg Hip Thrust, Leverage Machine | hipRaise | weightedSingleLegHipRaise | Bench support and machine equipment are not represented. |
| Split Squat, Band | bandedExercises | lunge | Stationary split stance is not represented. |
| Split Squat, Kettlebell | lunge | weightedLunge | Stationary split stance and kettlebell equipment are not represented. |
| Split Squat, Bodyweight | lunge | lunge | Generic lunge does not specify a stationary split stance. |
| Squat, Leverage Machine | squat | squat | Machine equipment is not represented. |
| Standing Calf Raise, Cable | calfRaise | weightedStandingCalfRaise | Generic weighted calf raise does not specify cable. |
| Standing Calf Raise, Leverage Machine | calfRaise | weightedStandingCalfRaise | Generic weighted calf raise does not specify machine. |
| Standing Row Close Grip | row | cableRowStanding | Close grip is not represented. |
| Standing Row V-Bar | row | vGripCableRow | Standing posture is not represented. |
| Stiff Leg Deadlift, Band | bandedExercises | deadlift | Knee angle is not represented. |
| Straight Leg Deadlift, Band | bandedExercises | deadlift | Knee angle is not represented. |
| Straight Leg Deadlift, Kettlebell | deadlift | straightLegDeadlift | Generic straight-leg deadlift does not specify kettlebell. |
| Triceps Dip, Leverage Machine | tricepsExtension | bodyWeightDip | FIT has no machine-assisted subtype; exports 0 kg with assistance in step notes. |
| Upright Row, Cable | shrug | uprightRow | Cable equipment is not represented. |
| V Up, Dumbbell | sitUp | weightedVUp | Generic weighted V-up does not specify dumbbells. |
| Vertical Row | row | invertedRow | Bodyweight row inclination is not represented. |
| Wide Row | row | invertedRow | Wide grip is not represented. |

## category

| Liftosaur name | Garmin category | Garmin subtype | Limitation |
| --- | --- | --- | --- |
| Arnold Press, Kettlebell | shoulderPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Around The World | core | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Back Extension | hyperextension | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Battle Ropes | battleRope | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Behind The Neck Press | shoulderPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Behind The Neck Press, Smith Machine | shoulderPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Behind The Neck Press, Band | shoulderPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Bench Press, Cable | benchPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Bench Press Close Grip, Smith Machine | benchPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Bench Press Close Grip, EZ Bar | benchPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Bench Press Wide Grip, Smith Machine | benchPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Bent Over Row, Cable | row | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Bent Over Row, Smith Machine | row | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Bent Over Row, Leverage Machine | row | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Bicep Curl, Leverage Machine | curl | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Box Squat, Dumbbell | squat | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Bulgarian Split Squat, Bodyweight | lunge | — | FIT has no bodyweight rear-foot-elevated split squat; do not invent overhead loading. |
| Cable Twist, Barbell | core | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Cable Twist | core | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Cable Twist, Bodyweight | core | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Cable Twist, Leverage Machine | core | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Calf Press on Leg Press | calfRaise | — | Standing calf raise is not the leg-press calf movement. |
| Calf Press on Seated Leg Press | calfRaise | — | Seated calf raise has different knee positioning from a leg press. |
| Chest Fly, Barbell | flye | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Chest Fly, Leverage Machine | flye | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Chest Press, Leverage Machine | benchPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Concentration Curl, Barbell | curl | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Concentration Curl, Cable | curl | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Copenhagen Plank | plank | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Deadlift, Cable | deadlift | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Deadlift, Smith Machine | deadlift | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Deadlift, Leverage Machine | deadlift | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Decline Bench Press, Smith Machine | benchPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Dragon Flag | core | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Front Lever Row | row | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Front Squat, Cable | squat | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Front Squat, Smith Machine | squat | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Front Squat, Kettlebell | squat | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Good Morning, Smith Machine | legCurl | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Good Morning, Leverage Machine | legCurl | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Hack Squat, Smith Machine | squat | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Hang Clean, Kettlebell | olympicLift | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| High Row, Cable | row | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| High Row | row | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Hip Abductor | hipStability | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Hip Adductor | hipStability | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Incline Bench Press, Cable | benchPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Incline Bench Press Wide Grip | benchPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Incline Chest Fly, Cable | flye | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Incline Chest Press, Leverage Machine | benchPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Incline Row, Barbell | row | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Kettlebell Swing, Dumbbell | hipSwing | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Kneeling Pulldown | pullUp | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Lateral Raise, Kettlebell | lateralRaise | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Lateral Raise, Leverage Machine | lateralRaise | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Legs Up Bench Press | benchPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Leg Press, Smith Machine | squat | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Lying Bicep Curl, Cable | curl | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Lying Bicep Curl | curl | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Oblique Crunch | crunch | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Overhead Press, EZ Bar | shoulderPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Pallof Press | core | — | FIT has no banded anti-rotation press subtype. |
| Pec Deck | flye | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Preacher Curl, Barbell | curl | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Preacher Curl, Leverage Machine | curl | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Pseudo Planche Push Up | pushUp | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Pullover, Barbell | pullUp | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Pullover | pullUp | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Push Press | shoulderPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Push Press, Bodyweight | shoulderPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Reverse Crunch, Cable | crunch | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Reverse Curl, Cable | curl | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Reverse Curl | curl | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Reverse Fly | flye | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Reverse Fly, Band | flye | — | FIT banded fly does not distinguish chest fly from rear-delt fly. |
| Reverse Fly, Leverage Machine | flye | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Reverse Wrist Curl, EZ Bar | curl | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Reverse Hyperextension | hyperextension | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Reverse Hyperextension, Leverage Machine | hyperextension | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Russian Twist, Cable | core | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Safety Squat Bar Squat | squat | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Scapular Pull Up | pullUp | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Shoulder Press, Cable | shoulderPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Shoulder Press, Band | bandedExercises | — | No standing banded overhead press code; wheelchair variant is not equivalent. |
| Shoulder Press, Leverage Machine | shoulderPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Shoulder Press Parallel Grip | shoulderPress | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Shrimp Squat | squat | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Shrug, Cable | shrug | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Shrug, Smith Machine | shrug | — | FIT Smith shrug specifies behind-the-back; normal shrug position differs. |
| Shrug, Band | shrug | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Shrug, Leverage Machine | shrug | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Side Bend, Band | core | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Side Crunch, Cable | crunch | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Side Crunch, Band | crunch | — | FIT has no banded lateral crunch subtype. |
| Side Crunch | crunch | — | Standing position cannot be inferred from the source name. |
| Side Hip Abductor, Leverage Machine | hipStability | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Single Leg Deadlift, Bodyweight | deadlift | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Sissy Squat | squat | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Skullcrusher, Barbell | tricepsExtension | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Squat, Smith Machine | squat | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Standing Row Rear Delt, Horizontal, With Rope | row | — | Horizontal rear-delt row is not necessarily a face pull. |
| Step up, Band | squat | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Triceps Extension, Barbell | tricepsExtension | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Tuck Front Lever Row | row | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| V Up, Band | sitUp | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Wrist Curl, EZ Bar | curl | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |
| Wrist Roller | curl | — | No equivalent subtype for this movement/equipment in FIT profile 21.214.0. |

## unsupported

| Liftosaur name | Garmin category | Garmin subtype | Limitation |
| --- | --- | --- | --- |
| Arch Hang | — | — | No FIT hanging arch-hold exercise. |
| Crow Pose | — | — | No FIT crow-pose exercise. |
| Dead Hang | — | — | No FIT dead-hang exercise; hanging hurdle and pull-up codes describe different movements. |
| Handstand | — | — | No FIT static handstand exercise; handstand push-ups require repetitions of a different movement. |
| Leg Extension | — | — | No FIT machine knee-extension exercise; crunch leg extensions and banded extensions are not equivalent. |
| Squat Row | — | — | No FIT combined banded squat-and-row exercise. |
| Support Hold | — | — | No FIT static support-hold exercise; dips describe a different movement. |
| Wall Handstand | — | — | No FIT static wall handstand exercise; wall walks and handstand push-ups are different movements. |

## Additional aliases and imported names

The catalog also retains 29 names outside the built-in snapshot:

- Back Extension, Machine
- Bench Press, Barbell
- Bent Over Row, Barbell
- Bicep Curl, Machine
- Chest Dip, Assisted
- Chest Press, Machine
- Chin Up, Assisted
- Crunch, Machine
- Deadlift, Barbell
- Decline Crunch
- Glute Kickback, Machine
- Hip Abductor, Machine
- Hip Adductor, Machine
- Iso-lateral Chest Press, Machine
- Lat Pulldown, Machine
- Lateral Raise, Machine
- Leg Extension, Machine
- Lying Leg Curl, Machine
- Overhead Press, Barbell
- Overhead Press, Smith Machine
- Pull Up, Assisted
- Push-up
- Seated Calf Raise, Machine
- Seated Row, Machine
- Shoulder Press, Machine
- Squat, Barbell
- Squat, Machine
- Strict Military Press
- Triceps Pushdown, Cable, Straight Bar

Regenerate with `npm run audit:mappings --prefix web` after editing the shared mappings.
