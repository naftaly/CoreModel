# CoreModel

[![Build Status](https://travis-ci.org/naftaly/CoreModel.svg?branch=master)](https://travis-ci.org/naftaly/CoreModel)

CoreModel is a lightweight framework that simplifies the process of converting your data to usable objects. The API allows you to quickly get data from anywhere and bring it into your app as instances of your objects.

## Installation

CoreModel is available on [CocoaPods](http://cocoapods.org). Just add the following to your project Podfile:

```ruby
pod 'CoreModel'
```

## Usage

First include it using the following import:

```objective-c
#import <CoreModel/CoreModel.h>
```

Find yourself some data from somewhere. Let's use some JSON data as this is the default handled by CoreModel:

`{ "firstName": "Alex", "lastName": "Cohen", "profession": "Developer", "age", 37, "married" : NO }`

Create a subclass of `CMModel`, let's call it `Person`:

```objective-c
 @interface Person : CMModel
 
 @property (strong) NSString* firstName;
 @property (strong) NSString* lastName;
 @property (strong) NSString* gender;
 @property (strong) NSString* profession;
 @property (assign) NSUInteger age;
 @property (assign) BOOL married;
 
 @end
 
 @implementation Employee
 @end
 ```
 
 Then just load it up:
 
 ```objective-c
 Person* person = [[Person alloc] initWithData:data error:nil];
 ```
 
 You now have a fully initialized instance of person filled in with your data.
 
## License

CoreModel is released under a MIT License. See LICENSE file for details.


