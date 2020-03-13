import AppKit
import Starscream
import Foundation

// import Cache

var serialNumber: String? {
	let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice") )
	
	guard platformExpert > 0 else {
		return nil
	}
	
	guard let serialNumber = (IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String) else {
		return nil
	}

	IOObjectRelease(platformExpert)
	return serialNumber
}

extension Dictionary {
    mutating func merge(dict: [Key: Value]){
        for (k, v) in dict {
            updateValue(v, forKey: k)
        }
    }
}



public class NucleusClient {
	
	public var appId: String
	public var debug: Bool? = false
//	public var autoUserId: Bool?
	public var reportInterval: Int = 10
	public var apiUrl: String = "wss://app.nucleus.sh"

	var localData: [String: Any] = [:]
	var trackingOff: Bool = false
	var isConnected: Bool = false
//    var sock: Any = nil
    var queue = [[String: Any]]()
    var queueUrl = URL(string: "/")

	public init(_ appId: String) {
		self.appId = appId

		let osInfo = ProcessInfo().operatingSystemVersion

		// Find the analytics data 
		self.localData["locale"] = Locale.preferredLanguages[0]
		self.localData["platform"] = "mac"
		self.localData["moduleVersion"] = "0.0.1"
		self.localData["osVersion"] = String(osInfo.majorVersion) + "." + String(osInfo.minorVersion)
		self.localData["totalRam"] = Double(ProcessInfo().physicalMemory) / pow( 1024,  3)
		self.localData["machineId"] = serialNumber
		self.localData["sessionId"] = arc4random_uniform(10000) + 1

        // Set up cache storing
        self.initStore()
		// Next open websocket connection
        
        var timer = Timer.scheduledTimer(timeInterval: TimeInterval(reportInterval), target: self, selector: Selector(("reportData")), userInfo: nil, repeats: true)

	}
    
	public func track(name: String, data: [String: Any]? = [:], type: String = "event") {
 
		if trackingOff {
			return
		}

		self.log("reporting event "+name)

		// Generate a small temp id for this event, so when the server returns it
		// we can remove it from the queue
		let tempId = arc4random_uniform(10000) + 1
		let date = Date()

		var eventData = [
			"type": type,
			"name": name,
			"date": date,
			"appId": self.appId,
			"id": tempId,
			"userId": self.localData["userId"],
			"machineId": self.localData["machineId"],
			"sessionId": self.localData["sessionId"],
			"payload": data
		]

		// Extra data is only needed for 1st event and errors so save bandwidth if not needed

		if name == "init" || name == "error" {

			let extraData = [
				"client": "cocoa",
				"platform": self.localData["osName"],
				"osVersion": self.localData["osVersion"],
				"totalRam": self.localData["ram"],
				"version": self.localData["version"],
				"locale": self.localData["locale"],
				// "arch": self.localData['arch'],
				"moduleVersion": self.localData["moduleVersion"]
			]

			eventData.merge(dict: extraData)
		}
        
        queue.append(eventData)
        
        self.log("queue is now "+String(queue.count))

        // Save to Userdefaults/Core Data
	}

	public func trackError(error: Error) {
        // Deep shit here
	}

	public func appStarted() {
		self.track(name: "init")
	}

	public func setUserId(id: String) {
		self.localData["user_id"] = id
		self.log("user id set to " + id)
		self.track(name: "userid")
	}
    
    public func disableTracking() {
        self.trackingOff = true
        self.log("tracking disabled")
    }
    
    public func enableTracking() {
        self.trackingOff = false
        self.log("tracking enabled")
    }

	func reportData() {
        
        // Only make it in reportData at regular interval to make sure we don't write too  much
        self.saveQueue()
        
        let request = URLRequest(url: URL(string: self.apiUrl)!)


        if (!self.isConnected) {
            let sock = WebSocket(request: request)
//            socket.delegate = self
            sock.connect()
		
            sock.onEvent = { event in
			 	switch event {
			 		case .connected(let headers):
			 			self.isConnected = true
			 			self.log("websocket is connected: \(headers)")
			 		case .disconnected(let reason, let code):
			 			self.isConnected = false
			 			self.logError("websocket is disconnected: \(reason) with code: \(code)")
			 		case .text(let string):
			 			self.log("Received text: \(string)")
			 		case .binary(let data):
			 			self.log("Received data: \(data.count)")
			 		case .ping(_):
			 			break
			 		case .pong(_):
			 			break
			 		case .viablityChanged(_):
			 			break
			 		case .reconnectSuggested(_):
			 			break
			 		case .cancelled:
			 			self.isConnected = false
			 		case .error(let error):
			 			self.isConnected = false
                        self.logError("Error with ws: \(String(describing: error))?")
			 	}
			 }
		}

	}
    
    func initStore() {
        do {
            let fileManager = FileManager.default
            let fileName = self.appId+".plist"
            let appSupportUrl = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            
            let directoryURL = appSupportUrl!.appendingPathComponent("sh.nucleus.swift")
            try fileManager.createDirectory (at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        
            self.queueUrl = directoryURL.appendingPathComponent(fileName)
            
            self.queue = NSKeyedUnarchiver.unarchiveObject(withFile: self.queueUrl!.path) as? [[String: Any]] ?? []
            
        //if (fileManager.fileExists(atPath: self.queueUrl!.path)) {
          //  self.log("temp data detected, loading from file")
           //self.queue = NSArray(contentsOf: self.queueUrl!) as [[String: Any]]
        //} else {
          //  self.log("No doc detected")
            
          //  document.write (to: self.queueUrl, ofType: "sh.nucleus.swift")
        //}
            
        }
        
        catch {
          print("An error occured")
        }
    }
    
    func saveQueue() {
        self.log("saving queue")
        NSKeyedArchiver.archiveRootObject(queue, toFile: self.queueUrl!.path)
        self.log("queue saved")
    }
    
    func log(_ message: String) {
        if (self.debug == true) {
            print("nucleus: "+message)
        }
    }

    func logError(_ message: String) {
        if (self.debug == true) {
            print("nucleus error: "+message)
        }
    }
} 

//NSSetUncaughtExceptionHandler { (exception) in
//    let stack = exception.callStackReturnAddresses
//    print("Stack trace: \(stack)")
//}

// NSException(name: "SomeName", reason: "SomeReason", userInfo: nil).raise()
