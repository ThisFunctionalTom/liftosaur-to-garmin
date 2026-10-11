using Toybox.Test as Test;
using Toybox.Lang as Lang;

class LiftosaurUpdateTests {
    static function amrapModel(phase) {
        return {
            "phase" => phase,
            "status" => "",
            "queue" => [],
            "entryIndex" => 0,
            "setIndex" => 0,
            "restEnd" => 120,
            "lastSet" => false,
            "selectedAction" => 0,
            "editReps" => 8,
            "workout" => {
                "entries" => [
                    {
                        "sets" => [
                            { "setId" => "amrap1", "reps" => 8, "weight" => "50kg", "timer" => 75, "isAmrap" => true, "completed" => null }
                        ]
                    }
                ]
            }
        };
    }

    static function effectOf(result, index) {
        return result.get("effects")[index].get("type");
    }

    static function setResultModel() {
        var model = amrapModel("rest");
        model["queue"] = [
            { "kind" => "set", "entryId" => "squat", "setId" => "set1" },
            { "kind" => "set", "entryId" => "squat", "setId" => "set2" }
        ];
        model["workout"].get("entries")[0].get("sets")[0]["completed"] = { "reps" => 8, "weight" => "50kg" };
        return model;
    }

    static function setResultWorkout() {
        return {
            "entries" => [
                { "sets" => [
                    { "setId" => "set1", "reps" => 8, "weight" => "50kg", "isAmrap" => true, "completed" => { "reps" => 8, "weight" => "50kg" } },
                    { "setId" => "set2", "reps" => 8, "weight" => "50kg", "isAmrap" => false, "completed" => null }
                ] }
            ]
        };
    }

    static function undoModel(phase, selectedAction) {
        return {
            "phase" => phase,
            "status" => "",
            "queue" => [],
            "entryIndex" => 0,
            "setIndex" => 1,
            "selectedAction" => selectedAction,
            "undo" => { "entryId" => "squat", "setId" => "set1", "entryIndex" => 0, "setIndex" => 0 },
            "restEnd" => 120,
            "lastSet" => false,
            "workout" => {
                "entries" => [
                    {
                        "entryId" => "squat",
                        "name" => "Squat",
                        "sets" => [
                            { "setId" => "set1", "reps" => 5, "weight" => "45kg", "completed" => { "reps" => 5, "weight" => "45kg" } },
                            { "setId" => "set2", "reps" => 5, "weight" => "45kg", "completed" => null }
                        ]
                    }
                ]
            }
        };
    }

    (:test)
    static function selectOnAmrapOpensEditor(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var result = updater.update(amrapModel("working"), { "type" => "SELECT" }, 100);
        Test.assertEqual("editing", result.get("model").get("phase"));
        Test.assertEqual(8, result.get("model").get("editReps"));
        Test.assertEqual(0, result.get("effects").size());
        return true;
    }

    (:test)
    static function selectOnPlannedSetLogsSetInReducer(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var model = amrapModel("working");
        var set = model.get("workout").get("entries")[0].get("sets")[0];
        set["isAmrap"] = false;
        var result = updater.update(model, { "type" => "SELECT" }, 100);
        Test.assertEqual("rest", result.get("model").get("phase"));
        Test.assertEqual(8, result.get("model").get("workout").get("entries")[0].get("sets")[0].get("completed").get("reps"));
        Test.assertEqual("startTicker", effectOf(result, 0));
        Test.assertEqual("flushQueue", effectOf(result, 1));
        return true;
    }

    (:test)
    static function startOnAmrapDuringRestSkipsRestAndEdits(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var result = updater.update(amrapModel("rest"), { "type" => "SELECT" }, 100);
        Test.assertEqual("editing", result.get("model").get("phase"));
        Test.assert(result.get("model").get("restEnd") == null);
        Test.assertEqual("stopTicker", effectOf(result, 0));
        return true;
    }

    (:test)
    static function backDuringRestPreservesWorkoutAndSkipsTimer(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var model = amrapModel("rest");
        var result = updater.update(model, { "type" => "BACK" }, 100);
        Test.assertEqual("working", result.get("model").get("phase"));
        Test.assert(result.get("model").get("restEnd") == null);
        Test.assertEqual(model.get("workout"), result.get("model").get("workout"));
        Test.assertEqual("stopTicker", effectOf(result, 0));
        return true;
    }

    (:test)
    static function backDuringEditCancelsWithoutEffect(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var result = updater.update(amrapModel("editing"), { "type" => "BACK" }, 100);
        Test.assertEqual("working", result.get("model").get("phase"));
        Test.assertEqual(0, result.get("effects").size());
        return true;
    }

    (:test)
    static function finalRestExpiresIntoComplete(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var model = amrapModel("rest");
        model["lastSet"] = true;
        var result = updater.update(model, { "type" => "REST_EXPIRED" }, 200);
        Test.assertEqual("complete", result.get("model").get("phase"));
        Test.assertEqual("stopTicker", effectOf(result, 0));
        Test.assertEqual("vibrate", effectOf(result, 1));
        return true;
    }

    (:test)
    static function adjustChangesEditedReps(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var model = amrapModel("editing");
        var result = updater.update(model, { "type" => "ADJUST", "direction" => -1 }, 100);
        Test.assertEqual(9, result.get("model").get("editReps"));
        Test.assertEqual("editing", result.get("model").get("phase"));
        return true;
    }

    (:test)
    static function successfulSetResponseRemovesOneQueueItem(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var result = updater.update(setResultModel(), {
            "type" => "SET_RESULT", "code" => 200, "workout" => setResultWorkout()
        }, 100);
        Test.assertEqual(1, result.get("model").get("queue").size());
        Test.assertEqual("set2", result.get("model").get("queue")[0].get("setId"));
        Test.assertEqual("rest", result.get("model").get("phase"));
        Test.assertEqual("flushQueue", effectOf(result, 0));
        return true;
    }

    (:test)
    static function failedSetResponseKeepsQueueForRetry(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var result = updater.update(setResultModel(), {
            "type" => "SET_RESULT", "code" => 0, "workout" => null
        }, 100);
        Test.assertEqual(2, result.get("model").get("queue").size());
        Test.assertEqual("Offline - set saved on watch", result.get("model").get("status"));
        Test.assertEqual(0, result.get("effects").size());
        return true;
    }

    (:test)
    static function successfulFinishClearsWorkoutAndLoadsNext(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var model = setResultModel();
        model["phase"] = "finishing";
        model["finishPending"] = true;
        var result = updater.update(model, { "type" => "FINISH_RESULT", "code" => 200 }, 100);
        Test.assertEqual("loading", result.get("model").get("phase"));
        Test.assert(result.get("model").get("workout") == null);
        Test.assertEqual("Workout saved", result.get("model").get("status"));
        Test.assertEqual("stopTicker", effectOf(result, 0));
        Test.assertEqual("loadNext", effectOf(result, 1));
        return true;
    }

    (:test)
    static function failedDiscardReturnsToConfirmation(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var model = setResultModel();
        model["phase"] = "discarding";
        model["discardPending"] = true;
        var result = updater.update(model, { "type" => "DISCARD_RESULT", "code" => 400 }, 100);
        Test.assertEqual("confirm-discard", result.get("model").get("phase"));
        Test.assertEqual("Discard failed: 400", result.get("model").get("status"));
        Test.assert(result.get("model").get("discardPending") == false);
        return true;
    }

    (:test)
    static function successfulDiscardExitsApp(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var model = setResultModel();
        model["phase"] = "discarding";
        var result = updater.update(model, { "type" => "DISCARD_RESULT", "code" => 200 }, 100);
        Test.assertEqual("loading", result.get("model").get("phase"));
        Test.assertEqual("Workout discarded", result.get("model").get("status"));
        Test.assertEqual("stopTicker", effectOf(result, 0));
        Test.assertEqual("exitApp", effectOf(result, 1));
        Test.assertEqual(2, result.get("effects").size());
        return true;
    }

    (:test)
    static function plannedSetLogUpdatesModelAndQueue(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var model = amrapModel("working");
        var set = model.get("workout").get("entries")[0].get("sets")[0];
        set["isAmrap"] = false;
        var result = updater.update(model, { "type" => "SELECT" }, 100);
        var next = result.get("model");
        Test.assertEqual("rest", next.get("phase"));
        Test.assertEqual(175, next.get("restEnd"));
        Test.assertEqual(8, next.get("workout").get("entries")[0].get("sets")[0].get("completed").get("reps"));
        Test.assertEqual("amrap1", next.get("queue")[0].get("setId"));
        Test.assertEqual("startTicker", effectOf(result, 0));
        Test.assertEqual("flushQueue", effectOf(result, 1));
        Test.assert(result.get("model").get("workout") != model.get("workout"));
        Test.assert(model.get("workout").get("entries")[0].get("sets")[0].get("completed") == null);
        return true;
    }

    (:test)
    static function backFromWorkingOpensWorkoutOptions(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var model = amrapModel("working");
        var result = updater.update(model, { "type" => "BACK" }, 100);
        Test.assertEqual("actions", result.get("model").get("phase"));
        Test.assertEqual(0, result.get("model").get("selectedAction"));
        Test.assertEqual(0, result.get("effects").size());
        return true;
    }

    (:test)
    static function backExitsFromPreviewLoadingAndError(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var phases = ["preview", "loading", "error"];
        for (var i = 0; i < phases.size(); i += 1) {
            var result = updater.update(amrapModel(phases[i]), { "type" => "BACK" }, 100);
            Test.assertEqual(phases[i], result.get("model").get("phase"));
            Test.assertEqual(1, result.get("effects").size());
            Test.assertEqual("exitApp", effectOf(result, 0));
        }
        return true;
    }

    (:test)
    static function leaveActionRestoresWorkoutAndRequestsAppExit(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var model = amrapModel("actions");
        model["selectedAction"] = 1;
        model["restEnd"] = 150;
        var result = updater.update(model, { "type" => "SELECT" }, 100);
        Test.assertEqual("rest", result.get("model").get("phase"));
        Test.assertEqual(150, result.get("model").get("restEnd"));
        Test.assertEqual("exitApp", effectOf(result, 0));
        return true;
    }

    (:test)
    static function discardActionOpensConfirmation(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var model = amrapModel("actions");
        model["selectedAction"] = 2;
        var result = updater.update(model, { "type" => "SELECT" }, 100);
        Test.assertEqual("confirm-discard", result.get("model").get("phase"));
        Test.assertEqual(0, result.get("effects").size());
        return true;
    }

    (:test)
    static function undoLastCompletedSetIsAvailableFromMenuOnNextSet(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var model = undoModel("actions", 2);
        var confirm = updater.update(model, { "type" => "SELECT" }, 100);
        Test.assertEqual("confirm-undo", confirm.get("model").get("phase"));
        Test.assertEqual(0, confirm.get("effects").size());

        var undone = updater.update(confirm.get("model"), { "type" => "SELECT" }, 100);
        var next = undone.get("model");
        Test.assertEqual("working", next.get("phase"));
        Test.assertEqual(0, next.get("entryIndex"));
        Test.assertEqual(0, next.get("setIndex"));
        Test.assert(next.get("workout").get("entries")[0].get("sets")[0].get("completed") == null);
        Test.assertEqual("set1", next.get("queue")[0].get("setId"));
        Test.assert(next.get("queue")[0].get("completed") == null);
        Test.assert(next.get("queue")[0].get("undo") == true);
        Test.assertEqual("stopTicker", effectOf(undone, 0));
        Test.assertEqual("flushQueue", effectOf(undone, 1));
        return true;
    }

    (:test)
    static function cancelUndoReturnsToWorkoutMenu(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var model = undoModel("confirm-undo", 2);
        var result = updater.update(model, { "type" => "BACK" }, 100);
        Test.assertEqual("actions", result.get("model").get("phase"));
        Test.assertEqual(2, result.get("model").get("selectedAction"));
        Test.assertEqual(0, result.get("effects").size());
        return true;
    }

    (:test)
    static function undoAcknowledgementKeepsCursorOnUndoneSet(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var model = undoModel("working", 0);
        model["setIndex"] = 0;
        model.get("workout").get("entries")[0].get("sets")[0]["completed"] = null;
        model["queue"] = [
            { "kind" => "set", "entryId" => "squat", "setId" => "set1", "completed" => null, "entryIndex" => 0, "setIndex" => 0, "undo" => true }
        ];
        model.get("workout").get("entries")[0].get("sets")[1]["completed"] = { "reps" => 5, "weight" => "45kg" };
        var serverWorkout = {
            "entries" => [
                { "sets" => [
                    { "setId" => "set1", "reps" => 5, "weight" => "45kg", "completed" => null },
                    { "setId" => "set2", "reps" => 5, "weight" => "45kg", "completed" => { "reps" => 5, "weight" => "45kg" } }
                ] }
            ]
        };
        var result = updater.update(model, { "type" => "SET_RESULT", "code" => 200, "workout" => serverWorkout }, 100);
        Test.assertEqual(0, result.get("model").get("entryIndex"));
        Test.assertEqual(0, result.get("model").get("setIndex"));
        Test.assertEqual("working", result.get("model").get("phase"));
        Test.assertEqual("Set undone", result.get("model").get("status"));
        return true;
    }

    (:test)
    static function completedSetCorrectionIsReducerOwned(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var model = amrapModel("editing");
        var set = model.get("workout").get("entries")[0].get("sets")[0];
        set["completed"] = { "reps" => 6, "weight" => "50kg" };
        model["editCompleted"] = true;
        model["editReps"] = 7;
        var result = updater.update(model, { "type" => "SELECT" }, 100);
        Test.assertEqual("working", result.get("model").get("phase"));
        Test.assertEqual(7, result.get("model").get("workout").get("entries")[0].get("sets")[0].get("completed").get("reps"));
        Test.assert(result.get("model").get("queue")[0].get("correction") == true);
        Test.assertEqual("Saving correction", result.get("model").get("status"));
        Test.assertEqual("flushQueue", effectOf(result, 0));
        return true;
    }

    (:test)
    static function finishAndDiscardInitiationAreReducerOwned(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var finishModel = amrapModel("confirm-finish");
        var finish = updater.update(finishModel, { "type" => "SELECT" }, 100);
        Test.assertEqual("finishing", finish.get("model").get("phase"));
        Test.assertEqual(100000, finish.get("model").get("endTime"));
        Test.assertEqual("sendFinish", effectOf(finish, 0));

        var discardModel = amrapModel("confirm-discard");
        var discard = updater.update(discardModel, { "type" => "SELECT", "requestBusy" => true }, 100);
        Test.assertEqual("discarding", discard.get("model").get("phase"));
        Test.assert(discard.get("model").get("discardPending") == true);
        Test.assertEqual(0, discard.get("effects").size());

        var immediate = updater.update(discardModel, { "type" => "SELECT", "requestBusy" => false }, 100);
        Test.assertEqual("sendDiscard", effectOf(immediate, 0));
        return true;
    }

    (:test)
    static function requestStatusChangesGoThroughReducer(logger as Test.Logger) as Lang.Boolean {
        var updater = new LiftosaurUpdate();
        var loading = updater.update(amrapModel("loading"), { "type" => "CURRENT_REQUEST" }, 100);
        Test.assertEqual("Checking workout", loading.get("model").get("status"));
        var next = updater.update(loading.get("model"), { "type" => "LOAD_NEXT" }, 100);
        Test.assertEqual("Loading next workout", next.get("model").get("status"));
        Test.assertEqual("loading", next.get("model").get("phase"));
        return true;
    }
}
