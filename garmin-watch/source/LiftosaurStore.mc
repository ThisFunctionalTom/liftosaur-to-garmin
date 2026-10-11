using Toybox.Application.Storage;
using Toybox.Attention;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.Timer;

class LiftosaurStore {
    var api;
    var state;
    var changed;
    var ticker;
    var requestBusy;
    var retryAfter;
    var updater;

    function initialize() {
        api = new LiftosaurApi();
        state = Storage.getValue("workoutState");
        if (state == null) {
            state = { "phase" => "loading", "queue" => [], "status" => "" };
        }
        changed = null;
        requestBusy = false;
        retryAfter = 0;
        updater = new LiftosaurUpdate();
        ticker = new Timer.Timer();
    }

    function setChanged(callback) {
        changed = callback;
    }

    function isText(value, expected) {
        return value != null && value.equals(expected);
    }

    function dispatchMessage(type, value, payload) {
        var message = { "type" => type };
        message["requestBusy"] = requestBusy;
        if (value != null) { message["direction"] = value; }
        if (type.equals("CURRENT_RESULT") || type.equals("NEXT_RESULT") || type.equals("START_RESULT") || type.equals("SET_RESULT") || type.equals("FINISH_RESULT") || type.equals("DISCARD_RESULT")) {
            message["code"] = value;
            message["workout"] = payload;
        }
        var updateResult = updater.update(state, message, Time.now().value());
        state = updateResult.get("model");
        if (updateResult.get("changed") == true) { notify(); }
        runEffects(updateResult.get("effects"));
    }

    function runEffects(effects) {
        for (var i = 0; i < effects.size(); i += 1) {
            var effect = effects[i];
            var type = effect.get("type");
            if (isText(type, "startWorkout")) { startWorkout(); }
            else if (isText(type, "stopTicker")) { ticker.stop(); }
            else if (isText(type, "startTicker")) { startTicker(); }
            else if (isText(type, "flushQueue")) { flushQueue(); }
            else if (isText(type, "sendFinish")) { sendFinish(); }
            else if (isText(type, "sendDiscard")) { sendDiscardRequest(); }
            else if (isText(type, "loadNext")) { loadNext(); }
            else if (isText(type, "exitApp")) {
                ticker.stop();
                save();
                System.exit();
            }
            else if (isText(type, "vibrate")) {
                if (Attention has :vibrate) {
                    Attention.vibrate([ new Attention.VibeProfile(100, 500) ]);
                }
            }
        }
    }

    function copyField(source, destination, key) {
        var value = source.get(key);
        if (value != null) { destination[key] = value; }
    }

    function compactWorkout(workout) {
        var compact = {};
        copyField(workout, compact, "programId");
        copyField(workout, compact, "dayName");
        copyField(workout, compact, "startTime");

        var dayData = workout.get("dayData");
        if (dayData != null) {
            var compactDay = {};
            copyField(dayData, compactDay, "week");
            copyField(dayData, compactDay, "dayInWeek");
            compact["dayData"] = compactDay;
        }

        var entries = workout.get("entries");
        var compactEntries = [];
        for (var i = 0; i < entries.size(); i += 1) {
            var entry = entries[i];
            var compactEntry = {};
            copyField(entry, compactEntry, "entryId");
            copyField(entry, compactEntry, "name");
            compactEntry["hasSuperset"] = entry.get("superset") != null;
            var prompted = entry.get("promptedVars");
            compactEntry["hasPromptedVars"] = prompted != null && prompted.size() > 0;

            var compactSets = [];
            var warmupSets = entry.get("warmupSets");
            if (warmupSets != null) {
                for (var j = 0; j < warmupSets.size(); j += 1) {
                    compactSets.add(compactSet(warmupSets[j], true));
                }
            }
            var sets = entry.get("sets");
            if (sets != null) {
                for (var k = 0; k < sets.size(); k += 1) {
                    compactSets.add(compactSet(sets[k], false));
                }
            }
            compactEntry["sets"] = compactSets;
            compactEntries.add(compactEntry);
        }
        compact["entries"] = compactEntries;
        return compact;
    }

    function compactSet(set, isWarmup) {
        var compact = {};
        copyField(set, compact, "setId");
        compact["isWarmup"] = isWarmup || set.get("isWarmup") == true;
        copyField(set, compact, "reps");
        copyField(set, compact, "weight");
        copyField(set, compact, "isAmrap");
        copyField(set, compact, "timer");
        copyField(set, compact, "askWeight");
        copyField(set, compact, "logRpe");
        copyField(set, compact, "isUnilateral");
        compact["hasSetTimer"] = set.get("setTimer") != null;

        var completed = set.get("completed");
        if (completed != null) {
            var compactCompleted = {};
            copyField(completed, compactCompleted, "reps");
            copyField(completed, compactCompleted, "weight");
            compact["completed"] = compactCompleted;
        }
        return compact;
    }

    function notify() {
        // A workout response can exceed the simulator/device's remaining
        // object-store capacity. A failed save must not prevent the UI from
        // showing the response that was just received.
        try {
            save();
        } catch (ex) {
            System.println("[Liftosaur] ERROR saving workout state");
            ex.printStackTrace();
            state["status"] = "Workout loaded; watch storage is full";
        }
        refreshView();
    }

    function refreshView() {
        if (changed != null) {
            changed.invoke();
        }
    }

    function save() {
        Storage.setValue("workoutState", state);
    }

    function open() {
        if (state.get("workout") != null) {
            state["workout"] = compactWorkout(state.get("workout"));
        }
        if (!api.hasKey()) {
            System.println("[Liftosaur] ERROR Liftosaur API key is missing");
            dispatchMessage("NO_API_KEY", null, null);
            return;
        }

        if (isActive()) { startTicker(); }
        requestCurrent();
    }

    function isActive() {
        var phase = state.get("phase");
        return isText(phase, "working") || isText(phase, "editing") || isText(phase, "rest") || isText(phase, "complete") || isText(phase, "finishing") || isText(phase, "actions") || isText(phase, "confirm-finish") || isText(phase, "confirm-discard") || isText(phase, "confirm-undo") || isText(phase, "discarding");
    }

    function undoTarget() {
        var selected = currentSet();
        var workout = state.get("workout");
        if (selected != null && selected.get("completed") != null) {
            return { "entryIndex" => state.get("entryIndex"), "setIndex" => state.get("setIndex"), "entry" => currentEntry(), "set" => selected, "selected" => true };
        }

        var last = state.get("undo");
        if (last != null) {
            var lastEntryIndex = last.get("entryIndex");
            var lastSetIndex = last.get("setIndex");
            if (workout != null && lastEntryIndex != null && lastSetIndex != null &&
                lastEntryIndex >= 0 && lastEntryIndex < workout.get("entries").size()) {
                var lastEntry = workout.get("entries")[lastEntryIndex];
                var lastSets = lastEntry.get("sets");
                if (lastSetIndex >= 0 && lastSetIndex < lastSets.size() && lastSets[lastSetIndex].get("completed") != null) {
                    var lastSet = lastSets[lastSetIndex];
                    return { "entryIndex" => lastEntryIndex, "setIndex" => lastSetIndex, "entry" => lastEntry, "set" => lastSet, "selected" => false };
                }
            }
        }

        var phase = state.get("phase");
        if (!isText(phase, "complete") && !isText(phase, "actions") && !isText(phase, "confirm-undo")) { return null; }
        if (workout == null) { return null; }
        var entries = workout.get("entries");
        for (var i = entries.size() - 1; i >= 0; i -= 1) {
            var sets = entries[i].get("sets");
            for (var j = sets.size() - 1; j >= 0; j -= 1) {
                if (sets[j].get("completed") != null) {
                    return { "entryIndex" => i, "setIndex" => j, "entry" => entries[i], "set" => sets[j], "selected" => false };
                }
            }
        }
        return null;
    }

    function requestCurrent() {
        if (requestBusy) { return; }
        requestBusy = true;
        dispatchMessage("CURRENT_REQUEST", null, null);
        api.get("/workout/current", method(:onCurrent));
    }

    function onCurrent(code, data) {
        if (code != 200) { System.println("[Liftosaur] ERROR GET /workout/current: " + code.toString()); }
        requestBusy = false;
        var compact = null;
        if (code == 200 && data != null) {
            var envelope = data.get("data");
            var workout = envelope == null ? null : envelope.get("workout");
            if (workout != null) { compact = compactWorkout(workout); }
        }
        dispatchMessage("CURRENT_RESULT", code, compact);
    }

    function loadNext() {
        if (requestBusy) { return; }
        requestBusy = true;
        dispatchMessage("LOAD_NEXT", null, null);
        api.get("/workout/next", method(:onNext));
    }

    function onNext(code, data) {
        requestBusy = false;
        if (code != 200) { System.println("[Liftosaur] ERROR GET /workout/next: " + code.toString()); }
        var compact = null;
        if (code == 200 && data != null) {
            var envelope = data.get("data");
            var workout = envelope == null ? null : envelope.get("workout");
            if (workout != null) { compact = compactWorkout(workout); }
        }
        dispatchMessage("NEXT_RESULT", code, compact);
    }

    function startWorkout() {
        if (!supportsWorkout(state.get("workout"))) {
            dispatchMessage("UNSUPPORTED_WORKOUT", null, null);
            return;
        }
        if (requestBusy) { return; }
        requestBusy = true;
        dispatchMessage("START_REQUEST", null, null);
        var dayData = state.get("workout").get("dayData");
        var startBody = {
            "programId" => state.get("workout").get("programId"),
            "week" => dayData.get("week"),
            "dayInWeek" => dayData.get("dayInWeek")
        };
        api.post("/workout/start", startBody, method(:onStartWorkout));
    }

    function onStartWorkout(code, data) {
        requestBusy = false;
        if (code != 200) { System.println("[Liftosaur] ERROR POST /workout/start: " + code.toString()); }
        var compact = null;
        if (code == 200 && data != null) {
            var envelope = data.get("data");
            var workout = envelope == null ? null : envelope.get("workout");
            if (workout != null) { compact = compactWorkout(workout); }
        }
        dispatchMessage("START_RESULT", code, compact);
    }

    function entryAt(index) {
        var entries = state.get("workout").get("entries");
        return index < entries.size() ? entries[index] : null;
    }

    function setAt(entryIndex, setIndex) {
        var entry = entryAt(entryIndex);
        if (entry == null) { return null; }
        var sets = entry.get("sets");
        return setIndex < sets.size() ? sets[setIndex] : null;
    }

    function currentEntry() {
        return entryAt(state.get("entryIndex") == null ? 0 : state.get("entryIndex"));
    }

    function currentSet() {
        return setAt(state.get("entryIndex") == null ? 0 : state.get("entryIndex"), state.get("setIndex") == null ? 0 : state.get("setIndex"));
    }

    function select() {
        dispatchMessage("SELECT", null, null);
    }

    function menu() {
        dispatchMessage("MENU", null, null);
    }

    function adjust(direction) {
        dispatchMessage("ADJUST", direction, null);
    }

    function supportsWorkout(workout) {
        if (workout == null) { return false; }
        var entries = workout.get("entries");
        for (var i = 0; i < entries.size(); i += 1) {
            var entry = entries[i];
            if (entry.get("hasSuperset") == true || entry.get("hasPromptedVars") == true) { return false; }
            var sets = entry.get("sets");
            for (var j = 0; j < sets.size(); j += 1) {
                var set = sets[j];
                if (set.get("isWarmup") == true) { continue; }
                if (set.get("askWeight") == true || set.get("logRpe") == true || set.get("isUnilateral") == true || set.get("hasSetTimer") == true) { return false; }
            }
        }
        return true;
    }

    function flushQueue() {
        var queue = state.get("queue");
        if (queue == null || queue.size() == 0) { return; }
        if (requestBusy) {
            return;
        }
        requestBusy = true;
        var action = queue[0];
        if (isText(action.get("kind"), "set")) {
            var body = {
                "entryId" => action.get("entryId"),
                "setId" => action.get("setId"),
                "completed" => action.get("completed")
            };
            api.post("/workout/set", body, method(:onSetSynced));
        }
    }

    function onSetSynced(code, data) {
        requestBusy = false;
        if (code != 200) { System.println("[Liftosaur] ERROR POST /workout/set: " + code.toString()); }
        var compact = null;
        if (code == 200 && data != null) {
            var envelope = data.get("data");
            var updatedWorkout = envelope == null ? null : envelope.get("workout");
            if (updatedWorkout != null) { compact = compactWorkout(updatedWorkout); }
        } else {
            retryAfter = Time.now().value() + (code <= 0 ? 15 : 60);
        }
        dispatchMessage("SET_RESULT", code, compact);
    }

    function sendDiscardRequest() {
        if (requestBusy) {
            return;
        }
        if (state.get("workout") == null || state.get("startedAt") == null) { return; }
        requestBusy = true;
        api.delete("/workout/current", { "startTime" => state.get("startedAt") }, method(:onDiscarded));
    }

    function onDiscarded(code, data) {
        requestBusy = false;
        if (code != 200) { System.println("[Liftosaur] ERROR DELETE /workout/current: " + code.toString()); }
        dispatchMessage("DISCARD_RESULT", code, null);
    }

    function sendFinish() {
        if (requestBusy || state.get("finishPending") != true) { return; }
        if (state.get("queue").size() > 0) { flushQueue(); return; }
        requestBusy = true;
        api.post("/workout/finish", {
            "startTime" => state.get("startedAt"),
            "endTime" => state.get("endTime")
        }, method(:onFinished));
    }

    function onFinished(code, data) {
        requestBusy = false;
        if (code != 200) {
            System.println("[Liftosaur] ERROR POST /workout/finish: " + code.toString());
            retryAfter = Time.now().value() + 15;
        }
        dispatchMessage("FINISH_RESULT", code, null);
    }

    function startTicker() {
        ticker.start(method(:tick), 1000, true);
    }

    function tick() {
        if (isActive() && state.get("queue") != null && state.get("queue").size() > 0 && !requestBusy && Time.now().value() >= retryAfter) {
            retryAfter = Time.now().value() + 15;
            flushQueue();
        }
        if (isText(state.get("phase"), "rest") && state.get("restEnd") != null) {
            var remaining = state.get("restEnd") - Time.now().value();
            if (remaining <= 0) {
                dispatchMessage("REST_EXPIRED", null, null);
                return;
            }
            refreshView();
        } else if (isText(state.get("phase"), "finishing")) {
            if (Time.now().value() >= retryAfter) {
                retryAfter = Time.now().value() + 15;
                if (state.get("queue").size() > 0) { flushQueue(); }
                else { sendFinish(); }
            }
        }
    }

    function remainingRest() {
        if (state.get("restEnd") == null) { return 0; }
        var remaining = state.get("restEnd") - Time.now().value();
        return remaining < 0 ? 0 : remaining;
    }

}
