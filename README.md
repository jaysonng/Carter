# Carter

Carter is a modern Swift Library to receive metadata and Open Graph information from URLs. 
\
Based on [Awkward/Ocarina](https://github.com/awkward/Ocarina) Library. Built on top of the Kanna Libraray

## Installation

### [Swift Package Manager](https://swift.org/package-manager/)

You can use The Swift Package Manager (SPM) to install Carter by going to 
"Project->NameOfYourProject->Swift Packages" and placing "https://github.com/jaysonng/Carter.git" in the 
search field.

## Requirements
- Swift 5.5
- iOS 15


## Synopsis
```swift
import Kanna

let url = URL(string: url)!
do {

    let urlInformation = try await url.carter.getURLInformation()
    // Do stuff here with the URLInformation object
    
} catch let error as CarterError {
    // No URLInformation object retrieved.
    print(error.description)
}
```


## Bonus
"You know, you blow up one sun and suddenly everyone expects you to walk on water."
\
&mdash; Lt. Col. Samantha Carter 
\
SG-1
