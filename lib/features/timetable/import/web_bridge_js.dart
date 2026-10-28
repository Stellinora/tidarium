const String shiguangBridgeInitJs = r'''
(function() {
    if (window._shiguangBridgeInjected) return;
    window._shiguangBridgeInjected = true;

    var callbacks = {};
    var callbackCounter = 0;

    function postRawMessage(msg) {
        try {
            if (window._shiguangNativeBridge && typeof window._shiguangNativeBridge.postMessage === 'function') {
                window._shiguangNativeBridge.postMessage(msg);
                return;
            }
            if (window.ShiguangBridge && typeof window.ShiguangBridge.postMessage === 'function') {
                window.ShiguangBridge.postMessage(msg);
                return;
            }
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.shiguangBridge) {
                window.webkit.messageHandlers.shiguangBridge.postMessage(msg);
                return;
            }
        } catch (error) {
            console.warn('[TidariumBridge] postMessage failed', error);
        }
        console.warn('[TidariumBridge] native bridge unavailable:', msg);
    }

    function postMessageToNative(action, payload, callbackId) {
        var msg = JSON.stringify({
            action: action,
            callbackId: callbackId || null,
            payload: payload ? JSON.stringify(payload) : null
        });
        postRawMessage(msg);
    }

    window._shiguangNativeCallback = function(callbackId, isSuccess, result) {
        var callback = callbacks[callbackId];
        if (!callback) return;
        if (isSuccess) {
            callback.resolve(result);
        } else {
            callback.reject(result);
        }
        delete callbacks[callbackId];
    };

    function callPromise(action, payload) {
        return new Promise(function(resolve, reject) {
            var id = 'cb_' + (++callbackCounter) + '_' + Date.now();
            callbacks[id] = { resolve: resolve, reject: reject };
            postMessageToNative(action, payload, id);
        });
    }

    window.shiguangBridgePromise = {
        showAlert: function(titleText, contentText, confirmText) {
            return callPromise('showAlert', {
                titleText: titleText || '',
                contentText: contentText || '',
                confirmText: confirmText || null
            });
        },
        showPrompt: function(titleText, tipText, defaultText, validatorJsFunction) {
            return callPromise('showPrompt', {
                titleText: titleText || '',
                tipText: tipText || '',
                defaultText: defaultText || '',
                validatorJsFunction: validatorJsFunction || null
            });
        },
        showSingleSelection: function(titleText, items, defaultSelectedIndex) {
            var itemsJson = (typeof items === 'string') ? items : JSON.stringify(items || []);
            return callPromise('showSingleSelection', {
                titleText: titleText || '',
                itemsJsonString: itemsJson,
                defaultSelectedIndex: defaultSelectedIndex === undefined ? -1 : defaultSelectedIndex
            });
        },
        saveImportedCourses: function(coursesJsonString) {
            return callPromise('saveImportedCourses', {
                coursesJsonString: coursesJsonString
            });
        },
        saveCourseConfig: function(configJsonString) {
            return callPromise('saveCourseConfig', {
                configJsonString: configJsonString
            });
        },
        savePresetTimeSlots: function(timeSlotsJsonString) {
            return callPromise('savePresetTimeSlots', {
                timeSlotsJsonString: timeSlotsJsonString
            });
        },
        saveComboSchedule: function(comboScheduleJsonString) {
            var comboJson = (typeof comboScheduleJsonString === 'string')
                ? comboScheduleJsonString
                : JSON.stringify(comboScheduleJsonString || {});
            return callPromise('saveComboSchedule', {
                comboScheduleJsonString: comboJson
            });
        }
    };

    window.shiguangBridge = {
        showToast: function(message) {
            postMessageToNative('showToast', { message: message });
        },
        notifyTaskCompletion: function() {
            postMessageToNative('notifyTaskCompletion');
        }
    };

    window.AndroidBridgePromise = window.shiguangBridgePromise;
    window.AndroidBridge = window.shiguangBridge;
})();
''';
