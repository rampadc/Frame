var selectedCamera = null;
var availableCameras = null;

function toastSuccess(title, message) {
    $('body').toast({
        title: title,
        class: 'green',
        message: message,
        showProgress: 'top',
        progressUp: true,
        className: {
            toast: 'ui message'
        }
    });
}

function toastError(title, message) {
    $('body').toast({
        title: title,
        class: 'red',
        message: message,
        showProgress: 'top',
        progressUp: true,
        className: {
            toast: 'ui message'
        }
    });
}

$(document).ready(function () {
    $('.ui.slider').slider();

    if (typeof cameras != 'undefined') {
        // dev mode
        configureCamera(cameras);
    } else {
        // on device
        getCameras();
    }

    // When available cameras list is changed, update the JSON viewer to see that camera's property
    // Do not switch user's camera
    $('#camerasList').change(() => {
        var cameraId = $('#camerasList').val();
        selectedCamera = _.find(availableCameras, function (o) {
            return o.properties.uniqueID == cameraId;
        });
        $('#cameraProperties').jsonViewer(selectedCamera);
    });

    // When the current camera selection is change, switch the user's camera
    // Update the GUI to reflect the new camera's settings
    $('#currentCameraSelection').change(() => {
        var cameraId = $('#currentCameraSelection').val();
        selectedCamera = _.find(availableCameras, function (o) {
            return o.properties.uniqueID == cameraId;
        });

        const formData = new URLSearchParams()
        formData.append('uniqueID', selectedCamera.properties.uniqueID);

        $.ajax('/cameras/select', {
            type: 'POST',
            data: formData.toString()
        }).done((data) => {
            toastSuccess('Camera switched', 'Hooray!');
        }).fail((jqXHR, textStatus, errorThrown) => {
            if (jqXHR.status == 501) {
                toastError('Camera switch failed', 'Dev forgot to implement NDI Control delegate');
            }
            if (jqXHR.status == 400) {
                toastError('Camera switch failed', 'Bad inputs. Expected a camera\'s unique ID');
            }
            if (jqXHR.status == 500) {
                toastError('Camera switch failed', 'iPhone does not want to switch. Try again later.');
            }
        });

        updateGuiForSelectedCamera();
    });
});

function getCameras() {
    $.ajax(`/cameras`).done((data) => {
        configureCamera(data);
    });
}

function configureCamera(cameras) {
    availableCameras = cameras;
    selectedCamera = cameras[0];

    setupCamerasInspection(cameras);
    setupCurrentCameraSelection(cameras);
    updateGuiForSelectedCamera();
}

function setupCamerasInspection(cameras) {
    $('#camerasList').html('')
    $.each(cameras, (idx, camera) => {
        $('#camerasList').append(`<option value="${camera.properties.uniqueID}">${camera.properties.localizedName}</option>`)
    });
    $('#cameraProperties').jsonViewer(cameras[0]);
}

function setupCurrentCameraSelection(cameras) {
    $('#currentCameraSelection').html('')
    $.each(cameras, (idx, camera) => {
        $('#currentCameraSelection').append(`<option value="${camera.properties.uniqueID}">${camera.properties.localizedName}</option>`)
    });
}

function updateGuiForSelectedCamera() {
    updateZoomGui();
    // updateCustomExposureGui();
    updateCompensationExposureGui();
}

function updateCustomExposureGui() {
    var exposureTimeSlider = $('#exposure-time-slider');
    var exposureTimeInput = $('#exposure-time-slider-input');
    var isoSlider = $('#iso-slider');
    var isoInput = $('#iso-slider-input');
    var autoExposeBtn = $('#auto-expose-btn');

    if (selectedCamera.exposure.isCustomExposureSupported) {
        $('#exposure-label').text(`Aperture: ${selectedCamera.properties.lensAperture}`);
        exposureTimeSlider.prop('disabled', false);
        exposureTimeInput.prop('disabled', false);
        isoSlider.prop('disabled', false);
        isoInput.prop('disabled', false);
        autoExposeBtn.prop('disabled', false);

        exposureTimeSlider.val(selectedCamera.exposure.currentTargetBias_EV);
        exposureTimeInput.val(selectedCamera.exposure.currentTargetBias_EV);
    
        exposureTimeSlider.attr('min', 0.0);
        exposureTimeSlider.attr('max', 1.0);
        exposureTimeSlider.attr('step', 0.0001);
        exposureTimeSlider.on('input change', (e) => {
            const value = e.target.value;
            exposureTimeInput.val(value);
            expose(value);
        });
    
        exposureTimeInput.change(() => {
            const value = exposureTimeInput.val();
            expose(value);
        });
    
        exposureTimeInput.on('keypress', function(e) {
            if (e.which === 13) {
                var value = exposureTimeInput.val();
                expose(value);
            }
        })

        isoInput.change(() => {
            const value = isoInput.val();
            expose(value);
        });
    
        isoInput.on('keypress', function(e) {
            if (e.which === 13) {
                var value = isoInput.val();
                expose(value);
            }
        })
    } else {
        $('#exposure-label').text('Custom exposure not supported');
        exposureTimeSlider.prop('disabled', true);
        exposureTimeInput.prop('disabled', true);
        isoSlider.prop('disabled', true);
        isoInput.prop('disabled', true);
        autoExposeBtn.prop('disabled', true);
    }
}

function exposeCustom(duration, iso) {
    // UNUSED
    const formData = new URLSearchParams()
    formData.append('exposeTime', parseFloat(duration));
    formData.append('iso', parseFloat(iso));

    $.ajax('/camera/exposure/custom', {
        type: 'POST',
        data: formData.toString()
    }).done((data) => {
        $('#exposure-slider-input').val(duration);
        $('#exposure-slider').val(duration);
        $('#iso-slider-input').val(iso);
        $('#iso-slider').val(iso);
    }).fail((jqXHR, textStatus, errorThrown) => {
        if (jqXHR.status == 501) {
            toastError('Cannot change exposure', 'Feature not implemented');
        }
        if (jqXHR.status == 400) {
            toastError('Cannot change exposure', 'Bad inputs. Expected a exposureTarget as a floating number');
        }
        if (jqXHR.status == 500) {
            toastError('Cannot change exposure', 'iPhone does not want to switch. Try again later.');
        }
    });
}

function updateCompensationExposureGui() {
    var slider = $('#ev-slider');
    var input = $('#ev-slider-input');

    let min = selectedCamera.exposure.minExposureTargetBias_EV;
    let max = selectedCamera.exposure.maxExposureTargetBias_EV;
    let current = selectedCamera.exposure.currentTargetBias_EV;

    slider.val(current);
    input.val(current);

    slider.attr('min', min);
    slider.attr('max', max);
    slider.attr('step', 0.01);
    slider.on('input change', (e) => {
        const ev = e.target.value;
        input.val(ev);
        compensateExposure(ev);
    });

    input.change(() => {
        const ev = input.val();
        compensateExposure(ev);
    });

    input.on('keypress', function(e) {
        if (e.which === 13) {
            const ev = input.val();
            compensateExposure(ev);
        }
    })
}

function compensateExposure(ev) {
    const formData = new URLSearchParams()
    formData.append('bias', parseFloat(ev));

    $.ajax('/camera/exposure/bias', {
        type: 'POST',
        data: formData.toString()
    }).done((data) => {
        $('#ev-slider-input').val(ev);
        $('#ev-slider').val(ev);
    }).fail((jqXHR, textStatus, errorThrown) => {
        if (jqXHR.status == 501) {
            toastError('Cannot change exposure', 'Feature not implemented');
        }
        if (jqXHR.status == 400) {
            toastError('Cannot change exposure', 'Bad inputs. Expected a exposureTarget as a floating number');
        }
        if (jqXHR.status == 500) {
            toastError('Cannot change exposure', 'iPhone does not want to switch. Try again later.');
        }
    });
}

function updateZoomGui() {
    var slider = $('#zoom-slider');
    var input = $('#zoom-slider-input');

    slider.val(selectedCamera.zoom.minAvailableZoomFactor);
    input.val(selectedCamera.zoom.minAvailableZoomFactor);

    slider.attr('min', selectedCamera.zoom.minAvailableZoomFactor);
    slider.attr('max', selectedCamera.zoom.maxAvailableZoomFactor);
    slider.attr('step', 0.01);
    slider.on('input change', (e) => {
        const factor = e.target.value;
        input.val(factor);
        zoom(factor);
    });

    input.change(() => {
        const factor = input.val();
        zoom(factor);
    });

    input.on('keypress', function(e) {
        if (e.which === 13) {
            const factor = input.val();
            zoom(factor);
        }
    })
}

function zoom(factor) {
    const formData = new URLSearchParams()
    formData.append('zoomFactor', factor);

    $.ajax('/camera/zoom', {
        type: 'POST',
        data: formData.toString()
    }).done((data) => {
        $('#zoom-slider-input').val(factor);
        $('#zoom-slider').val(factor);
    }).fail((jqXHR, textStatus, errorThrown) => {
        if (jqXHR.status == 501) {
            toastError('Cannot zoom', 'Feature not implemented');
        }
        if (jqXHR.status == 400) {
            toastError('Cannot zoom', 'Bad inputs. Expected a zoomFactor as a floating number');
        }
        if (jqXHR.status == 500) {
            toastError('Cannot zoom', 'iPhone does not want to switch. Try again later.');
        }
    });
}