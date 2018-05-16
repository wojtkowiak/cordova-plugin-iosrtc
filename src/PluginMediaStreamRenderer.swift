import Foundation
import AVFoundation


class PluginMediaStreamRenderer : NSObject, RTCEAGLVideoViewDelegate {
	var webView: UIView
	var eventListener: (_ data: NSDictionary) -> Void
	var elementView: UIView
	var videoView: RTCEAGLVideoView
	var pluginMediaStream: PluginMediaStream?
	var rtcAudioTrack: RTCAudioTrack?
	var rtcVideoTrack: RTCVideoTrack?


	init(
		webView: UIView,
		eventListener: @escaping (_ data: NSDictionary) -> Void
	) {
		NSLog("PluginMediaStreamRenderer#init()")

		// The browser HTML view.
		self.webView = webView
		self.eventListener = eventListener
		// The video element view.
		self.elementView = UIView()
		// The effective video view in which the the video stream is shown.
		// It's placed over the elementView.
		self.videoView = RTCEAGLVideoView()

		self.elementView.isUserInteractionEnabled = false
		self.elementView.isHidden = true
		self.elementView.backgroundColor = UIColor.black
		self.elementView.addSubview(self.videoView)
		self.elementView.layer.masksToBounds = true

		self.videoView.isUserInteractionEnabled = false

		// Place the video element view inside the WebView's superview
		self.webView.superview?.addSubview(self.elementView)
	}


	deinit {
		NSLog("PluginMediaStreamRenderer#deinit()")
	}


	func run() {
		NSLog("PluginMediaStreamRenderer#run()")

		self.videoView.delegate = self
	}


	func render(_ pluginMediaStream: PluginMediaStream) {
		NSLog("PluginMediaStreamRenderer#render()")

		if self.pluginMediaStream != nil {
			self.reset()
		}

		self.pluginMediaStream = pluginMediaStream

		// Take the first audio track.
		for (_, track) in pluginMediaStream.audioTracks {
			self.rtcAudioTrack = track.rtcMediaStreamTrack as? RTCAudioTrack
			break
		}

		// Take the first video track.
		for (_, track) in pluginMediaStream.videoTracks {
			self.rtcVideoTrack = track.rtcMediaStreamTrack as? RTCVideoTrack
			break
		}

		if self.rtcVideoTrack != nil {
			self.rtcVideoTrack!.add(self.videoView)
		}

        
       self.listenForUnpluggedHeadphones()  // OVERRIDE : Checks if headphones are connected and creates an event listener to re-set to the
                                            // louder SPEAKER setting (rather than the quiter EARPIECE setting) if headphones are unplugged or to
                                            // NONE (defalt setting allowing headphones) if headphones are plugged in - SHANE

	}


	func mediaStreamChanged() {
		NSLog("PluginMediaStreamRenderer#mediaStreamChanged()")

		if self.pluginMediaStream == nil {
			return
		}

		let oldRtcVideoTrack: RTCVideoTrack? = self.rtcVideoTrack

		self.rtcAudioTrack = nil
		self.rtcVideoTrack = nil

		// Take the first audio track.
		for (_, track) in self.pluginMediaStream!.audioTracks {
			self.rtcAudioTrack = track.rtcMediaStreamTrack as? RTCAudioTrack
			break
		}

		// Take the first video track.
		for (_, track) in pluginMediaStream!.videoTracks {
			self.rtcVideoTrack = track.rtcMediaStreamTrack as? RTCVideoTrack
			break
		}

		// If same video track as before do nothing.
		if oldRtcVideoTrack != nil && self.rtcVideoTrack != nil &&
			oldRtcVideoTrack!.label == self.rtcVideoTrack!.label {
			NSLog("PluginMediaStreamRenderer#mediaStreamChanged() | same video track as before")
		}

		// Different video track.
		else if oldRtcVideoTrack != nil && self.rtcVideoTrack != nil &&
			oldRtcVideoTrack!.label != self.rtcVideoTrack!.label {
			NSLog("PluginMediaStreamRenderer#mediaStreamChanged() | has a new video track")

			oldRtcVideoTrack!.remove(self.videoView)
			self.rtcVideoTrack!.add(self.videoView)
		}

		// Did not have video but now it has.
		else if oldRtcVideoTrack == nil && self.rtcVideoTrack != nil {
			NSLog("PluginMediaStreamRenderer#mediaStreamChanged() | video track added")

			self.rtcVideoTrack!.add(self.videoView)
		}

		// Had video but now it has not.
		else if oldRtcVideoTrack != nil && self.rtcVideoTrack == nil {
			NSLog("PluginMediaStreamRenderer#mediaStreamChanged() | video track removed")

			oldRtcVideoTrack!.remove(self.videoView)
		}
	}


	func refresh(_ data: NSDictionary) {
		let elementLeft = data.object(forKey: "elementLeft") as? Float ?? 0
		let elementTop = data.object(forKey: "elementTop") as? Float ?? 0
		let elementWidth = data.object(forKey: "elementWidth") as? Float ?? 0
		let elementHeight = data.object(forKey: "elementHeight") as? Float ?? 0
		var videoViewWidth = data.object(forKey: "videoViewWidth") as? Float ?? 0
		var videoViewHeight = data.object(forKey: "videoViewHeight") as? Float ?? 0
		let visible = data.object(forKey: "visible") as? Bool ?? true
		let opacity = data.object(forKey: "opacity") as? Float ?? 1
		let zIndex = data.object(forKey: "zIndex") as? Float ?? 0
		let mirrored = data.object(forKey: "mirrored") as? Bool ?? false
		let clip = data.object(forKey: "clip") as? Bool ?? true
		let borderRadius = data.object(forKey: "borderRadius") as? Float ?? 0

		NSLog("PluginMediaStreamRenderer#refresh() [elementLeft:%@, elementTop:%@, elementWidth:%@, elementHeight:%@, videoViewWidth:%@, videoViewHeight:%@, visible:%@, opacity:%@, zIndex:%@, mirrored:%@, clip:%@, borderRadius:%@]",
			String(elementLeft), String(elementTop), String(elementWidth), String(elementHeight),
			String(videoViewWidth), String(videoViewHeight), String(visible), String(opacity), String(zIndex),
			String(mirrored), String(clip), String(borderRadius))

		let videoViewLeft: Float = (elementWidth - videoViewWidth) / 2
		let videoViewTop: Float = (elementHeight - videoViewHeight) / 2

		self.elementView.frame = CGRect(
			x: CGFloat(elementLeft),
			y: CGFloat(elementTop),
			width: CGFloat(elementWidth),
			height: CGFloat(elementHeight)
		)

		// NOTE: Avoid a zero-size UIView for the video (the library complains).
		if videoViewWidth == 0 || videoViewHeight == 0 {
			videoViewWidth = 1
			videoViewHeight = 1
			self.videoView.isHidden = true
		} else {
			self.videoView.isHidden = false
		}

		self.videoView.frame = CGRect(
			x: CGFloat(videoViewLeft),
			y: CGFloat(videoViewTop),
			width: CGFloat(videoViewWidth),
			height: CGFloat(videoViewHeight)
		)

		if visible {
			self.elementView.isHidden = false
		} else {
			self.elementView.isHidden = true
		}

		self.elementView.alpha = CGFloat(opacity)
		self.elementView.layer.zPosition = CGFloat(zIndex)

                // if the zIndex is 0 (the default) bring the view to the top, last one wins
                if zIndex == 0 {
			self.webView.superview?.bringSubview(toFront: self.elementView)
                }

		if !mirrored {
			self.elementView.transform = CGAffineTransform.identity
		} else {
			self.elementView.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
		}

		if clip {
			self.elementView.clipsToBounds = true
		} else {
			self.elementView.clipsToBounds = false
		}

		self.elementView.layer.cornerRadius = CGFloat(borderRadius)
	}


	func close() {
		NSLog("PluginMediaStreamRenderer#close()")

		self.reset()
		self.elementView.removeFromSuperview()
	}


	/**
	 * Private API.
	 */


	fileprivate func reset() {
		NSLog("PluginMediaStreamRenderer#reset()")

		if self.rtcVideoTrack != nil {
			self.rtcVideoTrack!.remove(self.videoView)
		}

		self.pluginMediaStream = nil
		self.rtcAudioTrack = nil
		self.rtcVideoTrack = nil
	}


	/**
	 * Methods inherited from RTCEAGLVideoViewDelegate.
	 */


	func videoView(_ videoView: RTCEAGLVideoView!, didChangeVideoSize size: CGSize) {
		NSLog("PluginMediaStreamRenderer | video size changed [width:%@, height:%@]",
			String(describing: size.width), String(describing: size.height))

		self.eventListener([
			"type": "videoresize",
			"size": [
				"width": Int(size.width),
				"height": Int(size.height)
			]
		])
	}
    
    //OVERRIDE
    // Checks if headphones are connected and creates an event listener to re-set to the
    // louder SPEAKER setting (rather thant he quiter EARPIECE) if headphones are unplugged or to
    // NONE (defalt setting allowing headphones) if headphones are plugged in - SHANE
    
    func listenForUnpluggedHeadphones() { //event listener: for looking for plugged or un-plugged headphones
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(checkForUnpluggedHeadphones),
                                               name: .AVAudioSessionRouteChange,
                                               object: AVAudioSession.sharedInstance())
    }
    
    func checkForUnpluggedHeadphones(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSessionRouteChangeReason(rawValue:reasonValue) else {
                return
        }
        switch reason {
        case .newDeviceAvailable:
            let session = AVAudioSession.sharedInstance()
            for output in session.currentRoute.outputs where output.portType == AVAudioSessionPortHeadphones {
                // headphonesConnected == true
                let audioSession = AVAudioSession.sharedInstance()
                print("setting audioSession to NONE (defalt allowing headphones)... ")
                do {
                    try audioSession.overrideOutputAudioPort(AVAudioSessionPortOverride.none)
                } catch {
                    print("ERROR setting audioSession to NONE")
                }
            }
        case .oldDeviceUnavailable:
            if let previousRoute =
                userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                for output in previousRoute.outputs where output.portType == AVAudioSessionPortHeadphones {
                    // headphonesConnected == false
                    
                    // OVERRIDES the default quiter EARPIECE setting when the headphones are disconnected
                    let audioSession = AVAudioSession.sharedInstance()
                    print("setting audioSession to SPEAKER... ")
                    do {
                        try audioSession.overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
                    } catch {
                        print("ERROR setting audioSession to SPEAKER")
                    }
                }
            }
        default: ()
        }
    }//END checkForUnpluggedHeadphones
    //END OVERRIDE

}
