/*
 *
 *  Copyright 2016 X-Rite, Incorporated. All rights reserved.
 *
 *
 *  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
 *  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 *  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 *  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 *  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#import <Foundation/Foundation.h>

@protocol ModelAdapter <NSObject>

@required

/*
 * take in a blob of data and return a property list object representation
 */
- (id)modelAdapterPropertyListFromData:(NSData*)data error:(NSError**)error;

@end

@interface Model : NSObject

/* 
 * initializers 
 */
- (instancetype)initWithData:(NSData*)data error:(NSError**)error;
+ (NSArray<__kindof Model*>*)modelsFromData:(NSData*)data error:(NSError**)error;

/*
 *
 * Overload the following class methods in your subclass to change behavior
 *
 */

/*
 * return a custom adapter to use to convert your data to property list objects. default wraps NSJSONSerialization.
 */
+ (id<ModelAdapter>)modelAdapter;

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

@interface Model (NSURLSessionDataTask)

/* 
 * data task for which the completion handler will compute an array of models 
 */
+ (NSURLSessionDataTask*)modelTaskURLSession:(NSURLSession*)session request:(NSURLRequest*)request completionHandler:(void (^)(NSArray<__kindof Model*>* models, NSURLResponse* response, NSError* error))completionHandler;

@end


