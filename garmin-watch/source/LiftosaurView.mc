using Toybox.Graphics;
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

        if (phase.equals("preview")) {
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
        } else if (isText(phase, "finishing")) {
            line(dc, 78, "SAVING", Graphics.FONT_MEDIUM);
            line(dc, 118, statusText(state), Graphics.FONT_SMALL);
        } else {
            line(dc, 78, "LIFTOSAUR", Graphics.FONT_MEDIUM);
            line(dc, 120, statusText(state), Graphics.FONT_SMALL);
        }
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
        line(dc, dc.getHeight() - 48, "PRESS START", Graphics.FONT_SMALL);
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
        dc.setColor(nextSet ? Graphics.COLOR_GREEN : Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        line(dc, 38, entry.get("name").toString(), Graphics.FONT_SMALL);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        var setPosition = currentSetNumber(entry, set);
        if (LiftosaurSet.get(set, "isWarmup") == true) {
            line(dc, 82, "W" + setPosition.toString() + " / " + warmupSetCount(entry).toString(), Graphics.FONT_SMALL);
        } else {
            line(dc, 82, "SET " + setPosition.toString() + " / " + workSetCount(entry).toString(), Graphics.FONT_SMALL);
        }
        var completed = LiftosaurSet.get(set, "completed");
        var shownWeight = completed != null && LiftosaurSet.doneGet(completed, "weight") != null ? LiftosaurSet.doneGet(completed, "weight") : LiftosaurSet.get(set, "weight");
        var plannedReps = LiftosaurSet.get(set, "reps").toString();
        if (LiftosaurSet.get(set, "isAmrap") == true) { plannedReps += "+"; }
        drawWeightAndReps(dc, 120, shownWeight, plannedReps);
        var actualReps = completed == null ? null : LiftosaurSet.doneGet(completed, "reps");
        if (actualReps != null) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);
            line(dc, 166, "done " + actualReps.toString(), Graphics.FONT_SMALL);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        }
        drawSetProgress(dc, entry, set, nextSet);
    }

    function drawEdit(dc, state) {
        var entry = _store.currentEntry();
        if (entry != null) { line(dc, 38, entry.get("name").toString(), Graphics.FONT_SMALL); }
        if (isText(state.get("editField"), "reps")) {
            line(dc, 88, state.get("editCompleted") == true ? "FIX LOGGED REPS" : "REPS", Graphics.FONT_SMALL);
            line(dc, 125, state.get("editReps").toString(), Graphics.FONT_NUMBER_HOT);
        } else {
            line(dc, 88, "WEIGHT", Graphics.FONT_SMALL);
            drawWeight(dc, 125, state.get("editWeight"));
        }
    }

    function drawRest(dc, state) {
        var remaining = _store.remainingRest();
        line(dc, 49, "REST", Graphics.FONT_SMALL);
        line(dc, 101, formatTime(remaining), Graphics.FONT_NUMBER_HOT);
        var next = _store.currentEntry();
        var nextSet = _store.currentSet();
        if (next != null) {
            var nextLabel = "NEXT ";
            if (nextSet != null && LiftosaurSet.get(nextSet, "isWarmup") == true) {
                nextLabel += "W" + currentSetNumber(next, nextSet).toString();
            } else if (nextSet != null) {
                nextLabel += currentSetNumber(next, nextSet).toString();
            }
            nextLabel += ": ";
            line(dc, 158, nextLabel + next.get("name").toString(), Graphics.FONT_XTINY);
            if (nextSet != null) {
                drawWeight(dc, 190, LiftosaurSet.get(nextSet, "weight"));
            }
        } else {
            line(dc, 171, "WORKOUT COMPLETE", Graphics.FONT_SMALL);
        }
        line(dc, 220, statusText(state), Graphics.FONT_XTINY);
    }

    function drawComplete(dc, state) {
        if (isText(state.get("phase"), "confirm-finish")) {
            line(dc, 70, "FINISH WORKOUT?", Graphics.FONT_MEDIUM);
            line(dc, 113, "Completed sets will save", Graphics.FONT_XTINY);
        } else {
            line(dc, 76, "WORKOUT", Graphics.FONT_SMALL);
            line(dc, 111, "COMPLETE", Graphics.FONT_MEDIUM);
        }
    }

    function drawDiscardConfirmation(dc, state) {
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
        line(dc, 65, "DISCARD WORKOUT?", Graphics.FONT_SMALL);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        line(dc, 108, "This cannot be undone", Graphics.FONT_XTINY);
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
        drawWeightAndReps(dc, 132, shownWeight, plannedReps);
        var actualReps = completed == null ? null : LiftosaurSet.doneGet(completed, "reps");
        if (actualReps != null) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);
            line(dc, 178, "done " + actualReps.toString(), Graphics.FONT_SMALL);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        }
    }

    function drawActions(dc, state) {
        var target = _store.undoTarget();
        var hasUndo = target != null;
        var selected = state.get("selectedAction");
        line(dc, 38, "WORKOUT OPTIONS", Graphics.FONT_XTINY);
        line(dc, 78, selected == 0 ? "> LEAVE / KEEP" : "LEAVE / KEEP", Graphics.FONT_XTINY);
        line(dc, 108, selected == 1 ? "> FINISH WORKOUT" : "FINISH WORKOUT", Graphics.FONT_XTINY);
        if (hasUndo) {
            var undoLabel = target.get("selected") == true ? "UNDO THIS SET" : "UNDO LAST SET";
            line(dc, 138, selected == 2 ? "> " + undoLabel : undoLabel, Graphics.FONT_XTINY);
        }
        var discardIndex = hasUndo ? 3 : 2;
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
        line(dc, 168, selected == discardIndex ? "> DISCARD WORKOUT" : "DISCARD WORKOUT", Graphics.FONT_XTINY);
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

    function drawSetProgress(dc, entry, currentSet, nextSet) {
        var sets = entry.get("sets");
        var count = sets.size();
        if (count == 0) { return; }
        var spacing = count > 1 ? (dc.getWidth() - 40) / (count - 1) : 0;
        if (spacing > 18) { spacing = 18; }
        var startX = (dc.getWidth() - ((count - 1) * spacing)) / 2;
        var index = 0;
        var centerY = 204;
        for (var i = 0; i < sets.size(); i += 1) {
            var set = sets[i];
            var x = startX + (index * spacing);
            var selected = LiftosaurSet.get(set, "setId") == LiftosaurSet.get(currentSet, "setId");
            var completed = LiftosaurSet.get(set, "completed") != null;
            var warmup = LiftosaurSet.get(set, "isWarmup") == true;
            if (completed) {
                dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);
                dc.drawLine(x - 4, centerY, x - 1, centerY + 3);
                dc.drawLine(x - 1, centerY + 3, x + 5, centerY - 4);
                if (selected) {
                    dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_BLACK);
                    if (warmup) { dc.drawRectangle(x - 7, centerY - 7, 14, 14); }
                    else { dc.drawCircle(x, centerY, 7); }
                }
            } else if (selected) {
                dc.setColor(nextSet ? Graphics.COLOR_GREEN : Graphics.COLOR_YELLOW, Graphics.COLOR_BLACK);
                if (warmup) { dc.fillRectangle(x - 4, centerY - 4, 9, 9); }
                else { dc.fillCircle(x, centerY, 5); }
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
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

    function drawWeightAndReps(dc, y, weight, reps) {
        var number = "BW";
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
            number = text.substring(0, unitStart);
            unit = text.substring(unitStart, chars.size());
        }

        var numberWidth = dc.getTextWidthInPixels(number, Graphics.FONT_NUMBER_MEDIUM);
        var unitWidth = dc.getTextWidthInPixels(unit, Graphics.FONT_SMALL);
        var multiplyWidth = dc.getTextWidthInPixels("x", Graphics.FONT_SMALL);
        var repsWidth = dc.getTextWidthInPixels(reps, Graphics.FONT_NUMBER_MEDIUM);
        var numberHeight = dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM);
        var multiplyHeight = dc.getFontHeight(Graphics.FONT_SMALL);
        var multiplyY = y + ((numberHeight - multiplyHeight) / 2);
        var gap = 4;
        var unitGap = unit.length() > 0 ? gap : 0;
        var totalWidth = numberWidth + unitGap + unitWidth + gap + multiplyWidth + gap + repsWidth;
        var x = (dc.getWidth() - totalWidth) / 2;
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_BLACK);
        dc.drawText(x, y, Graphics.FONT_NUMBER_MEDIUM, number, Graphics.TEXT_JUSTIFY_LEFT);
        var suffixX = x + numberWidth + unitGap;
        if (unit.length() > 0) {
            dc.drawText(suffixX, y + 15, Graphics.FONT_SMALL, unit, Graphics.TEXT_JUSTIFY_LEFT);
            suffixX += unitWidth + gap;
        }
        dc.drawText(suffixX, multiplyY, Graphics.FONT_SMALL, "x", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(suffixX + multiplyWidth + gap, y, Graphics.FONT_NUMBER_MEDIUM, reps, Graphics.TEXT_JUSTIFY_LEFT);
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
