var selectedCamera = null;
var availableCameras = null;

$(document).ready(function () {
    $('.ui.slider').slider();

    if (typeof cameras != 'undefined') {
        configureCamera(cameras);
    } else {
        $.ajax(`/cameras`).done((data) => {
            configureCamera(data);    
        });
    } 

    $('#camerasList').change(() => {
        var cameraId = $('#camerasList').val();
        selectedCamera = _.find(availableCameras, function(o) {
            return o.properties.uniqueID == cameraId;
        });
        updateGuiForSelectedCamera();
    });
});

function configureCamera(cameras) {
    availableCameras = cameras;

    $('#camerasList').html('')
    $.each(cameras, (idx, camera) => {
        $('#camerasList').append(`<option value="${camera.properties.uniqueID}">${camera.properties.localizedName}</option>`)
    });

    selectedCamera = cameras[0];
    updateGuiForSelectedCamera();
}

function updateGuiForSelectedCamera() {
    $('#cameraProperties').jsonViewer(selectedCamera);
}