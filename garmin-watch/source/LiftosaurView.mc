using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.WatchUi;

class LiftosaurView extends WatchUi.View {
    var _store;

    function initialize(store) {
        View.initialize();
        _store = store;
    }

    function isText(value, expected) {
        return value != null && value.equals(expected);
    }

    function onUpdate(dc) {
        var state = _store.state;
        var phase = state.get("phase");
        var phaseText = phase == null ? "" : phase.toString();
        try {
            drawState(dc, state, phaseText);
        } catch (ex) {
            System.println("[Liftosaur] ERROR drawing screen");
            ex.printStackTrace();
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
            line(dc, 78, "DRAW ERROR", Graphics.FONT_MEDIUM);
        }
    }

    function drawState(dc, state, phase) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        if (_store.isStarting()) {
            drawAppStarting(dc);
        } else if (phase.equals("preview")) {
            drawPreview(dc, state);
        } else if (isText(phase, "working")) {
            drawWorking(dc, state);
        } else if (isText(phase, "editing")) {
            drawEdit(dc, state);
        } else if (isText(phase, "rest")) {
            drawRest(dc, state);
        } else if (isText(phase, "actions")) {
            drawActions(dc, state);
        } else if (isText(phase, "confirm-discard")) {
            drawDiscardConfirmation(dc, state);
        } else if (isText(phase, "confirm-undo")) {
            drawUndoConfirmation(dc, state);
        } else if (isText(phase, "discarding")) {
            line(dc, 78, "DISCARDING", Graphics.FONT_MEDIUM);
            line(dc, 118, statusText(state), Graphics.FONT_SMALL);
        } else if (isText(phase, "complete") || isText(phase, "confirm-finish")) {
            drawComplete(dc, state);
        } else if (isText(phase, "error")) {
            line(dc, 62, "CONNECTION ERROR", Graphics.FONT_SMALL);
            line(dc, 101, statusText(state), Graphics.FONT_XTINY);
        } else if (isText(phase, "finishing")) {
            line(dc, 78, "SAVING", Graphics.FONT_MEDIUM);
            line(dc, 118, statusText(state), Graphics.FONT_SMALL);
        } else {
            line(dc, 78, "LIFTOSAUR", Graphics.FONT_MEDIUM);
            line(dc, 120, statusText(state), Graphics.FONT_SMALL);
        }
        if (state.get("demo") == true) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_BLACK);
            line(dc, 2, "DEMO", Graphics.FONT_XTINY);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        }
    }

    function drawAppStarting(dc) {
        var centerY = dc.getHeight() / 2;
        line(dc, centerY - 18, "LIFTOSAUR", Graphics.FONT_MEDIUM);
        line(dc, centerY + 18, "STARTING", Graphics.FONT_SMALL);
    }

    function drawPreview(dc, state) {
        if (isText(state.get("status"), "Starting workout")) {
            drawStarting(dc);
            return;
        }
        var workout = state.get("workout");
        var name = workout.get("dayName").toString();
        var font = Graphics.FONT_SMALL;
        var lines = wrapText(dc, name, font, dc.getWidth() - 48);
        var lineHeight = dc.getFontHeight(font) + 6;
        var y = (dc.getHeight() - (lines.size() * lineHeight) - 50) / 2;
        if (y < 24) { y = 24; }
        for (var i = 0; i < lines.size(); i += 1) {
            line(dc, y + (i * lineHeight), lines[i], font);
        }
        line(dc, dc.getHeight() - 75, "PRESS START", Graphics.FONT_SMALL);
        line(dc, dc.getHeight() - 47, "HOLD START: DEMO", Graphics.FONT_XTINY);
    }

    function drawStarting(dc) {
        var centerX = dc.getWidth() / 2;
        var top = 70;
        var waist = top + 18;
        var bottom = top + 38;

        // Draw a small hourglass with the graphics API so it works on the
        // fenix 5 without relying on a font-specific Unicode symbol.
        dc.drawLine(centerX - 12, top, centerX + 12, top);
        dc.drawLine(centerX - 12, top, centerX - 3, waist);
        dc.drawLine(centerX + 12, top, centerX + 3, waist);
        dc.drawLine(centerX - 3, waist, centerX + 3, waist);
        dc.drawLine(centerX - 3, waist, centerX - 12, bottom);
        dc.drawLine(centerX + 3, waist, centerX + 12, bottom);
        dc.drawLine(centerX - 12, bottom, centerX + 12, bottom);
        dc.drawLine(centerX - 4, top + 9, centerX + 4, top + 9);
        dc.drawLine(centerX - 2, waist + 9, centerX + 2, waist + 9);

        line(dc, top + 60, "STARTING WORKOUT", Graphics.FONT_SMALL);
        line(dc, top + 88, "PLEASE WAIT", Graphics.FONT_XTINY);
    }

    function wrapText(dc, text, font, maxWidth) {
        var lines = [];
        var currentLine = "";
        var word = "";
        var chars = text.toCharArray();
        for (var i = 0; i < chars.size(); i += 1) {
            var character = chars[i].toString();
            var hyphenSeparator = character.equals("-") && i > 0 && i < chars.size() - 1 && chars[i - 1].toString().equals(" ") && chars[i + 1].toString().equals(" ");
            if (hyphenSeparator) {
                if (word.length() > 0) {
                    var candidate = currentLine.length() == 0 ? word : currentLine + " " + word;
                    if (currentLine.length() > 0 && dc.getTextWidthInPixels(candidate, font) > maxWidth) {
                        lines.add(currentLine);
                        currentLine = word;
                    } else {
                        currentLine = candidate;
                    }
                    word = "";
                }
                if (currentLine.length() > 0) { lines.add(currentLine); }
                currentLine = "";
            } else if (character.equals(" ")) {
                if (word.length() > 0) {
                    var candidate = currentLine.length() == 0 ? word : currentLine + " " + word;
                    if (currentLine.length() > 0 && dc.getTextWidthInPixels(candidate, font) > maxWidth) {
                        lines.add(currentLine);
                        currentLine = word;
                    } else {
                        currentLine = candidate;
                    }
                    word = "";
                }
            } else {
                word += character;
            }
        }
        if (word.length() > 0) {
            var candidate = currentLine.length() == 0 ? word : currentLine + " " + word;
            if (currentLine.length() > 0 && dc.getTextWidthInPixels(candidate, font) > maxWidth) {
                lines.add(currentLine);
                currentLine = word;
            } else {
                currentLine = candidate;
            }
        }
        if (currentLine.length() > 0) { lines.add(currentLine); }
        return lines;
    }

    function drawWorking(dc, state) {
        var entry = _store.currentEntry();
        var set = _store.currentSet();
        if (entry == null || set == null) {
            line(dc, 85, "Workout complete", Graphics.FONT_MEDIUM);
            line(dc, 133, "SELECT  FINISH", Graphics.FONT_SMALL);
            return;
        }
        var activeEntryIndex = state.get("activeEntryIndex");
        if (activeEntryIndex == null) { activeEntryIndex = state.get("entryIndex"); }
        var nextSet = state.get("entryIndex") == activeEntryIndex && isNextSet(entry, set);
        drawSetDetails(dc, entry, set, nextSet, false, 196);
    }

    function drawSetDetails(dc, entry, set, highlight, resting, progressY) {
        var nameY = 22;
        var setY = 54;
        var repsY = 84;
        var extraY = 145;
        dc.setColor(highlight ? Graphics.COLOR_BLUE : Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        var setPosition = currentSetNumber(entry, set);
        var setLabel = "SET " + setPosition.toString() + " / " + workSetCount(entry).toString();
        if (LiftosaurSet.get(set, "isWarmup") == true) {
            setLabel = "W" + setPosition.toString() + " / " + warmupSetCount(entry).toString();
        }
        line(dc, nameY, setLabel, Graphics.FONT_SMALL);
        line(dc, setY, entry.get("name").toString(), Graphics.FONT_SMALL);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        var completed = LiftosaurSet.get(set, "completed");
        var shownWeight = completed != null && LiftosaurSet.doneGet(completed, "weight") != null ? LiftosaurSet.doneGet(completed, "weight") : LiftosaurSet.get(set, "weight");
        var expectedReps = LiftosaurSet.get(set, "reps");
        var actualReps = completed == null ? null : LiftosaurSet.doneGet(completed, "reps");
        drawSetRepsAndWeight(dc, repsY, set, completed, expectedReps, actualReps, shownWeight);
        drawSetExtra(dc, extraY, set, shownWeight, expectedReps, actualReps, _store.state.get("detailMode"));
        drawSetProgress(dc, entry, set, highlight, progressY - 8, resting);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    }

    function drawSetRepsAndWeight(dc, y, set, completed, expectedReps, actualReps, weight) {
        var shownReps = expectedReps.toString();
        var repsColor = Graphics.COLOR_YELLOW;
        if (actualReps != null) {
            shownReps = actualReps.toString();
            repsColor = actualReps < expectedReps ? Graphics.COLOR_RED : Graphics.COLOR_GREEN;
        } else if (LiftosaurSet.get(set, "isAmrap") == true) {
            shownReps += "+";
        }
        if (LiftosaurSet.get(set, "isUnilateral") == true) {
            var repsLeft = completed == null ? expectedReps : LiftosaurSet.doneGet(completed, "repsLeft");
            if (repsLeft == null) { repsLeft = expectedReps; }
            if (completed == null && LiftosaurSet.get(set, "isAmrap") == true) {
                shownReps = repsLeft.toString() + "+/" + expectedReps.toString() + "+";
            } else {
                shownReps = repsLeft.toString() + "/" + shownReps;
            }
            if (completed != null && repsLeft < expectedReps) { repsColor = Graphics.COLOR_RED; }
        }
        drawRepsAndWeight(dc, y, shownReps, weight, repsColor, 145);
    }

    function drawSetExtra(dc, y, set, weight, expectedReps, actualReps, mode) {
        var text = "";
        if (mode == null || isText(mode, "plates")) {
            var plates = LiftosaurSet.get(set, "plateSummary");
            text = plates == null ? "NO PLATE DATA" : plates.toString();
        } else {
            var reps = actualReps == null ? expectedReps : actualReps;
            if (actualReps != null && LiftosaurSet.get(set, "isUnilateral") == true) {
                var completed = LiftosaurSet.get(set, "completed");
                var repsLeft = LiftosaurSet.doneGet(completed, "repsLeft");
                if (repsLeft != null && repsLeft < reps) { reps = repsLeft; }
            }
            var weightText = weight == null ? "" : weight.toString();
            var chars = weightText.toCharArray();
            var unitStart = chars.size();
            for (var i = 0; i < chars.size(); i += 1) {
                var character = chars[i].toString().toLower();
                if (character.equals("k") || character.equals("l")) {
                    unitStart = i;
                    break;
                }
            }
            if (reps == null || reps <= 0 || unitStart == 0 || unitStart == chars.size()) {
                text = "e1RM UNAVAILABLE";
            } else {
                var unit = weightText.substring(unitStart, chars.size());
                var value = weightText.substring(0, unitStart).toFloat();
                var rounded = Math.round(value * (1.0 + (reps / 30.0)) * 10.0).toString();
                var roundedChars = rounded.toCharArray();
                var wholeEnd = roundedChars.size();
                for (var j = 0; j < roundedChars.size(); j += 1) {
                    if (roundedChars[j].toString().equals(".")) {
                        wholeEnd = j;
                        break;
                    }
                }
                var tenthsText = rounded.substring(0, wholeEnd);
                var wholeText = tenthsText.substring(0, tenthsText.length() - 1);
                if (wholeText.length() == 0) { wholeText = "0"; }
                var decimalText = tenthsText.substring(tenthsText.length() - 1, tenthsText.length());
                text = "e1RM " + wholeText + "." + decimalText + unit;
            }
        }
        var font = Graphics.FONT_MEDIUM;
        if (dc.getTextWidthInPixels(text, font) > dc.getWidth() - 40) {
            font = Graphics.FONT_SMALL;
        }
        if (dc.getTextWidthInPixels(text, font) > dc.getWidth() - 40) {
            font = Graphics.FONT_XTINY;
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(dc.getWidth() / 2, y, font, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawEdit(dc, state) {
        var entry = _store.currentEntry();
        if (entry != null) { line(dc, 38, entry.get("name").toString(), Graphics.FONT_SMALL); }
        if (isText(state.get("editField"), "reps")) {
            if (state.get("editUnilateral") == true) {
                var leftSide = isText(state.get("editSide"), "left");
                var leftCenter = dc.getWidth() / 3;
                var rightCenter = (dc.getWidth() * 2) / 3;
                var activeColor = Graphics.COLOR_YELLOW;
                var inactiveColor = Graphics.COLOR_LT_GRAY;
                dc.setColor(leftSide ? activeColor : inactiveColor, Graphics.COLOR_BLACK);
                dc.drawText(leftCenter, 76, Graphics.FONT_XTINY, "LEFT", Graphics.TEXT_JUSTIFY_CENTER);
                dc.drawText(leftCenter, 111, Graphics.FONT_NUMBER_HOT, state.get("editRepsLeft").toString(), Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(leftSide ? inactiveColor : activeColor, Graphics.COLOR_BLACK);
                dc.drawText(rightCenter, 76, Graphics.FONT_XTINY, "RIGHT", Graphics.TEXT_JUSTIFY_CENTER);
                dc.drawText(rightCenter, 111, Graphics.FONT_NUMBER_HOT, state.get("editReps").toString(), Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            } else {
                line(dc, 88, state.get("editCompleted") == true ? "FIX LOGGED REPS" : "REPS", Graphics.FONT_SMALL);
                line(dc, 125, state.get("editReps").toString(), Graphics.FONT_NUMBER_HOT);
            }
        } else {
            line(dc, 88, "WEIGHT", Graphics.FONT_SMALL);
            drawWeight(dc, 125, state.get("editWeight"));
        }
    }

    function drawRest(dc, state) {
        drawRestRing(dc);
        var entry = _store.currentEntry();
        var set = _store.currentSet();
        if (entry != null && set != null) {
            var activeEntryIndex = state.get("activeEntryIndex");
            if (activeEntryIndex == null) { activeEntryIndex = state.get("entryIndex"); }
            var nextSet = state.get("entryIndex") == activeEntryIndex && isNextSet(entry, set);
            drawSetDetails(dc, entry, set, nextSet, true, 190);
        } else {
            line(dc, 38, "WORKOUT COMPLETE", Graphics.FONT_SMALL);
        }
    }

    function drawRestRing(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var radius = (width < height ? width : height) / 2 - 3;
        var centerX = width / 2;
        var centerY = height / 2;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        drawThickArc(dc, centerX, centerY, radius, 90, 90);

        var total = _store.restDuration();
        var remaining = _store.remainingRest();
        if (total <= 0 || remaining <= 0) { return; }
        var endAngle = remaining >= total ? 90 : 90 - ((360 * remaining) / total);
        while (endAngle < 0) { endAngle += 360; }
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);
        drawThickArc(dc, centerX, centerY, radius, 90, endAngle);
    }

    function drawThickArc(dc, centerX, centerY, radius, startAngle, endAngle) {
        // Dc.drawArc is a one-pixel stroke, so layer nearby radii for a bolder ring.
        for (var inset = 0; inset < 5; inset += 1) {
            dc.drawArc(centerX, centerY, radius - inset, Graphics.ARC_CLOCKWISE, startAngle, endAngle);
        }
    }

    function drawComplete(dc, state) {
        if (isText(state.get("phase"), "confirm-finish")) {
            line(dc, 70, state.get("demo") == true ? "FINISH DEMO?" : "FINISH WORKOUT?", Graphics.FONT_MEDIUM);
            if (state.get("demo") != true) { line(dc, 113, "Completed sets will save", Graphics.FONT_XTINY); }
        } else if (state.get("demo") == true) {
            line(dc, 76, "DEMO", Graphics.FONT_SMALL);
            line(dc, 111, "COMPLETE", Graphics.FONT_MEDIUM);
        } else {
            line(dc, 76, "WORKOUT", Graphics.FONT_SMALL);
            line(dc, 111, "COMPLETE", Graphics.FONT_MEDIUM);
        }
    }

    function drawDiscardConfirmation(dc, state) {
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
        line(dc, 65, state.get("demo") == true ? "CANCEL DEMO?" : "DISCARD WORKOUT?", Graphics.FONT_SMALL);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        line(dc, 108, state.get("demo") == true ? "Demo changes will be lost" : "This cannot be undone", Graphics.FONT_XTINY);
    }

    function drawUndoConfirmation(dc, state) {
        var target = _store.undoTarget();
        if (target == null) {
            line(dc, 120, "NO SET TO UNDO", Graphics.FONT_MEDIUM);
            return;
        }
        var entry = target.get("entry");
        var set = target.get("set");
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
        line(dc, 28, "UNDO?", Graphics.FONT_SMALL);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        line(dc, 65, entry.get("name").toString(), Graphics.FONT_SMALL);
        var setPosition = currentSetNumber(entry, set);
        if (LiftosaurSet.get(set, "isWarmup") == true) {
            line(dc, 99, "W" + setPosition.toString() + " / " + warmupSetCount(entry).toString(), Graphics.FONT_SMALL);
        } else {
            line(dc, 99, "SET " + setPosition.toString() + " / " + workSetCount(entry).toString(), Graphics.FONT_SMALL);
        }
        var completed = LiftosaurSet.get(set, "completed");
        var shownWeight = completed != null && LiftosaurSet.doneGet(completed, "weight") != null ? LiftosaurSet.doneGet(completed, "weight") : LiftosaurSet.get(set, "weight");
        var plannedReps = LiftosaurSet.get(set, "reps").toString();
        if (LiftosaurSet.get(set, "isAmrap") == true) { plannedReps += "+"; }
        drawRepsAndWeight(dc, 132, plannedReps, shownWeight, Graphics.COLOR_YELLOW, 178);
        var actualReps = completed == null ? null : LiftosaurSet.doneGet(completed, "reps");
        if (actualReps != null) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);
            if (LiftosaurSet.get(set, "isUnilateral") == true) {
                var repsLeft = LiftosaurSet.doneGet(completed, "repsLeft");
                line(dc, 178, "L" + (repsLeft == null ? "?" : repsLeft.toString()) + " R" + actualReps.toString(), Graphics.FONT_SMALL);
            } else {
                line(dc, 178, "done " + actualReps.toString(), Graphics.FONT_SMALL);
            }
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        }
    }

    function drawActions(dc, state) {
        var target = _store.undoTarget();
        var hasUndo = target != null;
        var selected = state.get("selectedAction");
        line(dc, 38, state.get("demo") == true ? "DEMO OPTIONS" : "WORKOUT OPTIONS", Graphics.FONT_XTINY);
        var leaveLabel = state.get("demo") == true ? "EXIT DEMO" : "LEAVE / KEEP";
        line(dc, 78, selected == 0 ? "> " + leaveLabel : leaveLabel, Graphics.FONT_XTINY);
        var finishLabel = state.get("demo") == true ? "FINISH DEMO" : "FINISH WORKOUT";
        line(dc, 108, selected == 1 ? "> " + finishLabel : finishLabel, Graphics.FONT_XTINY);
        if (hasUndo) {
            var undoLabel = target.get("selected") == true ? "UNDO THIS SET" : "UNDO LAST SET";
            line(dc, 138, selected == 2 ? "> " + undoLabel : undoLabel, Graphics.FONT_XTINY);
        }
        var discardIndex = hasUndo ? 3 : 2;
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
        var discardLabel = state.get("demo") == true ? "CANCEL DEMO" : "DISCARD WORKOUT";
        line(dc, 168, selected == discardIndex ? "> " + discardLabel : discardLabel, Graphics.FONT_XTINY);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    }

    function workSetCount(entry) {
        var sets = entry.get("sets");
        var count = 0;
        for (var i = 0; i < sets.size(); i += 1) {
            if (LiftosaurSet.get(sets[i], "isWarmup") != true) { count += 1; }
        }
        return count;
    }

    function warmupSetCount(entry) {
        var sets = entry.get("sets");
        var count = 0;
        for (var i = 0; i < sets.size(); i += 1) {
            if (LiftosaurSet.get(sets[i], "isWarmup") == true) { count += 1; }
        }
        return count;
    }

    function currentSetNumber(entry, currentSet) {
        var sets = entry.get("sets");
        var count = 0;
        var warmup = LiftosaurSet.get(currentSet, "isWarmup") == true;
        for (var i = 0; i < sets.size(); i += 1) {
            if ((LiftosaurSet.get(sets[i], "isWarmup") == true) == warmup) {
                count += 1;
                if (LiftosaurSet.get(sets[i], "setId") == LiftosaurSet.get(currentSet, "setId")) { return count; }
            }
        }
        return count;
    }

    function isNextSet(entry, set) {
        if (set == null) { return false; }
        var sets = entry.get("sets");
        for (var i = 0; i < sets.size(); i += 1) {
            if (LiftosaurSet.get(sets[i], "completed") == null) {
                return LiftosaurSet.get(sets[i], "setId") == LiftosaurSet.get(set, "setId");
            }
        }
        return false;
    }

    function drawSetProgress(dc, entry, currentSet, nextSet, centerY, resting) {
        var sets = entry.get("sets");
        var count = sets.size();
        if (count == 0) { return; }
        var spacing = count > 1 ? (dc.getWidth() - 40) / (count - 1) : 0;
        if (spacing > 18) { spacing = 18; }
        var startX = (dc.getWidth() - ((count - 1) * spacing)) / 2;
        var index = 0;
        for (var i = 0; i < sets.size(); i += 1) {
            var set = sets[i];
            var x = startX + (index * spacing);
            var selected = LiftosaurSet.get(set, "setId") == LiftosaurSet.get(currentSet, "setId");
            var completed = LiftosaurSet.get(set, "completed") != null;
            var warmup = LiftosaurSet.get(set, "isWarmup") == true;
            if (completed) {
                var result = LiftosaurSet.get(set, "completed");
                var actualReps = LiftosaurSet.doneGet(result, "reps");
                var expectedReps = LiftosaurSet.get(set, "reps");
                var missed = actualReps != null && actualReps < expectedReps;
                dc.setColor(missed ? Graphics.COLOR_RED : Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);
                if (missed) {
                    dc.drawLine(x - 3, centerY - 3, x + 3, centerY + 3);
                    dc.drawLine(x + 3, centerY - 3, x - 3, centerY + 3);
                } else {
                    dc.drawLine(x - 4, centerY, x - 1, centerY + 3);
                    dc.drawLine(x - 1, centerY + 3, x + 5, centerY - 4);
                }
                if (selected) {
                    dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLACK);
                    if (warmup) { dc.drawRectangle(x - 7, centerY - 7, 14, 14); }
                    else { dc.drawCircle(x, centerY, 7); }
                }
            } else if (selected) {
                if (nextSet) {
                    dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLACK);
                    if (warmup) { dc.fillRectangle(x - 4, centerY - 4, 9, 9); }
                    else { dc.fillCircle(x, centerY, 5); }
                } else if (resting) {
                    dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLACK);
                    if (warmup) { dc.drawRectangle(x - 5, centerY - 5, 11, 11); }
                    else { dc.drawCircle(x, centerY, 5); }
                } else {
                    dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLACK);
                    if (warmup) { dc.fillRectangle(x - 4, centerY - 4, 9, 9); }
                    else { dc.fillCircle(x, centerY, 5); }
                }
            } else {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
                if (warmup) { dc.drawRectangle(x - 4, centerY - 4, 9, 9); }
                else { dc.drawCircle(x, centerY, 4); }
            }
            index += 1;
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    }

    function drawWeight(dc, y, weight) {
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_BLACK);
        if (weight == null) {
            dc.drawText(dc.getWidth() / 2, y, Graphics.FONT_MEDIUM, "BW", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            return;
        }
        var text = weight.toString();
        var chars = text.toCharArray();
        var unitStart = chars.size();
        for (var i = 0; i < chars.size(); i += 1) {
            var character = chars[i].toString().toLower();
            if (character.equals("k") || character.equals("l")) {
                unitStart = i;
                break;
            }
        }
        var number = text.substring(0, unitStart);
        var unit = text.substring(unitStart, chars.size());
        var numberWidth = dc.getTextWidthInPixels(number, Graphics.FONT_NUMBER_MEDIUM);
        var unitWidth = dc.getTextWidthInPixels(unit, Graphics.FONT_SMALL);
        var x = (dc.getWidth() - numberWidth - 6 - unitWidth) / 2;
        dc.drawText(x, y, Graphics.FONT_NUMBER_MEDIUM, number, Graphics.TEXT_JUSTIFY_LEFT);
        if (unit.length() > 0) {
            dc.drawText(x + numberWidth + 6, y, Graphics.FONT_SMALL, unit, Graphics.TEXT_JUSTIFY_LEFT);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    }

    function drawRepsAndWeight(dc, y, reps, weight, color, bottomLimit) {
        var weightNumber = "BW";
        var unit = "";
        if (weight != null) {
            var text = weight.toString();
            var chars = text.toCharArray();
            var unitStart = chars.size();
            for (var i = 0; i < chars.size(); i += 1) {
                var character = chars[i].toString().toLower();
                if (character.equals("k") || character.equals("l")) {
                    unitStart = i;
                    break;
                }
            }
            weightNumber = text.substring(0, unitStart);
            unit = text.substring(unitStart, chars.size());
        }

        var numberFont = Graphics.FONT_NUMBER_HOT;
        var multiplyFont = Graphics.FONT_MEDIUM;
        var repsWidth = dc.getTextWidthInPixels(reps, numberFont);
        var weightWidth = dc.getTextWidthInPixels(weightNumber, numberFont);
        var unitWidth = dc.getTextWidthInPixels(unit, Graphics.FONT_SMALL);
        var multiplyWidth = dc.getTextWidthInPixels("x", multiplyFont);
        var numberHeight = dc.getFontHeight(numberFont);
        var multiplyHeight = dc.getFontHeight(multiplyFont);
        var multiplyY = y + ((numberHeight - multiplyHeight) / 2);
        var gap = 4;
        var unitGap = unit.length() > 0 ? gap : 0;
        var totalWidth = repsWidth + gap + multiplyWidth + gap + weightWidth + unitGap + unitWidth;
        if (totalWidth > dc.getWidth() - 36 || numberHeight > bottomLimit - y - 4) {
            numberFont = Graphics.FONT_NUMBER_MEDIUM;
            multiplyFont = Graphics.FONT_SMALL;
            repsWidth = dc.getTextWidthInPixels(reps, numberFont);
            weightWidth = dc.getTextWidthInPixels(weightNumber, numberFont);
            multiplyWidth = dc.getTextWidthInPixels("x", multiplyFont);
            numberHeight = dc.getFontHeight(numberFont);
            multiplyHeight = dc.getFontHeight(multiplyFont);
            multiplyY = y + ((numberHeight - multiplyHeight) / 2);
            totalWidth = repsWidth + gap + multiplyWidth + gap + weightWidth + unitGap + unitWidth;
        }
        var x = (dc.getWidth() - totalWidth) / 2;
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.drawText(x, y, numberFont, reps, Graphics.TEXT_JUSTIFY_LEFT);
        var multiplyX = x + repsWidth + gap;
        dc.drawText(multiplyX, multiplyY, multiplyFont, "x", Graphics.TEXT_JUSTIFY_LEFT);
        var suffixX = multiplyX + multiplyWidth + gap;
        dc.drawText(suffixX, y, numberFont, weightNumber, Graphics.TEXT_JUSTIFY_LEFT);
        suffixX += weightWidth + unitGap;
        if (unit.length() > 0) {
            var unitY = y + numberHeight - dc.getFontHeight(Graphics.FONT_SMALL);
            dc.drawText(suffixX, unitY, Graphics.FONT_SMALL, unit, Graphics.TEXT_JUSTIFY_LEFT);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    }

    function statusText(state) {
        var text = state.get("status");
        return text == null ? "" : text.toString();
    }

    function formatTime(seconds) {
        var minutes = seconds / 60;
        var remainder = seconds % 60;
        var secondsText = remainder < 10 ? "0" + remainder.toString() : remainder.toString();
        return minutes.toString() + ":" + secondsText;
    }

    function line(dc, y, text, font) {
        if (text == null) { return; }
        dc.drawText(dc.getWidth() / 2, y, font, text.toString(), Graphics.TEXT_JUSTIFY_CENTER);
    }
}
