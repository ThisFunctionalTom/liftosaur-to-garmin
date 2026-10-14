using Toybox.Lang;

// Persisted layout v1. Keep these positions stable across app upgrades.
// Only high-cardinality set records use arrays; HTTP payloads remain objects.
module LiftosaurSet {
    const COMPLETED = 10;
    var fields = {
        "setId" => 0, "reps" => 1, "weight" => 2, "isWarmup" => 3,
        "isAmrap" => 4, "timer" => 5, "askWeight" => 6, "logRpe" => 7,
        "isUnilateral" => 8, "hasSetTimer" => 9, "completed" => COMPLETED,
        "plateSummary" => 11
    };

    function get(set, key) {
        if (set instanceof Lang.Array) {
            var index = fields.get(key);
            return index >= set.size() ? null : set[index];
        }
        // Old saved workouts and API responses use dictionaries.
        return set.get(key);
    }

    function doneGet(completed, key) {
        if (completed instanceof Lang.Array) {
            var index = key.equals("reps") ? 0 : key.equals("weight") ? 1 : 2;
            return index >= completed.size() ? null : completed[index];
        }
        return completed.get(key);
    }

    function packCompleted(completed) {
        if (completed == null || completed instanceof Lang.Array) { return completed; }
        var repsLeft = completed.get("repsLeft");
        if (repsLeft == null) { return [completed.get("reps"), completed.get("weight")]; }
        return [completed.get("reps"), completed.get("weight"), repsLeft];
    }

    function apiCompleted(completed) {
        if (completed == null) { return null; }
        var result = { "reps" => doneGet(completed, "reps") };
        var weight = doneGet(completed, "weight");
        var repsLeft = doneGet(completed, "repsLeft");
        if (weight != null) { result["weight"] = weight; }
        if (repsLeft != null) { result["repsLeft"] = repsLeft; }
        return result;
    }

    function pack(set, isWarmup) {
        return packWithPlateMultiplier(set, isWarmup, 1);
    }

    function packBarbell(set, isWarmup) {
        return packWithPlateMultiplier(set, isWarmup, 2);
    }

    function packWithPlateMultiplier(set, isWarmup, plateMultiplier) {
        if (set instanceof Lang.Array) { return set; }
        return [
            set.get("setId"), set.get("reps"), set.get("weight"),
            isWarmup || set.get("isWarmup") == true,
            set.get("isAmrap") == true, set.get("timer"),
            set.get("askWeight") == true, set.get("logRpe") == true,
            set.get("isUnilateral") == true,
            set.get("hasSetTimer") == true || set.get("setTimer") != null,
            packCompleted(set.get("completed")), packPlateSummary(set.get("plates"), plateMultiplier)
        ];
    }

    function packPlateSummary(plates, plateMultiplier) {
        if (plates == null || plates.size() == 0) { return null; }
        var summary = "";
        for (var i = 0; i < plates.size(); i += 1) {
            var plate = plates[i];
            var weight = plate.get("weight");
            var totalCount = plate.get("num");
            if (weight == null || totalCount == null || totalCount < plateMultiplier) { continue; }
            var weightText = weight.toString();
            var chars = weightText.toCharArray();
            var unitStart = chars.size();
            for (var j = 0; j < chars.size(); j += 1) {
                var character = chars[j].toString().toLower();
                if (character.equals("k") || character.equals("l")) {
                    unitStart = j;
                    break;
                }
            }
            var plateWeight = weightText.substring(0, unitStart);
            var countPerSide = 0;
            for (var n = plateMultiplier; n <= totalCount; n += plateMultiplier) { countPerSide += 1; }
            if (countPerSide > 0) {
                if (summary.length() > 0) { summary += "|"; }
                if (countPerSide > 1) { summary += countPerSide.toString() + "x"; }
                summary += plateWeight;
            }
        }
        return summary.length() == 0 ? null : summary;
    }

    function withCompleted(set, completed) {
        var source = pack(set, false);
        var result = new [12];
        for (var i = 0; i < source.size(); i += 1) { result[i] = source[i]; }
        result[COMPLETED] = packCompleted(completed);
        return result;
    }
}
