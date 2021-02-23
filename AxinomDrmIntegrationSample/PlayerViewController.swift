//
//  PlayerViewController.swift
//  AxinomDrmIntegrationSample
//
//  Copyright © 2021 Axinom. All rights reserved.
//
 
import UIKit
import AVKit
 
class PlayerViewController: AVPlayerViewController, AVContentKeySessionDelegate {
    
    // Certificate Url
    let fpsCertificateUrl: String = "CERTIFICATE_URL"
    
    // Licensing Token
    let licensingToken: String = "DRM-TOKEN-VALUE"
 
    // Licensing Service Url
    let licensingServiceUrl: String = "https://drm-fairplay-licensing.axtest.net/AcquireLicense"
     
    // Video url
    let videoUrl: String = "https://media.axprod.net/VTB/DrmQuickStart/AxinomDemoVideo-SingleKey/Encrypted_Cbcs/Manifest.m3u8"
    
    // Certificate data
    var fpsCertificate:Data!
    
    // Content Key session
    var contentKeySession: AVContentKeySession!
    
    // URLSession
    let urlSession = URLSession(configuration: .default)
 
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /*
         Creates Content Key Session.
        */
        contentKeySession = AVContentKeySession(keySystem: .fairPlayStreaming)
        
        /*
         Set our PlayerViewController as a delegate
        */
        contentKeySession.setDelegate(self, queue: DispatchQueue(label: "\(Bundle.main.bundleIdentifier!).ContentKeyDelegateQueue"))
        
        prepareAndPlay()
    }
    
    func prepareAndPlay() {
        /*
         Create URL instance.
        */
        guard let assetUrl = URL(string: self.videoUrl) else {
            return
        }
        
        /*
         Initialize AVURLAsset.
        */
        let asset: AVURLAsset = AVURLAsset(url: assetUrl)
        
        /*
         Link AVURLAsset to Content Key Session.
        */
        contentKeySession.addContentKeyRecipient(asset)
        
        /*
         Initialize AVPlayerItem with AVURLAsset.
        */
        let playerItem = AVPlayerItem(asset: asset)
        
        /*
         Initialize AVPlayer with AVPlayerItem.
        */
        let player:AVPlayer = AVPlayer(playerItem: playerItem)
        
        /*
         Pass AVPlayerViewController a reference to the player.
        */
        self.player = player
     
        /*
         Start playback.
        */
        player.play()
    }
 
    /*
     The following delegate callback gets called when the client initiates a key request or AVFoundation
     determines that the content is encrypted based on the playlist the client provided when it requests playback.
    */
    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        
        /*
         Parse ContentId from keyRequest and capture everything after "sdk://"
        */
        guard let contentKeyIdentifierString = keyRequest.identifier as? String,
        /*
          Capture everything after "sdk://" from #EXT-X-SESSION-KEY "URI" parameter.
        */
        let contentIdentifier = contentKeyIdentifierString.replacingOccurrences(of: "skd://", with: "") as String?,
        
        /*
          Convert contentIdentifier to Unicode string (utf8)
        */
        let contentIdentifierData = contentIdentifier.data(using: .utf8) else {
           print("ERROR: Failed to retrieve the contentIdentifier from the keyRequest!")
           return
        }
        
        /*
         Completion handler for makeStreamingContentKeyRequestData method.
         1. Sends obtained SPC to Key Server
         2. Receives CKC from Key Server
         3. Makes content key response object (AVContentKeyResponse)
         4. Provide the content key response object to make protected content available for processing
        */
        let getCkcAndMakeContentAvailable = { [weak self] (spcData: Data?, error: Error?) in
            guard let strongSelf = self else { return }
            
            if let error = error {
                print("ERROR: Failed to prepare SPC: \(error)")
                
                /*
                 Obtaining an SPC has failed. Report error to AVFoundation.
                */
                keyRequest.processContentKeyResponseError(error)
                return
            }
 
            guard let spcData = spcData else { return }
 
            /*
             Send SPC to Key Server and obtain CKC.
            */
            guard let url = URL(string: strongSelf.licensingServiceUrl) else {
                print("ERROR: missingLicensingServiceUrl")
                return
            }
            
            /*
             Before sending an SPC to Key Server (KSM) we need to set provided Licensing Token to "X-AxDRM-Message" HTTP header.
            */
            var ksmRequest = URLRequest(url: url)
            ksmRequest.httpMethod = "POST"
            ksmRequest.setValue(strongSelf.licensingToken, forHTTPHeaderField: "X-AxDRM-Message")
            ksmRequest.httpBody = spcData
            
            var dataTask: URLSessionDataTask?
            
            dataTask = self!.urlSession.dataTask(with: ksmRequest, completionHandler: { (data, response, error) in
                defer {
                    dataTask = nil
                }
                
                if let error = error {
                    print("ERROR: Error getting CKC: \(error.localizedDescription)")
                } else if
                    let ckcData = data,
                    let response = response as? HTTPURLResponse,
                    response.statusCode == 200 {
                    
                    /*
                     AVContentKeyResponse is used to represent the data returned from the key server when requesting a key for
                     decrypting content.
                     */
                    let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckcData)
 
                    /*
                     Provide the content key response to make protected content available for processing.
                    */
                    keyRequest.processContentKeyResponse(keyResponse)
                }
            })
        
            dataTask?.resume()
        }
       
        do {
            let applicationCertificate = try requestApplicationCertificate()
            
            /*
             Pass Content Id Unicode string together with FPS Certificate to obtain an SPC for a specific combination of application and content.
            */
            keyRequest.makeStreamingContentKeyRequestData(forApp: applicationCertificate,
                                                          contentIdentifier: contentIdentifierData,
                                                          options: [AVContentKeyRequestProtocolVersionsKey: [1]],
                                                          completionHandler: getCkcAndMakeContentAvailable)
        }
        catch {
            keyRequest.processContentKeyResponseError(error)
        }
    }
    
    /*
     Requests Application Certificate.
    */
    func requestApplicationCertificate() throws -> Data {
        var applicationCertificate: Data? = nil
        
        do {
            applicationCertificate = try Data(contentsOf: URL(string: fpsCertificateUrl)!)
        } catch {
            print("Error loading FairPlay application certificate: \(error)")
        }
        
        return applicationCertificate!
    }
}
