using Toybox.Application.Storage;
using Toybox.System;
using Toybox.Test;

(:test)
class LiftosaurSetTestStore extends LiftosaurStore {
    // Exercise pure compaction/support checks without initializing API/settings.
    function initialize() { }
}

(:test)
class LiftosaurSetTests {
    static function legacySet(done) {
        var set = {
            "setId" => "set1", "reps" => 5, "weight" => "52.5kg",
            "isWarmup" => false, "isAmrap" => true, "timer" => 180,
            "askWeight" => false, "logRpe" => false,
            "isUnilateral" => false, "hasSetTimer" => false
        };
        if (done) { set["completed"] = { "reps" => 8, "weight" => "52.5kg" }; }
        return set;
    }

    static function allocationFor35Sets(packed, done) {
        var before = System.getSystemStats().usedMemory;
        var sets = [];
        for (var i = 0; i < 35; i += 1) {
            var set = legacySet(done);
            set["setId"] = i.toString();
            sets.add(packed ? LiftosaurSet.pack(set, false) : set);
            set = null;
        }
        return System.getSystemStats().usedMemory - before;
    }

    (:test)
    static function arraysReducePlannedAndCompletedMemory(logger) {
        var oldPlanned = allocationFor35Sets(false, false);
        var newPlanned = allocationFor35Sets(true, false);
        var oldDone = allocationFor35Sets(false, true);
        var newDone = allocationFor35Sets(true, true);
        logger.debug("35 planned sets: dictionaries=" + oldPlanned + " arrays=" + newPlanned);
        logger.debug("35 completed sets: dictionaries=" + oldDone + " arrays=" + newDone);
        Test.assert(newPlanned < oldPlanned / 2);
        Test.assert(newDone < oldDone / 2);
        return true;
    }

    (:test)
    static function completionsRemainImmutableAndApiUsesObjects(logger) {
        var original = LiftosaurSet.pack(legacySet(false), false);
        var logged = LiftosaurSet.withCompleted(original, [0, "52.5kg"]);
        Test.assert(LiftosaurSet.get(original, "completed") == null);
        Test.assertEqual(5, LiftosaurSet.get(logged, "reps"));
        Test.assertEqual(true, LiftosaurSet.get(logged, "isAmrap"));
        var payload = LiftosaurSet.apiCompleted(LiftosaurSet.get(logged, "completed"));
        Test.assertEqual(0, payload.get("reps"));
        Test.assertEqual("52.5kg", payload.get("weight"));
        var undone = LiftosaurSet.withCompleted(logged, null);
        Test.assert(LiftosaurSet.get(undone, "completed") == null);
        Test.assertEqual(0, LiftosaurSet.doneGet(LiftosaurSet.get(logged, "completed"), "reps"));
        Test.assert(LiftosaurSet.apiCompleted(null) == null);
        Test.assert(LiftosaurSet.apiCompleted([5, null]).get("weight") == null);
        Test.assertEqual(8, LiftosaurSet.apiCompleted(legacySet(true).get("completed")).get("reps"));
        return true;
    }

    (:test)
    static function storageUpgradePreservesWorkoutQueueAndFlags(logger) {
        var store = new LiftosaurSetTestStore();
        var model = LiftosaurUpdateTests.undoModel("rest", 0);
        var entry = model.get("workout").get("entries")[0];
        entry["hasSuperset"] = true;
        entry["hasPromptedVars"] = true;
        entry.get("sets")[0]["isWarmup"] = true;
        entry.get("sets")[1]["hasSetTimer"] = true;
        model["queue"] = [{ "kind" => "set", "setId" => "set1",
            "entryId" => "squat", "completed" => { "reps" => 5, "weight" => "45kg" } }];
        var key = "setLayoutTest";
        try {
            Storage.setValue(key, model);
            store.state = Storage.getValue(key);
            model = store.state;
            model["workout"] = store.compactWorkout(model.get("workout"));
            Storage.setValue(key, model);
            store.state = Storage.getValue(key);
            model = store.state;
            model["workout"] = store.compactWorkout(model.get("workout"));
            var entries = model.get("workout").get("entries");
            var sets = entries[0].get("sets");
            Test.assertEqual(2, sets.size());
            Test.assertEqual("rest", model.get("phase"));
            Test.assertEqual(120, model.get("restEnd"));
            Test.assertEqual(1, model.get("setIndex"));
            Test.assertEqual(true, LiftosaurSet.get(sets[0], "isWarmup"));
            Test.assertEqual(true, LiftosaurSet.get(sets[1], "hasSetTimer"));
            Test.assertEqual(true, entries[0].get("hasSuperset"));
            Test.assertEqual(true, entries[0].get("hasPromptedVars"));
            Test.assertEqual(false, store.supportsWorkout(model.get("workout")));
            Test.assertEqual(5, LiftosaurSet.doneGet(LiftosaurSet.get(sets[0], "completed"), "reps"));
            Test.assertEqual(1, model.get("queue").size());
            Test.assertEqual("set1", model.get("queue")[0].get("setId"));
            Test.assertEqual(5, LiftosaurSet.apiCompleted(model.get("queue")[0].get("completed")).get("reps"));
        } finally {
            Storage.deleteValue(key);
        }
        return true;
    }

    (:test)
    static function packedAmrapLogCorrectionAndUndo(logger) {
        var store = new LiftosaurSetTestStore();
        var updater = new LiftosaurUpdate();
        var model = LiftosaurUpdateTests.amrapModel("working");
        model["workout"] = store.compactWorkout(model.get("workout"));
        model = updater.update(model, { "type" => "SELECT" }, 100).get("model");
        Test.assertEqual("editing", model.get("phase"));
        model = updater.update(model, { "type" => "SELECT" }, 100).get("model");
        Test.assertEqual(8, LiftosaurSet.apiCompleted(model.get("queue")[0].get("completed")).get("reps"));
        model = updater.update(model, { "type" => "SET_RESULT", "code" => 200 }, 100).get("model");
        model = updater.update(model, { "type" => "BACK" }, 100).get("model");
        // Navigate back to the completed set to correct it.
        model["phase"] = "working";
        model["entryIndex"] = 0;
        model["setIndex"] = 0;
        model = updater.update(model, { "type" => "LONG_START" }, 100).get("model");
        model = updater.update(model, { "type" => "ADJUST", "direction" => -1 }, 100).get("model");
        model = updater.update(model, { "type" => "SELECT" }, 100).get("model");
        Test.assertEqual(9, LiftosaurSet.apiCompleted(model.get("queue")[0].get("completed")).get("reps"));
        model = updater.update(model, { "type" => "SET_RESULT", "code" => 200 }, 100).get("model");
        model["phase"] = "confirm-undo";
        model = updater.update(model, { "type" => "SELECT" }, 100).get("model");
        Test.assert(model.get("queue")[0].get("completed") == null);
        Test.assert(LiftosaurSet.get(updater.currentSet(model), "completed") == null);
        return true;
    }
}



