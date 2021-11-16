# NDISenderExample

## Overview

Minimum implementation of the NDI SDK that works on the iPhone using Swift, with a set of exposed API to control the camera:

- List all available cameras `GET /cameras`
- Get active camera `GET /cameras/active`
- Switch camera `POST /cameras/select`
- Zoom with the selected camera `POST /camera/zoom`
- Change exposure bias `POST /camera/exposure/bias`
- Enable auto white balance `GET /camera/white-balance/mode/auto`
- Enable custom white balance `GET /camera/white-balance/mode/locked`
- Get current white balance temperature and white balance tint `GET /camera/white-balance/temp-tint`
- Set a new white balance temperature and white balance tint `POST /camera/white-balance/temp-tint`
- Set a custom white balance with a grey reference colour card `GET /camera/white-balance/grey`
- Hide controls on screen `GET /controls/hide`
- Show controls on screen `GET /controls/show`
- Start NDI `GET /ndi/start`
- Stop NDI `GET /ndi/stop` 
- Change session preset between `1080p`, `720p` and `4K` with `GET /preset/1080p`, `GET /preset/720p` and `GET /preset/4K` respectively

POST requests require a body of type `application/x-www-form-urlencoded`. As of Mar/2021, I haven't made a Swagger file for all the endpoints yet. To see what parameters you need to input, have a look at `NDIControls.swift`. For example, to change the white balance temperature and tint, you will need `temperature` and `tint` keys in the POST body, as indicated by the code in `NDIControls.swift` as below:

```swift
webServer.addHandler(forMethod: "POST", pathRegex: "/camera/white-balance/temp-tint", request: GCDWebServerURLEncodedFormRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
   let r = request as! GCDWebServerURLEncodedFormRequest
   guard let temp = Float(r.arguments["temperature"] ?? "invalidNumber"),
         let tint = Float(r.arguments["tint"] ?? "invalidNumber")
```

## How it works

When the app first starts, it will start the web server on port 8080. If the phone is connected to a LAN network, the user can access this endpoint using `http://<PHONE_LAN_HOST>`. Here, a basic and lagging UI (in terms of development in relations to the APIs exposed) is available. To use the APIs directly, you can enter in `http://<PHONE_LAN_HOST>/cameras` to get all the cameras available on the phone. A link to the controls will be shown on the screen and will also be shown in Xcode's Output window if you're building the project.

The app is built with the assumption that Metalkit effects will be added in the future (chroma-key, filters, etc.). In `CameraViewController.swift`, you can find a similar block as below

```swift
cameraCapture = CameraCapture(cameraPosition: .back, processingCallback: { [unowned self] (image) in
   guard let image = image else { return }

   // isUsingFilters defined before viewDidLoad()
   if self.isUsingFilters {
      // You can use CIFilters here.
      let filter = CIFilter.colorMonochrome()
      filter.intensity = 1
      filter.color = CIColor(red: 0.5, green: 0.5, blue: 0.5)
      filter.inputImage = image
      guard let output = filter.outputImage else { return }
      self.metalView.image = output
      NDIControls.instance.send(image: output)
   } else {
      self.metalView.image = image
      NDIControls.instance.send(image: image)
   }
})
```

In this block, you can chain CIFilters and build some cool effects. 

![output3](https://user-images.githubusercontent.com/5768361/97207673-9f32bf80-17fd-11eb-8cd6-9b5ed8791038.gif)

You'll need a high-speed network connection and an Apple device capable of MetalKit 2.

## How to build

1. Get the SDK from the [NDI SDK](https://www.ndi.tv/sdk/) site and install it (using `4.6` as of Feb/2021).
2. Copy `module.map` into `/Library/NDI SDK for Apple/include`.
4. Open the top-level `NDISenderExample.xcworkspace` in Xcode, select the `NDISenderExample` schema, and run it. The project expects to find `libndi_ios.a` in `/Library/NDI SDK for Apple/lib/iOS/libndi_ios.a`.
5. Tap the Send button on the screen to start sending with NDI.

## Help out

Check the issues list for known issues.

## Acknowledgement

Base NDI bridge based on `satoshi0212`'s [example](https://github.com/satoshi0212/NDISenderExample).
