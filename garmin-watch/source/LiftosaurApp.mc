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

    function initialize(store) {
        BehaviorDelegate.initialize();
        _store = store;
    }

    function onSelect() {
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
        if (_store.isText(_store.state.get("phase"), "rest")) {
            _store.skipRest();
        } else if (_store.isText(_store.state.get("phase"), "editing")) {
            _store.cancelEdit();
        } else if (_store.isText(_store.state.get("phase"), "actions")) {
            _store.cancelActions();
        } else if (_store.isText(_store.state.get("phase"), "confirm-finish")) {
            _store.cancelFinish();
        } else if (_store.isText(_store.state.get("phase"), "confirm-discard")) {
            _store.cancelDiscard();
        } else {
            _store.undo();
        }
        return true;
    }

    // Raw key events let us distinguish a short START press from a hold on
    // devices such as the fēnix 5, whose behavior delegate has no long-select.
    function onKeyPressed(keyEvent) {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            _keyDownAt = System.getTimer();
            return true;
        }
        return false;
    }

    function onKeyReleased(keyEvent) {
        if (keyEvent.getKey() != WatchUi.KEY_ENTER) { return false; }
        var held = _keyDownAt != null && System.getTimer() - _keyDownAt >= 700;
        _keyDownAt = null;

        if (held && _store.isText(_store.state.get("phase"), "working")) {
            _store.editCurrentReps();
        } else if (held && _store.isText(_store.state.get("phase"), "editing")) {
            _store.saveEditedSet();
        } else if (!held) {
            _store.select();
        }
        return true;
    }
}
