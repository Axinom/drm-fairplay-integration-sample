# Axinom DRM Integration Sample
 
The purpose of this sample application is to provide a minimal setup needed to use Axinom DRM with AVFoundation framework to play FairPlay protected HTTP Live Streams (HLS) hosted on remote servers.
 
You can use the example code provided in this sample to build your own application that integrates the Axinom DRM with AVFoundation.

Following steps are mandatory to play FairPlay protected HLS streams:

## 1. Prepare the Content Identifier parsed from the HLS manifest

* Parse Content Identifier from keyRequest provided by ```AVContentKeySessionDelegate``` in ```contentKeySession(_:didProvide:)``` and capture everything after "sdk://".

* Convert Content Identifier to Unicode string (utf8)

```swift
func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVPersistableContentKeyRequest) {    
    // Parse ContentId from keyRequest and capture everything after "sdk://"
    guard let contentKeyIdentifierString = keyRequest.identifier as? String,

    // Capture everything after "sdk://" from #EXT-X-SESSION-KEY "URI" parameter.
    let contentIdentifier = contentKeyIdentifierString.replacingOccurrences(of: "skd://", with: "") as String?,
    
    // Convert contentIdentifier to Unicode string (utf8)
    let contentIdentifierData = contentIdentifier.data(using: .utf8) else {
        print("ERROR: Failed to retrieve the contentIdentifier from the keyRequest!")
        return
    }
```
## 3. Request an FPS Certificate

The following code snippet shows how to retrieve FPS certificate from fpsCertificateUrl.

```swift
func requestApplicationCertificate() throws -> Data {
    var applicationCertificate: Data? = nil
    
    do {
        applicationCertificate = try Data(contentsOf: URL(string: fpsCertificateUrl)!)
    } catch {
        print("Error loading FairPlay application certificate: \(error)")
    }
    
    return applicationCertificate!
}
```

## 4. Obtain a Content Key Request data (SPC) 

Pass Content Identifier previously encoded as Unicode string together with FPS Certificate to ```keyRequest.makeStreamingContentKeyRequestData``` method to obtain a Content Key Request data (SPC) for a specific combination of application and content.


```swift
keyRequest.makeStreamingContentKeyRequestData(forApp: self.fpsCertificate,
                           contentIdentifier: contentIdentifierData,
                           options: [AVContentKeyRequestProtocolVersionsKey: [1]],
                           completionHandler: completionHandler)
}
```

## 5. Add Licensing Token to HTTP header of the Licensing Request

Before sending a Content Key Request (SPC) to Key Server (KSM) we need to set the Licensing Token to "X-AxDRM-Message" HTTP header.


```swift
var ksmRequest = URLRequest(url: url)
    ksmRequest.httpMethod = "POST"
    ksmRequest.setValue(licensingToken, forHTTPHeaderField: "X-AxDRM-Message")
    ksmRequest.httpBody = spcData
```

## Requirements
 
### Build
 
Xcode 11.0 or later; iOS 13.0 SDK or later
 
### Runtime
 
iOS 13.1 or later.