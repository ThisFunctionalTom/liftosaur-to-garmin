using Toybox.System;
using Toybox.Test;
using Toybox.Application.Storage;

// No HTTP requests or writes to the user's saved workout in these tests.
(:test)
class LiftosaurMemoryStoreStub {
    var changed;
    function setChanged(callback) { changed = callback; }
}

(:test)
class LiftosaurMemoryTests {
    static function createView() {
        var store = new LiftosaurMemoryStoreStub();
        var view = new LiftosaurView(store);
    }

    (:test)
    static function releasedViewsDoNotRetainStores(logger) {
        createView();
        var before = System.getSystemStats().usedMemory;
        for (var i = 0; i < 20; i += 1) { createView(); }
        var growth = System.getSystemStats().usedMemory - before;
        logger.debug("Released view/store memory growth: " + growth);
        Test.assert(growth <= 256);
        return true;
    }

    static function completeWorkout() {
        var sets = [];
        for (var i = 0; i < 32; i += 1) {
            sets.add(LiftosaurSet.pack({ "setId" => i.toString(), "reps" => 5, "weight" => "45kg", "timer" => 60 }, false));
        }
        var model = {
            "phase" => "working", "status" => "", "queue" => [],
            "entryIndex" => 0, "setIndex" => 0,
            "workout" => { "entries" => [ { "entryId" => "squat", "sets" => sets } ] }
        };
        sets = null;
        var updater = new LiftosaurUpdate();
        var before = System.getSystemStats().usedMemory;
        for (var j = 0; j < 32; j += 1) {
            model = updater.update(model, { "type" => "SELECT" }, 100).get("model");
            Test.assertEqual(1, model.get("queue").size());
            model = updater.update(model, { "type" => "SET_RESULT", "code" => 200 }, 100).get("model");
            Test.assertEqual(0, model.get("queue").size());
            model = updater.update(model, { "type" => "BACK" }, 100).get("model");
        }
        Test.assertEqual("complete", model.get("phase"));
        return System.getSystemStats().usedMemory - before;
    }

    (:test)
    static function repeatedWorkoutsReleaseModelsAndQueues(logger) {
        var completedGrowth = completeWorkout();
        var before = System.getSystemStats().usedMemory;
        for (var i = 0; i < 10; i += 1) { completeWorkout(); }
        var growth = System.getSystemStats().usedMemory - before;
        logger.debug("Released workout memory growth: " + growth);
        logger.debug("Live model growth for 32 completed sets: " + completedGrowth);
        Test.assert(growth <= 256);
        return true;
    }

    static function correctSet(updater, model) {
        model = updater.update(model, { "type" => "LONG_START" }, 100).get("model");
        model = updater.update(model, { "type" => "SELECT" }, 100).get("model");
        model = updater.update(model, { "type" => "SET_RESULT", "code" => 200 }, 100).get("model");
        Test.assertEqual(0, model.get("queue").size());
        return model;
    }

    (:test)
    static function repeatedCorrectionsAndStorageWritesDoNotGrow(logger) {
        var updater = new LiftosaurUpdate();
        var model = LiftosaurUpdateTests.undoModel("working", 0);
        model["setIndex"] = 0;
        model = correctSet(updater, model);
        // Dedicated test key; never overwrite workoutState or app settings.
        var storageKey = "memoryAuditTest";
        try {
            Storage.setValue(storageKey, model);
            var before = System.getSystemStats().usedMemory;
            for (var i = 0; i < 100; i += 1) {
                model = correctSet(updater, model);
                Storage.setValue(storageKey, model);
            }
            var growth = System.getSystemStats().usedMemory - before;
            logger.debug("100 corrections and storage writes memory growth: " + growth);
            Test.assert(growth <= 256);
        } finally {
            Storage.deleteValue(storageKey);
        }
        return true;
    }
}
