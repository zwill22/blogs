# Creating a Swift interface to a C++ library
*Z. Williams - 20th December 2024*

I have recently been trying to create a
[new iOS app to track Bus locations in real-time](https://github.com/zwill22/BusTracker.git). This app uses an
[AWS API Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/welcome.html)
to retreive real-time bus locations.
I have created a C++ library 
[OpenID repository](https://github.com/zwill22/OpenID.git)
to handle authorisation requests in order to access the
API. This library uses the
[AWS-SDK-CPP](https://aws.amazon.com/developer/language/cpp)
to interact with the server.

However, in order to use this in my app, I need to create a C
interface. In this article, I discuss how to setup a C header file
and library which may be imported into Swift. In a [recent article](linking.md), I covered the process of linking this library into XCode.
Here I am more interested in the C header, the underlying C++ code, and the Swift interface. 

## The OpenID C++ library

The OpenID library may be accessed via the header
[`OpenID.hpp`](https://github.com/zwill22/OpenID/blob/main/include/OpenID.hpp)
which exposes two classes and two structs. The simplest of these is
the [`OpenID::APIClient`](https://github.com/zwill22/OpenID/blob/main/src/APIClient.hpp) which must always be initialised calling
any other methods. It contains a simple constructor and destructor:
```cpp
// APIClient.hpp
class APIClient {
    public:
    APIClient();
    ~APIClient();

    private:
    //...
};
```
The core of the library is the `IDProvider` class which provides all the
methods necessary to create an account and request authentication.
```cpp
// IDProvider.hpp
class IDProvider {
public:
    IDProvider(const IDSettings &idSettings);

    ~IDProvider();

    void signUpUser() const;
    void verifyUser(const std::string & confirmationCode) const;
    void resendCode() const;

    Authentication passwordAuthenticate() const;

    void deleteUser(const Authentication & authentication) const;

private:
    // ...
};
```
This can be initialised with a struct `IDSettings`, which contains all
the necessary settings:
```cpp
struct IDSettings {
    std::string userID;
    std::string password;
    std::string emailAddress;
    std::string clientRegion;
    std::string clientID;
};
```
Finally, when the user requests authentication using the 
`passwordAuthenticate()` method, the class returns a `Authentication`
struct
```cpp
struct Authentication {
    std::string accessToken;
    size_t expiryTime;
    std::string idToken;
    std::string refreshToken;
    std::string tokenType;
};
```
which contains all the authentication tokens necessary to access the API.

Now that we know what the C++ API looks like, it is time to create a C version.

## Translating a C++ API to a C API

Firstly, we need to consider what we want to do with the C API.
The answer is "the same as with the C++ API!". In the C++ API, after initialising the
`APIClient`, we input some identity data to `IDSettings` which in turn is used to
initialise `IDProvider` so that we may call its public methods and eventually get
an `Authentication` result struct from which we can access all members. 
Finally, when the program terminates, the classes and structs are deleted by the 
program. This final part is done automatically in C++ but not in C!

A C API must be able to:
- Initialise and store an `APIClient` in memory and delete it
when finished. 
- Take identity data and use it to initialise an `IDProvider` in memory
- Use the `IDProvider` members
- Delete the `IDProvider` when finished
- Generate authentication and allow access to each member.
- Hide the C++ layer

Since the aim is to use this library in Swift, the final point is important, since 
Swift cannot interact with C++ directly. Exposing the `IDSettings` struct
is unnecessary for the C API since it functions as intermidiate storage for
multiple strings.

## OpenID C API

The OpenID C API is contained in the header file
[`OpenID.h`](https://github.com/zwill22/OpenID/blob/main/include/OpenID.h)
```C
// OpenID.h
#include <stdbool.h>
#include <stddef.h>

// C-header for OpenID library

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

bool initialiseOpenIDClient(void* openIDClient);
bool uninitialiseOpenIDClient(void* openIDClient);
size_t openIDClientSize();

bool initialiseOpenIDProvider(
    void * idProvider,
    const char * userID,
    const char * password,
    const char * emailAddress,
    const char * clientRegion,
    const char * clientID
);
bool uninitialiseOpenIDProvider(void* idProvider);
size_t idProviderSize();

bool signUpUser(const void * idProviderPtr);
bool verifyUser(const void * idProviderPtr, const char * confirmationCode);
bool resendCode(const void * idProviderPtr);

bool authenticate(void* authentication, void * idProviderPtr);
size_t authenticationSize();

char* getAccessToken(void * authenticationPtr);
int getExpiryTime(void * authenticationPtr);
char* getIDToken(void * authenticationPtr);
char* getRefreshToken(void * authenticationPtr);
char* getTokenType(void * authenticationPtr);

bool deleteUser(const void * idProviderPtr, const void * authenticationPtr);

#ifdef __cplusplus
}
#endif // __cplusplus
```
If this were to be used in C++ instead of the C++ header, it is necessary to let the
compiler know that this is C code, hence the `extern "C"` command.

For the `OpenIDClient` three functions are provided. Firstly, `openIDClientSize()` which calculates the 
amount of memory needed for an `OpenID::APIClient`. This should be used to allocate memory at pointer
`openIDClient`, which should then be passed to `initialiseOpenIDClient()` which constructs am `OpenID::APIClient`
in this location. Finally, `uninitialiseOpenIDClient()` should be used to call the `OpenID::APIClient` destructor
once the class is no longer needed. After calling this, the memory should be deallocated.

Similarly for the `IDProvider` class, the memory must be allocated before initialising the class and deallocated after
the uninitialiser is called. 
Each of the `IDProvider` member functions are included with the functions returning `true` on success. 
For the `Authentication` class, the memory must be allocated and deallocated before and after use.

Finally, 5 accessor functions are included to retreive the members of `Authentication` from memory.
In this form, the library may be accessed by numerous languages but there are no safeguards against
undefined behaviour, such as calling an accessor function when the `authenticationPtr` has not been
properly initialised. This responibility is passed to the user of the library.

## Implementation

So what does the underlying implementation look like? 
Firstly, although the header is in C code, the implementation is C++. Secondly, I am not going to go through all
of these here but rather focus on a couple which illustrate the idea of how they work. For more details, see the 
[CPP file](https://github.com/zwill22/OpenID/blob/main/src/Interface.cpp).

Firstly, the size functions simply compute the size of an object
```cpp
size_t openIDClientSize() {
    return sizeof(APIClient);
}
```
this can then be used to allocate memory at a pointer `openIDClient`. This pointer is then passed to the initialiser
```cpp
bool initialiseOpenIDClient(void* openIDClient) {
    try {
        new (openIDClient) APIClient();
        return true;
    } catch (const std::exception & e) {
        std::cerr << "Error: " << e.what() << '\n';
        return false;
    }
}
```
which creates a new `OpenID::APIClient` at location `openIDClient` and returns true if successful. Any exceptions thrown
by the C++ library must be caught with the return value indicating success or failure. 
Finally, the unininitiser is called once the client is no longer needed. 
```cpp
bool uninitialiseOpenIDClient(void* openIDClient) {
    try {
        const APIClient* apiClient = (APIClient*) openIDClient;

        apiClient->~APIClient();

        return true;
    } catch (const std::exception & e) {
        std::exception_ptr p = std::current_exception();
        std::cerr << "Error: " << e.what() << '\n';
        return false;
    }
}
```
This calls the `OpenID::APIClient` destructor.

The initialisation functions for the other objects are similar. While the other member functions follow similar
logic to the unininitiser, converting the raw pointer to a pointer of the class type and then calling the
class member function.

## Example usage

Before discussing any Swift usage, I would just like to show how these functions may be used from C++.
Obviously in this case, any C++ use case should use the C++ API but it can use this version instead.
Let's run through an example C++ `main` function, the full example file is available
[here](https://github.com/zwill22/OpenID/blob/main/examples/CInterface.cpp).
Firstly, we need to allocate and initialise the API Client:
```cpp
void * apiClient = alloca(openIDClientSize());
if (!initialiseOpenIDClient(apiClient)) {
    return 1;
}
```
Then initialise the `idProvider` using the necessary strings:
```cpp
const std::string userID = "MyName";
const std::string password = "NoneOfYourBusiness#123";
const std::string emailAddress = "me@email.com";
const std::string clientRegion = "eu-west-2"; // UK
const std::string clientID = "qwertyuiopasdfghjk"; // ID of AWS Cognito client

// Initialise ID Provider
void * idProvider = alloca(idProviderSize());
const auto success = initialiseOpenIDProvider(
    idProvider,
    userID.c_str(),
    password.c_str(),
    emailAddress.c_str(),
    clientRegion.c_str(),
    clientID.c_str()
);
if (!success) {
    return 1;
}
```
If this is successful, then the `idProvider` may be used to call the other member functions. 
If the user has not already been signed up, they can sign up and verify their account. 
Once verified, they may then request authentication using the `passwordAuthenticate()` function.
```cpp
void * authentication = alloca(authenticationSize());
if (!authenticate(authentication, idProvider)) {
    return 1;
}
```
If successful, the authentication allows access to the main Bus API. Additionally, it may be
used to delete the account. In order, to use the authentication codes in a function they must
be extracted from the `authentication` pointer, for example:
```cpp
const std::string accessToken = getAccessToken(authentication);
if (accessToken.size() == 0) {
    return 1;
}
```
In this way the result may be saved for future use.
Once the user has finished, the `APIClient` and `IDProvider` must be properly deleted, using:
```cpp
if (!uninitialiseOpenIDClient(apiClient)) {
    return 3;
}
if (!uninitialiseOpenIDProvider(idProvider)) {
    return 3;
}

free(apiClient);
free(idProvider);
```
Similarly, the memory associated with `authentication` must also be freed.
```cpp
free(authentication);
```

This  example shows how to make use of the library in a separate program.
However, in our case we wish to use the library in Swift.

## Swift Interface

I wish to reiterate that wrote a [separate article](linking.md) about linking the OpenID library to Swift.
This is about building the Swift code which calls the C interface.
However, I will repeat a couple of points where relevent.

Assuming the OpenID C interface has been built and been imported into the Swift project,
the first requirement is an Objective-C bridging header. This imports the C header and
exposes it to Swift. In our case this is simple:
```objC
// Bridging-header.h
#import "OpenID.h"
```
To use the library effectively in Swift, it is necessary to reconstruct the features of the `OpenID::IDProvider` class in Swift.
```Swift
import Foundation

class IDProvider {
    fileprivate let clientPtr: UnsafeMutableRawPointer
    fileprivate let idProviderPtr: UnsafeMutableRawPointer
    fileprivate let authenticationPtr: UnsafeMutableRawPointer
    var authenticated: Bool
    
    init(
        userID: String,
        password: String,
        emailAddress: String,
        clientRegion: String,
        clientID: String
    ) {
        // ...
    }
    
    // ...
}
```
Similar the `OpenID::IDProvider` class, the initialisator uses the `IDSettings` to create an instance of the class.
This class holds the pointers to the C++ classes from OpenID, which must be initialised. All three are stored as
`fileprivate` members to prevent access from outside the class or outside the file of use.
For `clientPtr`,
```Swift
let clientSize = openIDClientSize();
clientPtr = UnsafeMutableRawPointer.allocate(
    byteCount: clientSize,
    alignment: MemoryLayout<UnsafeMutableRawPointer>.alignment
);
let success = initialiseOpenIDClient(clientPtr);
if (!success) {
    throw IDError.openIDError(error: "Initialisation of OpenID Client failed");
}
```
similar to the C++ example, the `clientSize` is used to allocate memory for `clientPtr` then the C function
`initialiseOpenIDClient()` is called and checked for errors.

The `idProviderPtr` is initialised in a similar way as `clientPtr`, while the `authenticationPtr` only requires the memory to
be allocate. Most of the other functions may called in a similar way with the functions called directly from Swift.
The verification function `verifyUser()` requires an input string which must be passed to C as a `char*`, this may be
done using;
```Swift
func verify(authenticationCode: String) throws {
    var success = true;
    let string = authenticationCode.cString(using: .utf8)!;
    string.withUnsafeBytes { (authenticationCodePtr) in
        success = verifyUser(idProviderPtr, authenticationCodePtr.baseAddress!);
    }
        
    if (!success) {
        throw IDError.openIDError(error: "OpenID user verification failed");
    }
}
```
which converts the `String` into a `cString` and then passes the address to the function.

In addition to the `IDProvider` class, an `Authentication` struct is useful for storing the results of the authentication process.
```Swift
func getAuthentication() throws -> Authentication {
    if (!authenticated) {
        try requestAuthentication();
    }
    
    let accessToken = String(cString: getAccessToken(authenticationPtr));
    let expiryTime = Int(getExpiryTime(authenticationPtr));
    let idToken = String(cString: getIDToken(authenticationPtr));
    let refreshToken = String(cString: getRefreshToken(authenticationPtr));
    let tokenType = String(cString: getTokenType(authenticationPtr));
    
    return Authentication(
        accessToken: accessToken,
        expiryTime: expiryTime,
        idToken: idToken,
        refreshToken: refreshToken,
        tokenType: tokenType);
}
```
Here, the results of the accessor functions are converted to `String` types and then passed to the
struct. Finally, the class must include a deinitialiser to clean-up the pointers and call their destructors.
This may be performed using:
```Swift
deinit {
    uninitialiseOpenIDClient(clientPtr);
    uninitialiseOpenIDProvider(idProviderPtr);
    clientPtr.deallocate();
    idProviderPtr.deallocate();
    authenticationPtr.deallocate();
}
```
Now the class may be used in other Swift code and apps to authenticate users in an AWS Cognito User Pool.

## Summary

Having built a C++ library, I wished to use it in other programming languages such as Swift. I therefore created
a C API for the library which may be included in other code. This API loses the object-orientated structure of 
the C++ code but may be rebuilt in the other language. Abstracting this away exposes raw pointers which must be
properly managed. I have then shown how to use the interface to create another C++ program and build a Swift
class to replicate the functionality of the original C++ class in Swift. This may now be used in a Swift project.
