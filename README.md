# NucleusSwift

Analytics, licensing and bug reports for Swift MacOS applications.

We made it as simple as possible to report the data you need to analyze your app and improve it.

To start using this package, sign up and get an app ID on [Nucleus.sh](https://nucleus.sh). 


* Make sure to check enable both "Incoming and outgoing connections" for your app in XCode under "Signing & Capabilities" * 

If you have a server-side Swift application, or maybe a cross-platform (for example Linux & macOS) app/library, and you would like to log, we think targeting this logging API package is a great idea. Below you'll find all you need to know to get started.

## Usage


Sign up and get a tracking ID for your app [here](https://nucleus.sh).

```swift
.package(url: "https://github.com/nucleus-sh/NucleusSwift.git", from: "1.0.0"),
```

and to your application/library target, add "NucleusSwift" to your dependencies, e.g. like this:
```swift
.target(name: "ExampleApp", dependencies: ["NucleusSwift"]),
```

###

In AppDelegate, import the library

```swift
import NucleusSwift
Nucleus.shared.setup("my-app-id")

...
func applicationDidFinishLaunching(_ aNotification: Notification) {
    ...
    Nucleus.shared.appStarted()
}
```

Then you can use the module from anywhere in your app:

```swift
Nucleus.shared.track("BTN-CLICKED")

Nucleus.shared.setUserId("richard_hendrix")
```

#### Debugging
If you are having troubles with the module it can be useful to enable logging:
```swift
Nucleus.shared.debug = true
```

### Identify your users

You can track specific users actions on the 'User Explorer' section of your dashboard.

For that, you can supply an `userId` when initing the Nucleus module. 

It can be your own generated ID, an email, username... etc.

```swift
Nucleus.shared.setUserId("someUniqueUserId")
```


### Add properties

You can report custom data along with the automatic data.
 
Those will be visible in your user dashboard if you previously set an user ID.

The module will remember past properties so you can use `Nucleus.shared.setProps` multiple times without overwriting past props.

Properties can either **numbers**, **strings** or **booleans**. 
Nested properties or arrays aren't supported at the moment.

```swift
Nucleus.shared.setProps([
    "age": 34,
    "name": "Richard Hendricks",
    "jobType": "CEO"
])
```

Enable overwrite: set the second parameter as true to overwrite past properties. 

```swift
Nucleus.shared.setProps([
    "age": 23
], overwrite: true)
```

### Events

After initializing Nucleus, you can report your own custom events.

```javascript
Nucleus.shared.track("PLAYED_TRACK")
```

They are a couple event names that are reserved by Nucleus: `init`, `error:` and `nucleus:`. Don't report events containing these strings.

#### Attach more data

You can also add extra information to tracked events. Properties can either **numbers**, **strings** or **booleans**. 
Nested properties or arrays aren't supported at the moment.

Example
```javascript
Nucleus.track("PLAYED_TRACK", [
    "trackName": "My Awesome Song",
    "duration": 120
])
```

### Errors

You can catch and report errors. That can be useful to debug what went wrong once your app is deployed in production.

You need to supply an ID and a message to your errors. The package will extract a stracktrace that you will be able to see in your dashboard.
 
Example
```javascript
Nucleus.shared.trackError(id: "API-ERROR", message: "Missing required parameter")
```

### Toggle tracking

This will completely disable any communication with Nucleus' servers.

To opt-out your users from tracking, use the following methods:

```swift
Nucleus.shared.disableTracking()
```

and to opt back in:

```swift
Nucleus.shared.enableTracking()
```

This change won't persist after restarts so you have to handle the saving of the settings.


---
Contact **hello@nucleus.sh** for any inquiry
