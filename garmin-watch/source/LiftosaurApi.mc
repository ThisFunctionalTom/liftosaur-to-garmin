using Toybox.Communications;
using Toybox.Application.Properties;
using Toybox.Application.Storage;
using Toybox.Math;
using Toybox.Time;

class LiftosaurApi {
    const BASE_URL = "https://www.liftosaur.com/api/v1";
    const CLIENT_NAME = "LiftosaurGarmin/0.1.0";

    var _apiKey;
    var _deviceId;

    function initialize() {
        _apiKey = Properties.getValue("apiKey");
        _deviceId = Storage.getValue("deviceId");
        if (_deviceId == null) {
            _deviceId = Time.now().value().toString() + "-" + Math.rand().toString();
            Storage.setValue("deviceId", _deviceId);
        }
    }

    function hasKey() {
        // Settings can change while the app is open, especially in the simulator.
        _apiKey = Properties.getValue("apiKey");
        return _apiKey != null && _apiKey.length() > 0;
    }

    function get(path, callback) {
        request(path, Communications.HTTP_REQUEST_METHOD_GET, null, callback, false);
    }

    function post(path, body, callback) {
        request(path, Communications.HTTP_REQUEST_METHOD_POST, body, callback, true);
    }

    function delete(path, body, callback) {
        request(path, Communications.HTTP_REQUEST_METHOD_DELETE, body, callback, true);
    }

    function request(path, method, body, callback, isWrite) {
        if (!hasKey()) {
            callback.invoke(401, null);
            return;
        }

        var headers = {
            "Authorization" => "Bearer " + _apiKey
        };

        if (isWrite) {
            headers["X-Liftosaur-Device-Id"] = _deviceId;
            headers["X-Liftosaur-Client"] = CLIENT_NAME;
            headers["Content-Type"] = Communications.REQUEST_CONTENT_TYPE_JSON;
        }

        var options = {
            :method => method,
            :headers => headers
        };
        if (method == Communications.HTTP_REQUEST_METHOD_DELETE) {
            // makeJsonRequest appends DELETE parameters to the URL. The
            // Liftosaur discard endpoint expects startTime in a JSON body.
            options[:responseType] = Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON;
            Communications.makeWebRequest(BASE_URL + path, body, options, callback);
        } else {
            Communications.makeJsonRequest(BASE_URL + path, body, options, callback);
        }
    }
}
