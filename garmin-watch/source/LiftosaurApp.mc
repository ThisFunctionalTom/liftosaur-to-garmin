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
        System.println("[Liftosaur] initialize");
        _store = new LiftosaurStore();
        _view = new LiftosaurView(_store);
    }

    function getInitialView() {
        System.println("[Liftosaur] getInitialView");
        return [ _view, new LiftosaurDelegate(_store) ];
    }

    function onStart(state) {
        System.println("[Liftosaur] onStart");
        _store.open();
    }

    function onStop(state) {
        _store.save();
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

    function initialize(store) {
        BehaviorDelegate.initialize();
        _store = store;
    }

    function onSelect() {
        if (_suppressNextSelect) {
            _suppressNextSelect = false;
            System.println("[Liftosaur] consumed duplicate START select behavior");
            return true;
        }
        if (_keyDownAt != null) {
            var held = System.getTimer() - _keyDownAt;
            if (held >= 700) {
                System.println("[Liftosaur] START hold detected by select behavior heldMs=" + held.toString());
                _store.dispatchMessage("LONG_START", null, null);
                _keyHandled = true;
            }
            // Defer short presses to onKeyReleased so there is one consistent
            // decision point for both the behavior and raw key callbacks.
            return true;
        }
        _store.select();
        return true;
    }

    function onNextPage() {
        _store.adjust(1);
        return true;
    }

    function onPreviousPage() {
        _store.adjust(-1);
        return true;
    }

    function onMenu() {
        _store.menu();
        return true;
    }

    function onBack() {
        _store.dispatchMessage("BACK", null, null);
        return true;
    }

    // Raw key events let us distinguish a short START press from a hold on
    // devices such as the fēnix 5, whose behavior delegate has no long-select.
    function onKeyPressed(keyEvent) {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            _keyDownAt = System.getTimer();
            _keyHandled = false;
            return true;
        }
        return false;
    }

    function onKeyReleased(keyEvent) {
        if (keyEvent.getKey() != WatchUi.KEY_ENTER) { return false; }
        var heldMs = _keyDownAt != null ? System.getTimer() - _keyDownAt : 0;
        var held = heldMs >= 700;
        System.println("[Liftosaur] START released heldMs=" + heldMs.toString() + " alreadyHandled=" + (_keyHandled == true).toString());
        var alreadyHandled = _keyHandled == true;
        _keyDownAt = null;
        _keyHandled = false;
        if (!alreadyHandled) {
            if (held) { _store.dispatchMessage("LONG_START", null, null); }
            else { _store.dispatchMessage("SELECT", null, null); }
        }
        // BehaviorDelegate may report onSelect after this raw release event.
        _suppressNextSelect = !alreadyHandled;
        return true;
    }
}
