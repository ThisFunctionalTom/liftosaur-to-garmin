using Toybox.Application;
using Toybox.Application.Storage;
using Toybox.System;
using Toybox.Timer;
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
    var _holdTimer;
    var _keyDownAt;
    var _keyHandled;
    var _selectBehaviorSeen;
    var _suppressNextSelect;
    var _navigationKey;
    var _navigationKeyDownAt;
    var _navigationBehaviorSeen;
    var _navigationMenuSeen;
    var _navigationLongHandled;
    var _suppressNextMenu;
    var _suppressNextPage;
    var _suppressPreviousPage;

    function initialize(store) {
        BehaviorDelegate.initialize();
        _store = store;
        _holdTimer = new Timer.Timer();
    }

    function onSelect() {
        if (_suppressNextSelect) {
            _suppressNextSelect = false;
            return true;
        }
        if (_keyDownAt != null) {
            _selectBehaviorSeen = true;
            // Raw key handling dispatches short presses on release and holds
            // from the timer while the key is still down.
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
        if (_navigationKey == WatchUi.KEY_UP && _navigationKeyDownAt != null) {
            _navigationMenuSeen = true;
            return true;
        }
        if (_suppressNextMenu) {
            _suppressNextMenu = false;
            return true;
        }
        _store.menu();
        return true;
    }

    function onHoldThreshold() {
        if (_keyDownAt != null && !_keyHandled) {
            var keyElapsed = System.getTimer() - _keyDownAt;
            if (keyElapsed >= 700) {
                _keyHandled = true;
                _store.dispatchMessage("LONG_START", null, null);
            } else {
                _holdTimer.start(method(:onHoldThreshold), 700 - keyElapsed, false);
            }
            return;
        }
        if (_navigationKeyDownAt != null && !_navigationLongHandled) {
            var navElapsed = System.getTimer() - _navigationKeyDownAt;
            if (navElapsed >= 700) {
                _navigationLongHandled = true;
                if (_navigationKey == WatchUi.KEY_UP) {
                    _store.menu();
                } else if (_navigationKey == WatchUi.KEY_DOWN) {
                    _store.dispatchMessage("LONG_NAV", 1, null);
                }
            } else {
                _holdTimer.start(method(:onHoldThreshold), 700 - navElapsed, false);
            }
        }
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
            _selectBehaviorSeen = false;
            _holdTimer.start(method(:onHoldThreshold), 700, false);
            return true;
        }
        var phase = _store.state.get("phase");
        var canJumpExercise = phase != null &&
            (phase.equals("working") || phase.equals("rest") || phase.equals("complete"));
        if (canJumpExercise && (key == WatchUi.KEY_UP || key == WatchUi.KEY_DOWN)) {
            _navigationKey = key;
            _navigationKeyDownAt = System.getTimer();
            _navigationBehaviorSeen = false;
            _navigationMenuSeen = false;
            _navigationLongHandled = false;
            _suppressNextPage = false;
            _suppressPreviousPage = false;
            _holdTimer.start(method(:onHoldThreshold), 700, false);
            return true;
        }
        return false;
    }

    function onKeyReleased(keyEvent) {
        var key = keyEvent.getKey();
        if (_navigationKeyDownAt != null && key == _navigationKey) {
            _holdTimer.stop();
            var direction = key == WatchUi.KEY_UP ? -1 : 1;
            var longHandled = _navigationLongHandled == true;
            if (!longHandled) {
                _store.adjust(direction);
            }
            _suppressNextPage = key == WatchUi.KEY_DOWN && !_navigationBehaviorSeen;
            _suppressPreviousPage = key == WatchUi.KEY_UP && !_navigationBehaviorSeen;
            _suppressNextMenu = key == WatchUi.KEY_UP && longHandled && !_navigationMenuSeen;
            _navigationKey = null;
            _navigationKeyDownAt = null;
            _navigationBehaviorSeen = false;
            _navigationMenuSeen = false;
            _navigationLongHandled = false;
            return true;
        }
        if (key != WatchUi.KEY_ENTER) { return false; }
        _holdTimer.stop();
        var alreadyHandled = _keyHandled == true;
        var behaviorSeen = _selectBehaviorSeen == true;
        _keyDownAt = null;
        _keyHandled = false;
        _selectBehaviorSeen = false;
        if (!alreadyHandled) {
            selectOrPreview();
        }
        // BehaviorDelegate may report onSelect after this raw release event.
        _suppressNextSelect = !behaviorSeen;
        return true;
    }
}
