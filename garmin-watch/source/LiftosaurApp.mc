using Toybox.Application;
using Toybox.Application.Storage;
using Toybox.System;
using Toybox.WatchUi;

class LiftosaurApp extends Application.AppBase {
    var _view;
    var _store;

    function initialize() {
        AppBase.initialize();
        var buildInfo = new LiftosaurBuildInfo();
        System.println("[Liftosaur] build=" + buildInfo.getBuildId());
        _store = new LiftosaurStore();
        _view = new LiftosaurView(_store);
    }

    function getInitialView() {
        return [ _view, new LiftosaurDelegate(_store) ];
    }

    function onStart(state) {
        _store.open();
    }

    function onStop(state) {
        _store.stop();
    }

    function onSettingsChanged() {
        _store.open();
    }
}

class LiftosaurDelegate extends WatchUi.BehaviorDelegate {
    var _store;
    var _keyDownAt;
    var _keyHandled;
    var _suppressNextSelect;
    var _navigationKey;
    var _navigationKeyDownAt;
    var _navigationBehaviorSeen;
    var _suppressNextPage;
    var _suppressPreviousPage;

    function initialize(store) {
        BehaviorDelegate.initialize();
        _store = store;
    }

    function onSelect() {
        if (_suppressNextSelect) {
            _suppressNextSelect = false;
            return true;
        }
        if (_keyDownAt != null) {
            var held = System.getTimer() - _keyDownAt;
            if (held >= 700) {
                _store.dispatchMessage("LONG_START", null, null);
                _keyHandled = true;
            }
            // Defer short presses to onKeyReleased so there is one consistent
            // decision point for both the behavior and raw key callbacks.
            return true;
        }
        selectOrPreview();
        return true;
    }

    function selectOrPreview() {
        _store.select();
    }

    function onNextPage() {
        if (_suppressNextPage) { _suppressNextPage = false; return true; }
        if (_navigationKey == WatchUi.KEY_DOWN && _navigationKeyDownAt != null) {
            _navigationBehaviorSeen = true;
            return true;
        }
        _store.adjust(1);
        return true;
    }

    function onPreviousPage() {
        if (_suppressPreviousPage) { _suppressPreviousPage = false; return true; }
        if (_navigationKey == WatchUi.KEY_UP && _navigationKeyDownAt != null) {
            _navigationBehaviorSeen = true;
            return true;
        }
        _store.adjust(-1);
        return true;
    }

    function onMenu() {
        _store.menu();
        return true;
    }

    function onBack() {
        // When there is no active workout, let Garmin's default back behavior
        // close the app. During a workout BACK remains an app navigation input.
        if (!_store.isActive()) {
            return false;
        }
        _store.dispatchMessage("BACK", null, null);
        return true;
    }

    // Raw key events let us distinguish a short START press from a hold on
    // devices such as the fēnix 5, whose behavior delegate has no long-select.
    function onKeyPressed(keyEvent) {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER) {
            _keyDownAt = System.getTimer();
            _keyHandled = false;
            return true;
        }
        var phase = _store.state.get("phase");
        var canJumpExercise = phase != null &&
            (phase.equals("working") || phase.equals("rest") || phase.equals("complete"));
        if (canJumpExercise && (key == WatchUi.KEY_UP || key == WatchUi.KEY_DOWN)) {
            _navigationKey = key;
            _navigationKeyDownAt = System.getTimer();
            _navigationBehaviorSeen = false;
            _suppressNextPage = false;
            _suppressPreviousPage = false;
            return true;
        }
        return false;
    }

    function onKeyReleased(keyEvent) {
        var key = keyEvent.getKey();
        if (_navigationKeyDownAt != null && key == _navigationKey) {
            var navigationHeld = System.getTimer() - _navigationKeyDownAt >= 700;
            var direction = key == WatchUi.KEY_UP ? -1 : 1;
            if (navigationHeld) {
                _store.dispatchMessage("LONG_NAV", direction, null);
            } else {
                _store.adjust(direction);
            }
            _suppressNextPage = key == WatchUi.KEY_DOWN && !_navigationBehaviorSeen;
            _suppressPreviousPage = key == WatchUi.KEY_UP && !_navigationBehaviorSeen;
            _navigationKey = null;
            _navigationKeyDownAt = null;
            _navigationBehaviorSeen = false;
            return true;
        }
        if (key != WatchUi.KEY_ENTER) { return false; }
        var heldMs = _keyDownAt != null ? System.getTimer() - _keyDownAt : 0;
        var held = heldMs >= 700;
        var alreadyHandled = _keyHandled == true;
        _keyDownAt = null;
        _keyHandled = false;
        if (!alreadyHandled) {
            if (held) { _store.dispatchMessage("LONG_START", null, null); }
            else { selectOrPreview(); }
        }
        // BehaviorDelegate may report onSelect after this raw release event.
        _suppressNextSelect = !alreadyHandled;
        return true;
    }
}
