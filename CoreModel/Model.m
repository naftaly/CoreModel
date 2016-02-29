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

#import "Model.h"
#import <objc/runtime.h>

@interface ModelProperty : NSObject

@property (nonatomic,strong) NSString* name;

@property (nonatomic,assign,getter=isReadOnly) BOOL readOnly;
@property (nonatomic,assign,getter=isCopied) BOOL copied;
@property (nonatomic,assign,getter=isReferenced) BOOL referenced;
@property (nonatomic,assign,getter=isNonAtomic) BOOL nonAtomic;
@property (nonatomic,assign,getter=isDynamic) BOOL dynamic;
@property (nonatomic,assign,getter=isWeak) BOOL weak;
@property (nonatomic,assign,getter=isEligibleForGarbageCollection) BOOL eligibleForGarbageCollection;

@property (nonatomic,assign) char typeEncoding;
@property (nonatomic,assign) Class typeClass;

@property (nonatomic,strong) NSString* customGetterSelectorName;
@property (nonatomic,strong) NSString* customSetterSelectorName;

@end

@implementation ModelProperty

- (NSString*)description
{
    return [NSString stringWithFormat:@"<%@:%p> %@ : %@", NSStringFromClass(self.class), self, self.name, NSStringFromClass(self.typeClass)];
}

@end

typedef NSMutableDictionary<NSString*,ModelProperty*>* ModelMap;

@interface Model ()

@end

@implementation Model

static NSMutableDictionary<NSString*,ModelMap>* _mappings = nil;
static NSMutableSet<NSString*>* _modelClassNames = nil;

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _mappings = [NSMutableDictionary dictionary];
        _modelClassNames = [NSMutableSet set];
    });
    
    [_modelClassNames addObject: NSStringFromClass(self.class)];
}

+ (void)setModelProperties:(ModelMap)mp forClass:(Class)cls
{
    _mappings[NSStringFromClass(cls)] = mp;
}

+ (ModelMap)modelPropertiesForClass:(Class)cls
{
    return _mappings[NSStringFromClass(cls)];
}

- (void)_loadProperties
{
    
    Class cls = self.class;
    ModelMap modelPropertyMap = [cls modelPropertiesForClass:cls];
    if ( modelPropertyMap )
        return;
    
    modelPropertyMap = [NSMutableDictionary dictionary];
    
    while (cls && cls != [Model class])
    {
        unsigned int count = 0;
        objc_property_t* properties = class_copyPropertyList(cls,&count);
        for ( unsigned int i = 0; i < count; i++ )
        {
            objc_property_t p = properties[i];
            const char* propName = property_getName(p);
            
            ModelProperty* modelProperty = [[ModelProperty alloc] init];
            modelProperty.name = [NSString stringWithUTF8String:propName];
            
            modelPropertyMap[modelProperty.name] = modelProperty;
            
            unsigned int outCount = 0;
            objc_property_attribute_t* propAtt = property_copyAttributeList(p, &outCount);
            for ( unsigned int c = 0; c < outCount; c++ )
            {
                
                switch (propAtt[c].name[0])
                {
                    case 'R':
                    {
                        modelProperty.readOnly = YES;
                    }
                        break;
                        
                    case 'C':
                    {
                        modelProperty.copied = YES;
                    }
                        break;
                        
                    case '&':
                    {
                        modelProperty.referenced = YES;
                    }
                        break;
                        
                    case 'N':
                    {
                        modelProperty.nonAtomic = YES;
                    }
                        break;
                        
                    case 'G':
                    {
                        modelProperty.customGetterSelectorName = [NSString stringWithUTF8String:propAtt[c].value];
                    }
                        break;
                        
                    case 'S':
                    {
                        modelProperty.customSetterSelectorName = [NSString stringWithUTF8String:propAtt[c].value];
                    }
                        break;
                        
                    case 'D':
                    {
                        modelProperty.dynamic = YES;
                    }
                        break;
                        
                    case 'W':
                    {
                        modelProperty.weak = YES;
                    }
                        break;
                        
                    case 'P':
                    {
                        modelProperty.eligibleForGarbageCollection = YES;
                    }
                        break;
                        
                    case 't':
                    {
                        modelProperty.typeEncoding = propAtt[c].value[0];
                    }
                        break;
                        
                    case 'T':
                    {
                        NSString* s = [NSString stringWithUTF8String:propAtt[c].value];
                        s = [s substringFromIndex:2];
                        s = [s substringToIndex:s.length-1];
                        modelProperty.typeClass = NSClassFromString(s);
                    }
                        break;
                        
                    default:
                    {
                        //NSLog( @"%s = %s", propAtt[c].name, propAtt[c].value );
                    }
                        break;
                }
                
            }
            free( propAtt );
            
        }
        free( properties );
        
        cls = class_getSuperclass(cls);
    }
    
    [[self class] setModelProperties:modelPropertyMap forClass:[self class]];
    
    //NSLog( @"%@", modelPropertyMap );
}

- (instancetype)init
{
    self = [super init];
    [self _loadProperties];
    return self;
}

- (instancetype)initWithJSON:(NSDictionary*)json
{
    if ( !json )
        return nil;
    self = [self init];
    [self _loadModelFromJSON:json];
    return self;
}

- (instancetype)initWithData:(NSData*)data error:(NSError**)error
{
    return [self initWithJSON:[[self class] JSONFromData:data error:error]];
}

+ (id)JSONFromData:(NSData*)data error:(NSError**)error
{
    id json = nil;
    @try {
        json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    }
    @catch (NSException *exception) {
        json = nil;
    }
    return json;
}

+ (NSArray<__kindof Model*>*)modelsFromJSON:(id)json
{
    if ( !json )
        return nil;
    
    if ( [json isKindOfClass:[NSArray class]] )
    {
        NSArray* array = json;
        NSMutableArray* results = [NSMutableArray array];
        for ( id it in array )
        {
            if ( [it isKindOfClass:[NSDictionary class]] )
            {
                id obj = [[[self class] alloc] initWithJSON:it];
                if ( obj )
                    [results addObject:obj];
            }
        }
        return [results copy];
    }
    else if ( [json isKindOfClass:[NSDictionary class]] )
    {
        NSDictionary<NSString*,id>* dict = json;
        
        NSString* rootKey = [self modelJSONKeyForClassRoot];
        if ( rootKey && dict[rootKey] )
        {
            if ( [dict[rootKey] isKindOfClass:[NSArray class]] )
            {
                NSMutableArray<__kindof Model*>* results = [NSMutableArray array];
                NSArray<NSDictionary*>* items = dict[rootKey];
                for ( NSDictionary* it in items )
                {
                    if ( [it isKindOfClass:[NSDictionary class]] )
                    {
                        id obj = [[[self class] alloc] initWithJSON:it];
                        if ( obj )
                            [results addObject:obj];
                    }
                }
                return [results copy];
            }
            else if ( [dict[rootKey] isKindOfClass:[NSDictionary class]] )
            {
                id obj = [[[self class] alloc] initWithJSON:dict[rootKey]];
                if ( obj )
                    return @[ obj ];
            }
        }
        else
        {
            id obj = [[[self class] alloc] initWithJSON:json];
            if ( obj )
                return @[ obj ];
        }
    }
    
    return nil;
}

+ (NSArray<__kindof Model*>*)modelsFromData:(NSData*)data error:(NSError**)error;
{
    return [self modelsFromJSON:[self JSONFromData:data error:error]];
}

+ (Class)modelClassForJSONKey:(NSString*)jsonKey
{
    if ( [_modelClassNames containsObject:jsonKey] )
        return NSClassFromString(jsonKey);
    return nil;
}

+ (NSString*)modelPropertyNameForJSONkey:(NSString*)jsonKey
{
    ModelProperty* prop = [self modelPropertiesForClass:self][jsonKey];
    return prop.name;
}

+ (NSString*)modelJSONKeyForClassRoot
{
    return nil;
}

+ (id)modelConvertJSONObject:(NSObject*)jsonObj toType:(Class)type
{
    // need to convert value to type class
    if ( [jsonObj isKindOfClass:[NSString class]] && type == [NSDate class] )
    {
        return [[self JSONDataFormatter] dateFromString:(NSString*)jsonObj];
    }
    else if ( [jsonObj isKindOfClass:[NSString class]] && type == [NSURL class] )
    {
        return [NSURL URLWithString:(NSString*)jsonObj];
    }
    else if ( [jsonObj isKindOfClass:[NSNull class]] )
    {
        return nil;
    }
    
    NSLog( @"<%@> have %@ but want %@", NSStringFromClass(self), NSStringFromClass(((NSObject*)jsonObj).class), NSStringFromClass(type) );
    return nil;
}

+ (NSDateFormatter*)JSONDataFormatter
{
    static NSDateFormatter* _fmt = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _fmt = [[NSDateFormatter alloc] init];
        [_fmt setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        [_fmt setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    });
    return _fmt;
}

- (void)_loadModelFromJSON:(NSDictionary<NSString*,id>*)json
{
    for ( NSString* inKey in json )
    {
        id obj = json[inKey];
        
        // get the property key we use for this key
        // if the returned key is nil we skip this value completely
        NSString* modelKey = [[self class] modelPropertyNameForJSONkey:inKey];
        if ( !modelKey )
            return;
        
        // get the ModelProperty used for this key
        // if we can't find one, then we skip
        ModelProperty* modelProperty = [[self class] modelPropertiesForClass:self.class][modelKey];
        if ( !modelProperty )
            return;
        
        id evaluatedObj = nil;
        
        // check the kind of the value and  evaluate it
        if ( [obj isKindOfClass:[NSArray class]] )
        {
            Class arrayModelClass = [[self class] modelClassForJSONKey:modelKey];
            if ( arrayModelClass )
                evaluatedObj = [arrayModelClass modelsFromJSON:obj];
        }
        else if ( [obj isKindOfClass:[NSDictionary class]] && [modelProperty.typeClass isSubclassOfClass:[Model class]] )
        {
            evaluatedObj = [[modelProperty.typeClass alloc] initWithJSON:obj];
        }
        else if ( [obj isKindOfClass:modelProperty.typeClass] )
        {
            evaluatedObj = obj;
        }
        else
        {
            evaluatedObj = [[self class] modelConvertJSONObject:obj toType:modelProperty.typeClass];
        }
        
        [self setValue:evaluatedObj forKey:modelProperty.name];
    }
    
}

@end

@implementation Model (NSURLSessionDataTask)

+ (NSURLSessionDataTask*)modelTaskURLSession:(NSURLSession*)session request:(NSURLRequest*)request completionHandler:(void (^)(NSArray<__kindof Model*>* models, NSURLResponse* response, NSError* error))completionHandler
{
    return [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if ( error )
        {
            if ( completionHandler )
                completionHandler(nil,response,error);
            return;
        }
        
        NSError* jsonError = nil;
        NSArray* results = [[self class] modelsFromData:data error:&jsonError];
        if ( !results )
        {
            if ( completionHandler )
                completionHandler( nil, response, jsonError );
        }
        
        if ( completionHandler )
            completionHandler( results, response, nil );
    }];
}

@end






