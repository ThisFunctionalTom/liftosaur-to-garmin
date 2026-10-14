class LiftosaurUpdate {
    function isText(value, expected) {
        return value != null && value.equals(expected);
    }

    function copyModel(model) {
        var next = {};
        var keys = [
            "phase", "status", "workout", "previewWorkout", "demo", "queue", "entryIndex", "setIndex", "activeEntryIndex",
            "startedAt", "restEnd", "lastSet", "undo", "selectedAction",
            "editReps", "editWeight", "editField", "editAmrap", "editCompleted",
            "editEntryIndex", "editSetIndex", "editSetId",
            "discardPending", "finishPending", "endTime"
        ];
        for (var i = 0; i < keys.size(); i += 1) {
            var value = model.get(keys[i]);
            if (value != null) { next[keys[i]] = value; }
        }
        return next;
    }

    function result(model, effects, changed) {
        return { "model" => model, "effects" => effects, "changed" => changed };
    }

    function copyArray(source) {
        var copy = [];
        if (source != null) {
            for (var i = 0; i < source.size(); i += 1) { copy.add(source[i]); }
        }
        return copy;
    }

    function copyObjectFields(source, keys) {
        var copy = {};
        for (var i = 0; i < keys.size(); i += 1) {
            var value = source.get(keys[i]);
            if (value != null) { copy[keys[i]] = value; }
        }
        return copy;
    }

    // Copy only the path being changed. Unmodified entries and sets can be
    // shared, keeping the reducer immutable without duplicating the full
    // workout in the fenix 5's limited heap.
    function replaceSet(model, entryIndex, setIndex, completed) {
        var workout = model.get("workout");
        var entries = copyArray(workout.get("entries"));
        var sourceEntry = entries[entryIndex];
        var entry = copyObjectFields(sourceEntry, ["entryId", "name", "hasSuperset", "hasPromptedVars"]);
        var sets = copyArray(sourceEntry.get("sets"));
        var sourceSet = sets[setIndex];
        var set = LiftosaurSet.withCompleted(sourceSet, completed);
        sets[setIndex] = set;
        entry["sets"] = sets;
        entries[entryIndex] = entry;
        var nextWorkout = copyObjectFields(workout, ["programId", "dayName", "startTime"]);
        nextWorkout["dayData"] = workout.get("dayData");
        nextWorkout["entries"] = entries;
        model["workout"] = nextWorkout;
    }

    function appendQueue(model, action) {
        var queue = copyArray(model.get("queue"));
        queue.add(action);
        model["queue"] = queue;
    }

    function returnFromDemo(next, model, effects) {
        next["phase"] = "preview";
        next["workout"] = model.get("previewWorkout");
        next["previewWorkout"] = null;
        next["demo"] = false;
        next["queue"] = [];
        next["entryIndex"] = 0;
        next["setIndex"] = 0;
        next["activeEntryIndex"] = 0;
        next["startedAt"] = null;
        next["restEnd"] = null;
        next["lastSet"] = false;
        next["undo"] = null;
        next["selectedAction"] = 0;
        next["editCompleted"] = false;
        next["editReps"] = null;
        next["editWeight"] = null;
        next["editField"] = null;
        next["editEntryIndex"] = null;
        next["editSetIndex"] = null;
        next["editSetId"] = null;
        next["discardPending"] = false;
        next["finishPending"] = false;
        next["status"] = "";
        effects.add({ "type" => "stopTicker" });
    }

    function beginDemo(next, model) {
        var workout = model.get("workout");
        if (workout == null) { return false; }
        next["previewWorkout"] = workout;
        next["demo"] = true;
        next["phase"] = "working";
        next["queue"] = [];
        next["entryIndex"] = 0;
        next["setIndex"] = 0;
        next["activeEntryIndex"] = 0;
        next["startedAt"] = null;
        next["restEnd"] = null;
        next["lastSet"] = false;
        next["undo"] = null;
        next["selectedAction"] = 0;
        next["status"] = "";
        normalizeCursor(next);
        return true;
    }

    function setCompletedValue(model, entryIndex, setIndex, reps, weight, remove) {
        var completed = null;
        if (!remove) {
            completed = [reps, weight];
        }
        replaceSet(model, entryIndex, setIndex, completed);
    }

    function isFirstIncompleteSet(model, entryIndex, setIndex) {
        var workout = model.get("workout");
        if (workout == null || entryIndex == null || setIndex == null) { return false; }
        var entries = workout.get("entries");
        if (entryIndex < 0 || entryIndex >= entries.size()) { return false; }
        var sets = entries[entryIndex].get("sets");
        if (setIndex < 0 || setIndex >= sets.size() || LiftosaurSet.get(sets[setIndex], "completed") != null) { return false; }
        for (var i = 0; i < setIndex; i += 1) {
            if (LiftosaurSet.get(sets[i], "completed") == null) { return false; }
        }
        return true;
    }

    function nextActiveSet(model) {
        var workout = model.get("workout");
        if (workout == null) { return null; }
        var entries = workout.get("entries");
        var firstEntry = model.get("activeEntryIndex");
        if (firstEntry == null) { firstEntry = model.get("entryIndex"); }
        if (firstEntry == null || firstEntry < 0) { firstEntry = 0; }
        for (var i = firstEntry; i < entries.size(); i += 1) {
            var sets = entries[i].get("sets");
            for (var j = 0; j < sets.size(); j += 1) {
                if (LiftosaurSet.get(sets[j], "completed") == null) {
                    return { "entryIndex" => i, "setIndex" => j };
                }
            }
        }
        return null;
    }

    function logSet(next, model, now, effects) {
        var entryIndex = model.get("entryIndex");
        var setIndex = model.get("setIndex");
        if (isText(model.get("phase"), "editing")) {
            if (model.get("editEntryIndex") != null) { entryIndex = model.get("editEntryIndex"); }
            if (model.get("editSetIndex") != null) { setIndex = model.get("editSetIndex"); }
        }
        if (entryIndex == null || setIndex == null) { return false; }
        var entry = model.get("workout").get("entries")[entryIndex];
        var set = entry == null ? null : entry.get("sets")[setIndex];
        if (set == null || entry == null || LiftosaurSet.get(set, "completed") != null || !isFirstIncompleteSet(model, entryIndex, setIndex)) { return false; }
        var reps = isText(model.get("phase"), "editing") ? model.get("editReps") : LiftosaurSet.get(set, "reps");
        var weight = isText(model.get("phase"), "editing") ? model.get("editWeight") : LiftosaurSet.get(set, "weight");
        var completed = [reps, weight];
        var action = {
            "kind" => "set", "entryId" => entry.get("entryId"),
            "setId" => LiftosaurSet.get(set, "setId"), "completed" => completed,
            "entryIndex" => entryIndex, "setIndex" => setIndex
        };
        replaceSet(next, entryIndex, setIndex, completed);
        if (model.get("demo") != true) { appendQueue(next, action); }
        next["undo"] = action;
        next["activeEntryIndex"] = entryIndex;
        next["entryIndex"] = entryIndex;
        next["setIndex"] = setIndex + 1;
        next["phase"] = "working";
        normalizeCursor(next);
        next["lastSet"] = isText(next.get("phase"), "complete");
        next["phase"] = "rest";
        var timer = LiftosaurSet.get(set, "timer");
        next["restEnd"] = now + (timer == null ? 0 : timer);
        next["status"] = "";
        next["editCompleted"] = false;
        next["editEntryIndex"] = null;
        next["editSetIndex"] = null;
        next["editSetId"] = null;
        effects.add({ "type" => "startTicker" });
        if (model.get("demo") != true) { effects.add({ "type" => "flushQueue" }); }
        return true;
    }

    function saveEditedSet(next, model, now, effects) {
        if (model.get("editCompleted") == true) {
            var entryIndex = model.get("editEntryIndex") == null ? model.get("entryIndex") : model.get("editEntryIndex");
            var setIndex = model.get("editSetIndex") == null ? model.get("setIndex") : model.get("editSetIndex");
            if (entryIndex == null || setIndex == null) { return false; }
            var entry = model.get("workout").get("entries")[entryIndex];
            var set = entry == null ? null : entry.get("sets")[setIndex];
            if (set == null || entry == null || LiftosaurSet.get(set, "completed") == null) { return false; }
            var editSetId = model.get("editSetId");
            if (editSetId != null && LiftosaurSet.get(set, "setId") != editSetId) { return false; }
            var reps = model.get("editReps");
            var weight = model.get("editWeight");
            var completed = [reps, weight];
            var action = {
                "kind" => "set", "correction" => true,
                "entryId" => entry.get("entryId"), "setId" => LiftosaurSet.get(set, "setId"),
                "completed" => completed, "entryIndex" => entryIndex, "setIndex" => setIndex
            };
            replaceSet(next, entryIndex, setIndex, completed);
            if (model.get("demo") != true) { appendQueue(next, action); }
            next["entryIndex"] = entryIndex;
            next["setIndex"] = setIndex;
            next["phase"] = "working";
            next["editCompleted"] = false;
            next["editEntryIndex"] = null;
            next["editSetIndex"] = null;
            next["editSetId"] = null;
            next["status"] = model.get("demo") == true ? "Demo correction saved" : "Saving correction";
            if (model.get("demo") != true) { effects.add({ "type" => "flushQueue" }); }
            return true;
        }
        return logSet(next, model, now, effects);
    }

    function moveSet(next, model, direction) {
        var workout = model.get("workout");
        if (workout == null) { return false; }
        var entries = workout.get("entries");
        var positions = [];
        for (var i = 0; i < entries.size(); i += 1) {
            var sets = entries[i].get("sets");
            for (var j = 0; j < sets.size(); j += 1) { positions.add([i, j]); }
        }
        if (positions.size() == 0) { return false; }
        var current = -1;
        for (var k = 0; k < positions.size(); k += 1) {
            if (positions[k][0] == model.get("entryIndex") && positions[k][1] == model.get("setIndex")) { current = k; break; }
        }
        if (current < 0) { current = direction > 0 ? -1 : positions.size(); }
        var target = current + direction;
        if (target < 0) { target = positions.size() - 1; }
        if (target >= positions.size()) { target = 0; }
        next["entryIndex"] = positions[target][0];
        next["setIndex"] = positions[target][1];
        if (isText(model.get("phase"), "complete") ||
            (!isText(model.get("phase"), "rest") && direction > 0 && positions[target][0] != model.get("entryIndex"))) {
            next["activeEntryIndex"] = positions[target][0];
        }
        if (isText(model.get("phase"), "complete")) { next["phase"] = "working"; }
        var selected = entries[positions[target][0]].get("sets")[positions[target][1]];
        next["status"] = LiftosaurSet.get(selected, "completed") == null ? "" : "Already logged";
        return true;
    }

    function moveExercise(next, model, direction) {
        var workout = model.get("workout");
        if (workout == null) { return false; }
        var entries = workout.get("entries");
        if (entries.size() == 0) { return false; }
        var current = model.get("entryIndex");
        if (current == null || current < 0 || current >= entries.size()) {
            current = direction > 0 ? entries.size() - 1 : 0;
        }
        var target = current + direction;
        if (target < 0) { target = entries.size() - 1; }
        if (target >= entries.size()) { target = 0; }
        var sets = entries[target].get("sets");
        if (sets.size() == 0) { return false; }
        var setIndex = direction > 0 ? 0 : sets.size() - 1;
        next["entryIndex"] = target;
        next["setIndex"] = setIndex;
        if (isText(model.get("phase"), "complete") ||
            (!isText(model.get("phase"), "rest") && direction > 0)) {
            next["activeEntryIndex"] = target;
        }
        if (isText(model.get("phase"), "complete")) { next["phase"] = "working"; }
        var selected = sets[setIndex];
        next["status"] = LiftosaurSet.get(selected, "completed") == null ? "" : "Already logged";
        return true;
    }

    function adjustEditedWeight(next, model, direction) {
        var weight = model.get("editWeight");
        if (weight == null) { return false; }
        var chars = weight.toCharArray();
        var splitAt = chars.size();
        for (var i = 0; i < chars.size(); i += 1) {
            var character = chars[i].toString().toLower();
            if (character.equals("k") || character.equals("l")) { splitAt = i; break; }
        }
        var value = weight.substring(0, splitAt).toFloat();
        var newValue = value + direction;
        if (newValue < 0) { newValue = 0; }
        next["editWeight"] = newValue.toString() + weight.substring(splitAt, chars.size());
        return true;
    }

    function beginFinish(next, model, now, effects) {
        if (model.get("workout") == null) { return false; }
        if (model.get("demo") == true) {
            returnFromDemo(next, model, effects);
            return true;
        }
        next["phase"] = "finishing";
        next["finishPending"] = true;
        next["endTime"] = now * 1000;
        next["status"] = "Saving workout";
        if (next.get("queue").size() > 0) { effects.add({ "type" => "flushQueue" }); }
        else { effects.add({ "type" => "sendFinish" }); }
        return true;
    }

    function beginDiscard(next, model, message, effects) {
        if (model.get("workout") == null) { return false; }
        if (model.get("demo") == true) {
            returnFromDemo(next, model, effects);
            return true;
        }
        next["phase"] = "discarding";
        if (message.get("requestBusy") == true) {
            next["discardPending"] = true;
            next["status"] = "Waiting for sync to discard";
        } else {
            next["discardPending"] = false;
            next["status"] = "Discarding workout";
            effects.add({ "type" => "sendDiscard" });
        }
        return true;
    }

    function undoLastSet(next, model, effects) {
        var last = model.get("undo");
        if (last == null || !isActive(model) || isText(model.get("phase"), "finishing")) { return false; }
        var entryIndex = last.get("entryIndex");
        var setIndex = last.get("setIndex");
        setCompletedValue(next, entryIndex, setIndex, null, null, true);
        if (model.get("demo") != true) {
            appendQueue(next, { "kind" => "set", "entryId" => last.get("entryId"), "setId" => last.get("setId"), "completed" => null });
        }
        next["entryIndex"] = entryIndex;
        next["setIndex"] = setIndex;
        next["activeEntryIndex"] = entryIndex;
        next["phase"] = "working";
        next["restEnd"] = null;
        next["status"] = "Set undone";
        next["undo"] = null;
        next["lastSet"] = false;
        effects.add({ "type" => "stopTicker" });
        if (model.get("demo") != true) { effects.add({ "type" => "flushQueue" }); }
        return true;
    }

    function undoTarget(model) {
        var set = currentSet(model);
        if (set != null && LiftosaurSet.get(set, "completed") != null) {
            return { "entryIndex" => model.get("entryIndex"), "setIndex" => model.get("setIndex") };
        }

        // Prefer the last locally logged set: workout order alone may not
        // match the order in which the user navigated and logged sets.
        var workout = model.get("workout");
        var last = model.get("undo");
        if (workout != null && last != null) {
            var lastEntryIndex = last.get("entryIndex");
            var lastSetIndex = last.get("setIndex");
            var entries = workout.get("entries");
            if (lastEntryIndex != null && lastSetIndex != null && lastEntryIndex >= 0 && lastEntryIndex < entries.size()) {
                var lastEntry = entries[lastEntryIndex];
                var sets = lastEntry.get("sets");
                if (lastSetIndex >= 0 && lastSetIndex < sets.size() && LiftosaurSet.get(sets[lastSetIndex], "completed") != null) {
                    return { "entryIndex" => lastEntryIndex, "setIndex" => lastSetIndex };
                }
            }
        }

        // A server-loaded workout may not have a local undo record. If every
        // set is complete, the cursor sits after the final entry.
        var phase = model.get("phase");
        if (workout == null || (!isText(phase, "complete") && !isText(phase, "actions") && !isText(phase, "confirm-undo"))) { return null; }
        var entries = workout.get("entries");
        for (var i = entries.size() - 1; i >= 0; i -= 1) {
            var sets = entries[i].get("sets");
            for (var j = sets.size() - 1; j >= 0; j -= 1) {
                if (LiftosaurSet.get(sets[j], "completed") != null) {
                    return { "entryIndex" => i, "setIndex" => j };
                }
            }
        }
        return null;
    }

    function beginUndoSet(next, model, effects) {
        var target = undoTarget(model);
        if (target == null) { return false; }
        var entryIndex = target.get("entryIndex");
        var setIndex = target.get("setIndex");
        var entry = model.get("workout").get("entries")[entryIndex];
        var set = entry.get("sets")[setIndex];
        if (LiftosaurSet.get(set, "completed") == null) { return false; }

        setCompletedValue(next, entryIndex, setIndex, null, null, true);
        if (model.get("demo") != true) {
            appendQueue(next, {
                "kind" => "set", "entryId" => entry.get("entryId"), "setId" => LiftosaurSet.get(set, "setId"),
                "completed" => null, "entryIndex" => entryIndex, "setIndex" => setIndex, "undo" => true
            });
        }
        next["entryIndex"] = entryIndex;
        next["setIndex"] = setIndex;
        next["activeEntryIndex"] = entryIndex;
        next["phase"] = "working";
        next["restEnd"] = null;
        next["lastSet"] = false;
        next["status"] = "Undoing set";
        var lastUndo = model.get("undo");
        if (lastUndo != null && lastUndo.get("entryIndex") == entryIndex && lastUndo.get("setIndex") == setIndex) {
            next["undo"] = null;
        }
        effects.add({ "type" => "stopTicker" });
        if (model.get("demo") != true) { effects.add({ "type" => "flushQueue" }); }
        return true;
    }

    function currentSet(model) {
        var workout = model.get("workout");
        if (workout == null) { return null; }
        var entries = workout.get("entries");
        var entryIndex = model.get("entryIndex");
        var setIndex = model.get("setIndex");
        if (entryIndex == null || setIndex == null || entryIndex >= entries.size()) { return null; }
        var sets = entries[entryIndex].get("sets");
        return setIndex < sets.size() ? sets[setIndex] : null;
    }

    function isActive(model) {
        var phase = model.get("phase");
        return isText(phase, "working") || isText(phase, "editing") || isText(phase, "rest") ||
            isText(phase, "complete") || isText(phase, "finishing") || isText(phase, "actions") ||
            isText(phase, "confirm-finish") || isText(phase, "confirm-discard") || isText(phase, "confirm-undo") || isText(phase, "discarding");
    }

    function normalizeCursor(model) {
        var workout = model.get("workout");
        if (workout == null) { return; }
        var entries = workout.get("entries");
        var entryIndex = model.get("activeEntryIndex");
        if (entryIndex == null) { entryIndex = model.get("entryIndex"); }
        if (entryIndex == null || entryIndex < 0) { entryIndex = 0; }
        while (entryIndex < entries.size()) {
            var sets = entries[entryIndex].get("sets");
            for (var setIndex = 0; setIndex < sets.size(); setIndex += 1) {
                if (LiftosaurSet.get(sets[setIndex], "completed") == null) {
                    model["activeEntryIndex"] = entryIndex;
                    model["entryIndex"] = entryIndex;
                    model["setIndex"] = setIndex;
                    return;
                }
            }
            entryIndex += 1;
        }
        model["phase"] = "complete";
        model["entryIndex"] = entries.size();
        model["setIndex"] = 0;
    }

    function setError(model, code) {
        model["phase"] = "error";
        if (code == 401) { model["status"] = "Check API key in Connect IQ settings"; }
        else if (code == 403) { model["status"] = "Liftosaur Premium is required"; }
        else if (code <= 0) { model["status"] = "No connection - try again"; }
        else { model["status"] = "Liftosaur request failed: " + code.toString(); }
    }

    function beginEdit(model, set) {
        var completed = LiftosaurSet.get(set, "completed");
        var reps = completed != null && LiftosaurSet.doneGet(completed, "reps") != null ? LiftosaurSet.doneGet(completed, "reps") : LiftosaurSet.get(set, "reps");
        model["editReps"] = reps == null ? 1 : reps;
        model["editWeight"] = completed != null && LiftosaurSet.doneGet(completed, "weight") != null ? LiftosaurSet.doneGet(completed, "weight") : LiftosaurSet.get(set, "weight");
        model["editField"] = "reps";
        model["editAmrap"] = LiftosaurSet.get(set, "isAmrap") == true;
        model["editCompleted"] = completed != null;
        model["editEntryIndex"] = model.get("entryIndex");
        model["editSetIndex"] = model.get("setIndex");
        model["editSetId"] = LiftosaurSet.get(set, "setId");
        model["phase"] = "editing";
        model["status"] = completed != null ? "Correct logged reps" : "";
    }

    function update(model, message, now) {
        var next = copyModel(model);
        var effects = [];
        var changed = false;
        var phase = model.get("phase");
        var type = message.get("type");

        if (isText(type, "SELECT")) {
            if (isText(phase, "preview")) {
                effects.add({ "type" => "startWorkout" });
            } else if (isText(phase, "editing")) {
                changed = saveEditedSet(next, model, now, effects);
            } else if (isText(phase, "rest")) {
                var nextSet = currentSet(model);
                var activeRestSet = nextActiveSet(model);
                var viewingActiveRestSet = activeRestSet != null &&
                    activeRestSet.get("entryIndex") == model.get("entryIndex") &&
                    activeRestSet.get("setIndex") == model.get("setIndex");
                if (viewingActiveRestSet && nextSet != null && LiftosaurSet.get(nextSet, "isAmrap") == true) {
                    next["restEnd"] = null;
                    next["phase"] = "working";
                    next["status"] = "Rest skipped";
                    beginEdit(next, nextSet);
                    effects.add({ "type" => "stopTicker" });
                    changed = true;
                }
            } else if (isText(phase, "working")) {
                var set = currentSet(model);
                if (set != null && LiftosaurSet.get(set, "completed") != null) {
                    next["status"] = "Set already logged";
                    changed = true;
                } else if (set != null && !isFirstIncompleteSet(model, model.get("entryIndex"), model.get("setIndex"))) {
                    next["status"] = "Complete earlier sets first";
                    changed = true;
                } else if (set != null && LiftosaurSet.get(set, "isAmrap") == true) {
                    beginEdit(next, set);
                    changed = true;
                } else if (set != null) {
                    changed = logSet(next, model, now, effects);
                }
            } else if (isText(phase, "complete")) {
                changed = beginFinish(next, model, now, effects);
            } else if (isText(phase, "actions")) {
                var undoTargetExists = undoTarget(model) != null;
                if (model.get("selectedAction") == 0) {
                    cancelOverlay(next, model, now);
                    effects.add({ "type" => "exitApp" });
                    changed = true;
                } else if (undoTargetExists && model.get("selectedAction") == 2) {
                    next["phase"] = "confirm-undo";
                    next["status"] = "Confirm undo set";
                    changed = true;
                } else if (model.get("selectedAction") == (undoTargetExists ? 3 : 2)) {
                    next["phase"] = "confirm-discard";
                    next["status"] = "This permanently deletes this workout";
                    changed = true;
                } else {
                    next["phase"] = "confirm-finish";
                    next["status"] = "Press SELECT to finish workout";
                    changed = true;
                }
            } else if (isText(phase, "confirm-finish")) {
                changed = beginFinish(next, model, now, effects);
            } else if (isText(phase, "confirm-discard")) {
                changed = beginDiscard(next, model, message, effects);
            } else if (isText(phase, "confirm-undo")) {
                changed = beginUndoSet(next, model, effects);
            }
        } else if (isText(type, "LONG_START")) {
            if (isText(phase, "preview")) {
                changed = beginDemo(next, model);
            } else if (isText(phase, "working")) {
                var editSet = currentSet(model);
                if (editSet != null) {
                    var editCompleted = LiftosaurSet.get(editSet, "completed") != null;
                    if (editCompleted || isFirstIncompleteSet(model, model.get("entryIndex"), model.get("setIndex"))) {
                        beginEdit(next, editSet);
                    } else {
                        next["status"] = "Complete earlier sets first";
                    }
                    changed = true;
                }
            } else if (isText(phase, "editing")) {
                changed = saveEditedSet(next, model, now, effects);
            }
        } else if (isText(type, "LONG_NAV")) {
            var navDirection = message.get("direction");
            if (isText(phase, "working") || isText(phase, "rest") || isText(phase, "complete")) {
                changed = moveExercise(next, model, navDirection);
            }
        } else if (isText(type, "BACK")) {
            if (isText(phase, "preview") || isText(phase, "loading") || isText(phase, "error")) {
                effects.add({ "type" => "exitApp" });
                changed = true;
            } else if (isText(phase, "working")) {
                var activeSet = nextActiveSet(model);
                if (activeSet != null && (activeSet.get("entryIndex") != model.get("entryIndex") || activeSet.get("setIndex") != model.get("setIndex"))) {
                    next["entryIndex"] = activeSet.get("entryIndex");
                    next["setIndex"] = activeSet.get("setIndex");
                    next["status"] = "";
                } else {
                    next["phase"] = "actions";
                    next["selectedAction"] = 0;
                }
                changed = true;
            } else if (isText(phase, "complete")) {
                next["phase"] = "actions";
                next["selectedAction"] = 0;
                changed = true;
            } else if (isText(phase, "rest")) {
                var restNextSet = nextActiveSet(model);
                if (restNextSet != null &&
                    (restNextSet.get("entryIndex") != model.get("entryIndex") || restNextSet.get("setIndex") != model.get("setIndex"))) {
                    next["entryIndex"] = restNextSet.get("entryIndex");
                    next["setIndex"] = restNextSet.get("setIndex");
                    next["status"] = "";
                } else {
                    next["restEnd"] = null;
                    next["phase"] = model.get("lastSet") == true ? "complete" : "working";
                    next["status"] = "Rest skipped";
                    effects.add({ "type" => "stopTicker" });
                }
                changed = true;
            } else if (isText(phase, "editing")) {
                next["phase"] = "working";
                next["editCompleted"] = false;
                next["editEntryIndex"] = null;
                next["editSetIndex"] = null;
                next["editSetId"] = null;
                next["status"] = "";
                changed = true;
            } else if (isText(phase, "actions")) {
                cancelOverlay(next, model, now);
                changed = true;
            } else if (isText(phase, "confirm-finish") || isText(phase, "confirm-discard")) {
                cancelOverlay(next, model, now);
                changed = true;
            } else if (isText(phase, "confirm-undo")) {
                next["phase"] = "actions";
                changed = true;
            } else {
                changed = undoLastSet(next, model, effects);
            }
        } else if (isText(type, "MENU")) {
            if (isText(phase, "working") || isText(phase, "rest")) {
                next["phase"] = "actions";
                next["selectedAction"] = 0;
                changed = true;
            } else if (isText(phase, "actions") || isText(phase, "confirm-finish") || isText(phase, "confirm-discard")) {
                cancelOverlay(next, model, now);
                changed = true;
            } else if (isText(phase, "confirm-undo")) {
                next["phase"] = "actions";
                changed = true;
            } else if (isText(phase, "complete")) {
                next["phase"] = "confirm-finish";
                next["status"] = "Press SELECT to finish early";
                changed = true;
            }
        } else if (isText(type, "ADJUST")) {
            var direction = message.get("direction");
            if (isText(phase, "actions")) {
                var maxAction = undoTarget(model) != null ? 3 : 2;
                var selectedAction = model.get("selectedAction") + direction;
                if (selectedAction < 0) { selectedAction = maxAction; }
                if (selectedAction > maxAction) { selectedAction = 0; }
                next["selectedAction"] = selectedAction;
                changed = true;
            } else if (isText(phase, "working") || isText(phase, "rest") || isText(phase, "complete")) {
                changed = moveSet(next, model, direction);
            } else if (isText(phase, "editing")) {
                if (isText(model.get("editField"), "weight")) {
                    changed = adjustEditedWeight(next, model, direction);
                } else {
                    var newReps = model.get("editReps") - direction;
                    next["editReps"] = newReps < 1 ? 1 : newReps;
                    changed = true;
                }
            }
        } else if (isText(type, "TOGGLE_EDIT_FIELD")) {
            if (isText(phase, "editing") && model.get("editAmrap") != true) {
                next["editField"] = isText(model.get("editField"), "reps") ? "weight" : "reps";
                changed = true;
            }
        } else if (isText(type, "CURRENT_REQUEST")) {
            next["status"] = "Checking workout";
            changed = true;
        } else if (isText(type, "LOAD_NEXT")) {
            next["phase"] = "loading";
            next["status"] = "Loading next workout";
            changed = true;
        } else if (isText(type, "START_REQUEST")) {
            next["status"] = "Starting workout";
            // The preview's full set list is no longer needed once its start
            // parameters have been copied into the HTTP request body.
            next["workout"] = null;
            changed = true;
        } else if (isText(type, "NO_API_KEY")) {
            next["phase"] = "error";
            next["status"] = "Missing API key\ncheck Connect IQ settings";
            changed = true;
        } else if (isText(type, "UNSUPPORTED_WORKOUT")) {
            next["phase"] = "error";
            next["status"] = "This workout has set types not supported in v1";
            changed = true;
        } else if (isText(type, "CURRENT_RESULT")) {
            var code = message.get("code");
            var workout = message.get("workout");
            if (code == 200) {
                if (workout != null) {
                    var savedPhase = phase;
                    var viewedSet = currentSet(model);
                    var preserveViewedSet = viewedSet != null && LiftosaurSet.get(viewedSet, "completed") != null;
                    next["workout"] = workout;
                    if (next.get("activeEntryIndex") == null) {
                        var savedEntryIndex = model.get("entryIndex");
                        next["activeEntryIndex"] = savedEntryIndex != null && savedEntryIndex < workout.get("entries").size() ? savedEntryIndex : 0;
                    }
                    next["startedAt"] = workout.get("startTime");
                    next["status"] = "";
                    if (!isActive(model)) { next["phase"] = "working"; }
                    if (!preserveViewedSet) { normalizeCursor(next); }
                    if (model.get("finishPending") == true) {
                        next["phase"] = "finishing";
                    } else if (isText(savedPhase, "rest") || isText(savedPhase, "editing") ||
                        isText(savedPhase, "actions") || isText(savedPhase, "confirm-finish") ||
                        isText(savedPhase, "confirm-discard") || isText(savedPhase, "confirm-undo")) {
                        if (!isText(savedPhase, "editing") || currentSet(next) != null) { next["phase"] = savedPhase; }
                    } else if (isText(savedPhase, "discarding")) {
                        next["phase"] = "confirm-discard";
                        next["status"] = "Tap START to retry discard";
                    }
                    if (model.get("discardPending") == true) {
                        next["discardPending"] = false;
                        effects.add({ "type" => "sendDiscard" });
                    } else if (model.get("finishPending") == true && next.get("queue").size() == 0) {
                        effects.add({ "type" => "sendFinish" });
                    } else if (next.get("queue").size() > 0) {
                        effects.add({ "type" => "flushQueue" });
                    }
                } else if (model.get("finishPending") == true) {
                    next["phase"] = "loading";
                    next["workout"] = null;
                    next["status"] = "Workout saved";
                    next["queue"] = [];
                    effects.add({ "type" => "stopTicker" });
                    effects.add({ "type" => "loadNext" });
                } else if (isText(phase, "discarding") || isText(phase, "confirm-discard") || model.get("discardPending") == true) {
                    // A successful current-workout lookup with no workout
                    // confirms that a pending discard already took effect.
                    next = { "phase" => "loading", "queue" => [], "status" => "Workout discarded" };
                    effects.add({ "type" => "stopTicker" });
                    effects.add({ "type" => "exitApp" });
                } else {
                    // The server is authoritative when it returns HTTP 200
                    // with no current workout. Drop stale local sets and
                    // queued writes that can no longer be applied.
                    next = { "phase" => "loading", "queue" => [], "status" => "" };
                    effects.add({ "type" => "stopTicker" });
                    effects.add({ "type" => "loadNext" });
                }
            } else if (isActive(model)) {
                next["status"] = "Offline - workout is saved on the watch";
            } else {
                setError(next, code);
            }
            changed = true;
        } else if (isText(type, "NEXT_RESULT")) {
            var nextCode = message.get("code");
            var nextWorkout = message.get("workout");
            if (nextCode == 200 && nextWorkout != null) {
                next = { "phase" => "preview", "workout" => nextWorkout, "queue" => [], "status" => "" };
            } else {
                setError(next, nextCode);
            }
            changed = true;
        } else if (isText(type, "START_RESULT")) {
            var startCode = message.get("code");
            var startedWorkout = message.get("workout");
            if (startCode == 200 && startedWorkout != null) {
                next["workout"] = startedWorkout;
                next["phase"] = "working";
                next["startedAt"] = startedWorkout.get("startTime");
                next["entryIndex"] = 0;
                next["setIndex"] = 0;
                next["activeEntryIndex"] = 0;
                next["undo"] = null;
                next["queue"] = [];
                next["status"] = "";
                normalizeCursor(next);
                effects.add({ "type" => "startTicker" });
            } else {
                setError(next, startCode);
            }
            changed = true;
        } else if (isText(type, "SET_RESULT")) {
            var setCode = message.get("code");
            var updatedWorkout = message.get("workout");
            if (setCode != 200) {
                next["status"] = setCode <= 0 ? "Offline - set saved on watch" : "Set not accepted - check supported set types";
                if (model.get("discardPending") == true) {
                    next["discardPending"] = false;
                    effects.add({ "type" => "sendDiscard" });
                }
            } else {
                var queue = copyArray(model.get("queue"));
                var syncedAction = queue.size() > 0 ? queue[0] : null;
                var isCorrection = syncedAction != null && syncedAction.get("correction") == true;
                var isUndo = syncedAction != null && syncedAction.get("undo") == true;
                var savedPhase = phase;
                var viewedSet = currentSet(model);
                var preserveViewedSet = isText(savedPhase, "working") && viewedSet != null && LiftosaurSet.get(viewedSet, "completed") != null;
                var preserveEditor = isText(savedPhase, "editing");
                // The store may omit the response workout to save memory. Local
                // set logs, corrections, and undo changes are already applied.
                if (updatedWorkout != null) { next["workout"] = updatedWorkout; }
                if (isCorrection && syncedAction != null && !preserveEditor) {
                    next["entryIndex"] = syncedAction.get("entryIndex");
                    next["setIndex"] = syncedAction.get("setIndex");
                    next["activeEntryIndex"] = syncedAction.get("entryIndex");
                    next["phase"] = "working";
                } else if (isUndo && syncedAction != null && !preserveEditor) {
                    next["entryIndex"] = syncedAction.get("entryIndex");
                    next["setIndex"] = syncedAction.get("setIndex");
                    next["activeEntryIndex"] = syncedAction.get("entryIndex");
                    next["phase"] = "working";
                } else if (!preserveViewedSet && !preserveEditor) {
                    normalizeCursor(next);
                    if (isText(savedPhase, "rest")) { next["phase"] = "rest"; }
                }
                if (queue.size() > 0) { queue.remove(queue[0]); }
                next["queue"] = queue;
                if (queue.size() == 0) { next["status"] = isCorrection ? "Reps corrected" : (isUndo ? "Set undone" : ""); }
                if (model.get("discardPending") == true) {
                    next["discardPending"] = false;
                    effects.add({ "type" => "sendDiscard" });
                } else if (queue.size() > 0) {
                    effects.add({ "type" => "flushQueue" });
                } else if (model.get("finishPending") == true) {
                    effects.add({ "type" => "sendFinish" });
                }
            }
            changed = true;
        } else if (isText(type, "FINISH_RESULT")) {
            var finishCode = message.get("code");
            if (finishCode == 200) {
                next = { "phase" => "loading", "queue" => [], "status" => "Workout saved" };
                effects.add({ "type" => "stopTicker" });
                effects.add({ "type" => "loadNext" });
            } else {
                next["phase"] = "finishing";
                next["status"] = "Offline - finish will sync when connected";
            }
            changed = true;
        } else if (isText(type, "DISCARD_RESULT")) {
            var discardCode = message.get("code");
            // DELETE endpoints may report either 200 or 204 for success.
            if (discardCode >= 200 && discardCode < 300) {
                next = { "phase" => "loading", "queue" => [], "status" => "Workout discarded" };
                effects.add({ "type" => "stopTicker" });
                effects.add({ "type" => "exitApp" });
            } else {
                next["discardPending"] = false;
                next["phase"] = "confirm-discard";
                next["status"] = discardCode <= 0 ? "Offline - discard not sent" : "Discard failed: " + discardCode.toString();
            }
            changed = true;
        } else if (isText(type, "DISCARD_LOCAL_ERROR")) {
            next["discardPending"] = false;
            next["phase"] = "confirm-discard";
            next["status"] = "Cannot discard: start time is missing";
            changed = true;
        } else if (isText(type, "REST_EXPIRED") && isText(phase, "rest")) {
            if (model.get("demo") == true && model.get("lastSet") == true) {
                returnFromDemo(next, model, effects);
            } else {
                next["restEnd"] = null;
                next["phase"] = model.get("lastSet") == true ? "complete" : "working";
                next["status"] = "";
                effects.add({ "type" => "stopTicker" });
                effects.add({ "type" => "vibrate" });
            }
            changed = true;
        }

        return result(next, effects, changed);
    }

    function cancelOverlay(next, model, now) {
        var restEnd = model.get("restEnd");
        next["phase"] = restEnd != null && restEnd > now ? "rest" : (model.get("lastSet") == true ? "complete" : "working");
        next["status"] = "";
    }
}
