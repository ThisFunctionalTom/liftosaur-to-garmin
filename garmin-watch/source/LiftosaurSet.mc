using Toybox.Lang;

// Persisted layout v1. Keep these positions stable across app upgrades.
// Only high-cardinality set records use arrays; HTTP payloads remain objects.
module LiftosaurSet {
    const COMPLETED = 10;
    var fields = {
        "setId" => 0, "reps" => 1, "weight" => 2, "isWarmup" => 3,
        "isAmrap" => 4, "timer" => 5, "askWeight" => 6, "logRpe" => 7,
        "isUnilateral" => 8, "hasSetTimer" => 9, "completed" => COMPLETED
    };

    function get(set, key) {
        if (set instanceof Lang.Array) { return set[fields.get(key)]; }
        // Old saved workouts and API responses use dictionaries.
        return set.get(key);
    }

    function doneGet(completed, key) {
        if (completed instanceof Lang.Array) {
            return completed[key.equals("reps") ? 0 : 1];
        }
        return completed.get(key);
    }

    function packCompleted(completed) {
        if (completed == null || completed instanceof Lang.Array) { return completed; }
        return [completed.get("reps"), completed.get("weight")];
    }

    function apiCompleted(completed) {
        if (completed == null) { return null; }
        var result = { "reps" => doneGet(completed, "reps") };
        var weight = doneGet(completed, "weight");
        if (weight != null) { result["weight"] = weight; }
        return result;
    }

    function pack(set, isWarmup) {
        if (set instanceof Lang.Array) { return set; }
        return [
            set.get("setId"), set.get("reps"), set.get("weight"),
            isWarmup || set.get("isWarmup") == true,
            set.get("isAmrap") == true, set.get("timer"),
            set.get("askWeight") == true, set.get("logRpe") == true,
            set.get("isUnilateral") == true,
            set.get("hasSetTimer") == true || set.get("setTimer") != null,
            packCompleted(set.get("completed"))
        ];
    }

    function withCompleted(set, completed) {
        var source = pack(set, false);
        var result = new [11];
        for (var i = 0; i < source.size(); i += 1) { result[i] = source[i]; }
        result[COMPLETED] = packCompleted(completed);
        return result;
    }
}
