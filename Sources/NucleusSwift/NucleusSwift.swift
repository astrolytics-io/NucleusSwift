import AppKit
import Starscream
import Foundation
import Codability

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


struct Event: Codable {
    var id: Int?
    var date: Date?
    var type: String
    var name: String?
    var appId: String?
    var machineId: String?
    var sessionId: Int?
    // Next is often omitted to save bandwidth
    var userId: String?
    var payload: [String:AnyCodable]?
    var client: String?
    var platform: String?
    var osVersion: String?
    var totalRam: Double?
    var version: String?
    var locale: String?
    var arch: String?
    var moduleVersion: String?
}


var platformName: String {
    #if os(OSX)
        return "macOS"
    #elseif os(watchOS)
        return "watchOS"
    #elseif os(tvOS)
        return "tvOS"
    #elseif os(iOS)
        #if targetEnvironment(macCatalyst)
            return "macOS"
        #else
            return "iOS"
        #endif
    #endif
}

var osVersionNumber: String {
    let osInfo = ProcessInfo().operatingSystemVersion
    return String(osInfo.majorVersion) + "." + String(osInfo.minorVersion)
}

public class NucleusClient {
	
    // Editable options
	public var appId: String
	public var debug: Bool? = false
	public var reportInterval: Int = 20
	public var apiUrl: String = "wss://app.nucleus.sh"

    // Internal variables
	var localData: [String: AnyCodable] = [:]
	var trackingOff = false
	var isConnected = false
    var sock: WebSocket?
    var websocket: WebSocketDelegate?
    var queue: [Event] = []
    var queueUrl = URL(string: "/")

    // Analytics data
    let locale: String = Locale.preferredLanguages[0]
    let platform: String = platformName
    let moduleVersion: String = "0.1.0"
    let osVersion: String = osVersionNumber
    let machineId: String? = serialNumber
    let totalRam: Double = Double(ProcessInfo().physicalMemory) / pow( 1024,  3)
    public var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    var sessionId: Int
    public var userId: String?
    
	public init(_ appId: String) {
		self.appId = appId
		// Find the analytics data
		self.sessionId = Int(arc4random_uniform(10000) + 1)

        // Set up cache storing
        self.initStore()

        let timer = Timer.scheduledTimer(timeInterval: TimeInterval(reportInterval), target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
	}
    
    @objc func fireTimer() {
        self.reportData()
    }
    
    public func track(name: String? = nil, data: [String: AnyCodable]? = nil, type: String = "event") {
 
		if trackingOff {
			return
		}

        self.log("reporting event "+(name ?? type) )

		// Generate a small temp id for this event, so when the server returns it
		// we can remove it from the queue
        
        var event = Event(
            id: Int(arc4random_uniform(10000) + 1),
            date: Date(),
            type: type,
            name: name,
            appId: self.appId,
            machineId: self.machineId,
            sessionId: self.sessionId,
            userId: self.userId,
            payload: data
        )

        // Only for these events to save bandwidth
		if type == "init" || type == "error" {
            event.client = "cocoa"
            event.platform = self.platform
            event.osVersion = self.osVersion
            event.totalRam = self.totalRam
            event.version = self.appVersion
            event.locale = self.locale
//                event.arch": self.localData['arch'],
            event.moduleVersion = self.moduleVersion
		}
        
        queue.append(event)
        
        self.log("queue is now "+String(queue.count))

        // Save to Userdefaults/Core Data
	}

	public func trackError(error: Error) {
        // Deep shit here
	}

	public func appStarted() {
		self.track(type: "init")
        self.reportData()
	}

	public func setUserId(id: String?) {
		self.userId = id
        self.log("user id set to " + id!)
		self.track(type: "userid")
	}
    
    public func disableTracking() {
        self.trackingOff = true
        self.log("tracking disabled")
    }
    
    public func enableTracking() {
        self.trackingOff = false
        self.log("tracking enabled")
    }

    func sendQueue() {
        
        if (!self.isConnected || self.sock == nil) {
            return
        }
        
        var toSend: [Event]
        
        if self.queue.isEmpty == false {
            toSend = self.queue
            
        } else {
            let heartbeat = Event(
                type: "heartbeat",
                machineId: self.machineId
            )
            
            toSend = [heartbeat]
        }
    
        let json: [String: [Event]] = [
            "data": toSend
        ]
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let jsonEncoded = try! encoder.encode(json)

        self.log("sending data to server")
        self.sock!.write(data: jsonEncoded)
    }
    
    func handleMessage(message: String) {
        let data = Data(message.utf8)
        
        let decoder = JSONDecoder()
        let parsed = try! decoder.decode([String:[Int]].self, from: data)
        
        print(parsed)
        
        self.queue = self.queue.filter { !(parsed["reportedIds"]?.contains($0.id!))! }
    
    }
    
    // This only runs at regular interval to save battery
    func reportData() {

        // Encode to JSON for file saving & ws communication
        
        let encoder = JSONEncoder()
        let jsonEncoded = try! encoder.encode(self.queue)
//        print(String(data: data, encoding: .utf8)!)
        
        self.log("saving queue")
        NSKeyedArchiver.archiveRootObject(jsonEncoded, toFile: self.queueUrl!.path)
        
        if (self.isConnected) {
            self.sendQueue()
        } else {
            self.log("Opening websocket connection")
            
            let request = URLRequest(url: URL(string: self.apiUrl + "/app/" + self.appId + "/track" )!)
            self.sock = WebSocket(request: request)
            self.sock!.delegate = self.websocket
		
            self.sock!.onEvent = { event in
			 	switch event {
			 		case .connected(let headers):
			 			self.isConnected = true
			 			self.log("websocket is connected: \(headers)")
                        self.sendQueue()
			 		case .disconnected(let reason, let code):
			 			self.isConnected = false
			 			self.logError("websocket is disconnected: \(reason) with code: \(code)")
			 		case .text(let string):
			 			self.log("Received text: \(string)")
                        handleMessage(message: string)
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
            
            self.sock!.connect()
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
            
            if fileManager.fileExists(atPath: self.queueUrl!.path) {
                let jsonData = NSKeyedUnarchiver.unarchiveObject(withFile: self.queueUrl!.path) // as? String ?? ""
                
                let decoder = JSONDecoder()
                self.queue = (jsonData != nil) ? try! decoder.decode([Event].self, from: jsonData as! Data) : [Event]()
            }
        } catch {
            // error
            print("Fail extracting")
        }
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
