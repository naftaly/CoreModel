/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2016 Alexander Cohen
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 `CMModelAdapter` is a protocol that let's you change the underlying format of the data used in the `CMModel` class.
 
 For example, your data could be XML. 
 You would implement `CMModelAdapter` on your custom object in order to return property list objects.
 */
@protocol CMModelAdapter <NSObject>

@required

/**
 Returns a property list object ( usually an NSDictionary ) that represents your data.
 
 @param data The data you wish to represent as a property list object.
 @param error On output, an error if an error occured during the processing of the data.
 */
- (id _Nullable)modelAdapterPropertyListFromData:(NSData*)data error:(NSError* _Nullable * _Nullable)error;

@end

/**
 `CMModel` is a class that enables you to load your data into a model. By default, `CMModel` deals with JSON data. This can be changed by implementing `CMModelAdapter` and returning your implementation from + modelAdapter.
 
 ## Subclassing Notes
 
 For best results, subclass `CMModel` and add properties that relate back to your data.
 
 ## Methods to Override
 
 To change the behavior of `CMModel`, developers may override:
    + modelAdapter
    + modelKeyForClassRoot
    + modelPropertyNameForkey
    + modelClassForKey
    + modelConvertObject:toType:
    + modelConvertObject:toTypeEncoding:.
 
 ## Example
 
 Take this JSON data for example:
 
 { "firstName": "Alex", "lastName": "Cohen", "profession": "Developer", "age", 37, "married" : NO }
 
 Your class could resemble the following:
 
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
 
 Load it as follows:
 
 Person* person = [[Person alloc] initWithData:data error:nil];
 
 You now have a fully initialized instance of person filled in with your data.
 
 */
@interface CMModel : NSObject

/**
 Initializes an instance of `CMModel` from the specified property list.
 
 This is the designated initializer.
 
 @param data The property list you wish to represent in your model.
 @param On output, an error if an error occured during the processing of the data.
 
 @return An array of CMModel or nil if an error occured processing the data.
 */
- (instancetype)initWithPropertyList:(NSDictionary<NSString*,id>*)plist NS_DESIGNATED_INITIALIZER;

/**
 Initializes an instance of `CMModel` from the specified data.
 
 @param data The data you wish to represent in your model.
 @param On output, an error if an error occured during the processing of the data.
 
 @return An array of CMModel or nil if an error occured processing the data.
 */
- (instancetype _Nullable)initWithData:(NSData*)data error:(NSError* _Nullable * _Nullable)error;

/**
 Creates an array of `CMModel` from the specified data.
 
 @param data The data you wish to represent in your model.
 @param On output, an error if an error occured during the processing of the data.
 
 @return An array of CMModel or nil if an error occured processing the data.
 */
+ (NSArray<__kindof CMModel*>* _Nullable)modelsFromData:(NSData*)data error:(NSError* _Nullable * _Nullable)error;

/**
 Returns an object that implements `CMModelAdapter`. This object will be used to parse the data for this class. 
 
 By default, this returns an instance that can adapt to JSON data.
 */
+ (id<CMModelAdapter>)modelAdapter;

/**
 Return an `NSString` that represents the path in your model to the important data in order to help the adapter parse into objects.
 
 Given some data, return the data key that represents the root object for the object needing decoding.
 ie: { "data" : [ { "id" : "12345" }, { "id" : "2345" } ] } => the model key would be "data"
 */
+ (NSString* _Nullable)modelKeyForClassRoot;

/**
 Returns an `NSString` that maps a property in your class to a key in you data.
 */
+ (NSString* _Nullable)modelPropertyNameForkey:(NSString*)key;

/**
 Returns a `Class` that maps an ObjC class to a key in your data.
 
 For example, if in your data you have an array in which each object is of type "Buddy", return [Buddy class].
 */
+ (Class _Nullable)modelClassForKey:(NSString*)key;

/**
 Returns a converted object in the requested data type.
 
 By default, the following is handled:
 
 NSNull, NSString => NSDate, NSString => NSURL
 
 @param obj The object in your data.
 @param type The destination ObjC class for the conversion.
 
 @return The converted object or nil.
 */
+ (id _Nullable)modelConvertObject:(NSObject*)obj toType:(Class)type;

/**
 Returns a converted object in the requested type encoding.
 
 By default, anything relating to number and bool is handled ( NSNumber ).
 
 @param obj The object in your data.
 @param type The destination ObjC class for the conversion.
 
 @return The converted object or nil.
 
 @see objc/runtime.h
 */
+ (id _Nullable)modelConvertObject:(NSObject*)obj toTypeEncoding:(char)typeEncoding;

@end


@interface CMModel (NSURLSessionDataTask)

/**
 Returns a data task which when resumed, will try and complete with an array of CMModels.
 
 @see -dataTaskWithRequest:completionHandler:
 */
+ (NSURLSessionDataTask*)modelTaskWithURLSession:(NSURLSession*)session request:(NSURLRequest*)request completionHandler:(void (^)(NSArray<__kindof CMModel*>* _Nullable models, NSURLResponse* _Nullable response, NSError* _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
