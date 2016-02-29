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

@protocol CMModelAdapter <NSObject>

@required

/*
 * take in a blob of data and return a property list object representation
 */
- (id)modelAdapterPropertyListFromData:(NSData*)data error:(NSError**)error;

@end

@interface CMModel : NSObject

/* 
 * initializers 
 */
- (instancetype)initWithData:(NSData*)data error:(NSError**)error;
+ (NSArray<__kindof CMModel*>*)modelsFromData:(NSData*)data error:(NSError**)error;

/*
 *
 * Overload the following class methods in your subclass to change behavior
 *
 */

/*
 * return a custom adapter to use to convert your data to property list objects. default wraps NSJSONSerialization.
 */
+ (id<CMModelAdapter>)modelAdapter;

/* 
 * given JSON, return the JSON key that represents the root object for the object needing decoding
 * ie: { "data" : [ { "id" : "12345" }, { "id" : "2345" } ] } => the JSON key would be "data"
 */
+ (NSString*)modelJSONKeyForClassRoot;

/* 
 * return the property name for a given json key 
 */
+ (NSString*)modelPropertyNameForJSONkey:(NSString*)jsonKey;

/* 
 * given a json key that is a Dictionary or an Array, return the class to use 
 */
+ (Class)modelClassForJSONKey:(NSString*)jsonKey;

/* 
 * given a JSON object, convert that object to type
 * default handles null, string => date, string => url
 */
+ (id)modelConvertJSONObject:(NSObject*)jsonObj toType:(Class)type;

/*
 * given a JSON object, convert that object to typeEncoding
 * default handles anthing relating to number and bool ( NSNumber )
 */
+ (id)modelConvertJSONObject:(NSObject*)jsonObj toTypeEncoding:(char)typeEncoding;

@end

@interface CMModel (NSURLSessionDataTask)

/* 
 * data task for which the completion handler will compute an array of models 
 */
+ (NSURLSessionDataTask*)modelTaskURLSession:(NSURLSession*)session request:(NSURLRequest*)request completionHandler:(void (^)(NSArray<__kindof CMModel*>* models, NSURLResponse* response, NSError* error))completionHandler;

@end


