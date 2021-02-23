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
        configureCamera(cameras);
    } else {
        $.ajax(`/cameras`).done((data) => {
            configureCamera(data);
        });
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

function configureCamera(cameras) {
    availableCameras = cameras;
    selectedCamera = cameras[0];

    setupCamerasInspection();
    setupCurrentCameraSelection();
    updateGuiForSelectedCamera();
}

function setupCamerasInspection() {
    $('#camerasList').html('')
    $.each(cameras, (idx, camera) => {
        $('#camerasList').append(`<option value="${camera.properties.uniqueID}">${camera.properties.localizedName}</option>`)
    });
    $('#cameraProperties').jsonViewer(cameras[0]);
}

function setupCurrentCameraSelection() {
    $('#currentCameraSelection').html('')
    $.each(cameras, (idx, camera) => {
        $('#currentCameraSelection').append(`<option value="${camera.properties.uniqueID}">${camera.properties.localizedName}</option>`)
    });
}

function updateGuiForSelectedCamera() {
    $('#zoom-slider').slider({
        min: selectedCamera.zoom.minAvailableZoomFactor,
        max: selectedCamera.zoom.maxAvailableZoomFactor,
        start: selectedCamera.zoom.videoZoomFactor,
        step: 0.01,
        onChange: function(value) {
            $.ajax(`/camera/zoom?value=${value}`)
            .done((data) => {

            })
            .fail((jqXHR, textStatus, errorThrown) => {

            })
        }
    });
    
}