var cameras = [];

$(document).ready(function() {
    $.ajax(`/cameras`).done((data) => {
        cameras = data;
        $('#camerasList').html('')
        $.each(cameras, (idx, camera) => {
            $('#camerasList').append(`<option value="${camera.properties.uniqueID}">${camera.properties.localizedName}</option>`)
        });

        let defaultCamera = cameras[0];
        $('#cameraProperties').jsonViewer(defaultCamera);
    });
});