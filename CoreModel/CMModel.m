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

#import "CMModel.h"
#import <objc/runtime.h>

@interface ModelJSONAdapter : NSObject <CMModelAdapter>
@end

@implementation ModelJSONAdapter

- (id)modelAdapterPropertyListFromData:(NSData *)data error:(NSError *__autoreleasing *)error
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

@end

@interface CMModelProperty : NSObject

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

@implementation CMModelProperty

- (NSString*)description
{
    return [NSString stringWithFormat:@"<%@:%p> %@ : %@", NSStringFromClass(self.class), self, self.name, NSStringFromClass(self.typeClass)];
}

@end

typedef NSMutableDictionary<NSString*,CMModelProperty*>* ModelMap;

@interface CMModel ()

@end

@implementation CMModel

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
    
    while (cls && cls != [CMModel class])
    {
        unsigned int count = 0;
        objc_property_t* properties = class_copyPropertyList(cls,&count);
        for ( unsigned int i = 0; i < count; i++ )
        {
            objc_property_t p = properties[i];
            const char* propName = property_getName(p);
            
            CMModelProperty* modelProperty = [[CMModelProperty alloc] init];
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
                        if ( s.length == 1 )
                        {
                            modelProperty.typeEncoding = propAtt[c].value[0];
                        }
                        else
                        {
                            s = [s substringFromIndex:2];
                            s = [s substringToIndex:s.length-1];
                            modelProperty.typeClass = NSClassFromString(s);
                        }
                    }
                        break;
                        
                    default:
                    {
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
}

- (instancetype)init
{
    return [self initWithPropertyList:@{}];
}

- (instancetype)initWithPropertyList:(NSDictionary<NSString*,id>*)plist
{
    if ( !plist || plist.count == 0 )
        return nil;
    self = [super init];
    [self _loadProperties];
    [self _loadModelFromJSON:plist];
    return self;
}

- (instancetype)initWithData:(NSData*)data error:(NSError**)error
{
    return [self initWithPropertyList:[[self class] JSONFromData:data error:error]];
}

+ (id<CMModelAdapter>)modelAdapter
{
    return [[ModelJSONAdapter alloc] init];
}

+ (id)JSONFromData:(NSData*)data error:(NSError**)error
{
    return [[self modelAdapter] modelAdapterPropertyListFromData:data error:error];
}

+ (NSArray<__kindof CMModel*>*)modelsFromJSON:(id)json
{
    if ( !json )
        return nil;
    
    if ( [json isKindOfClass:[NSArray class]] )
    {
        return [self _loadModelFromArray:json property:nil];
    }
    else if ( [json isKindOfClass:[NSDictionary class]] )
    {
        NSDictionary<NSString*,id>* dict = json;
        
        NSString* rootKey = [self modelKeyForClassRoot];
        if ( rootKey && dict[rootKey] )
        {
            id root = dict[rootKey];
            return [self modelsFromJSON:root];
        }
        else
        {
            id obj = [[[self class] alloc] initWithPropertyList:json];
            if ( obj )
                return @[ obj ];
        }
    }
    
    return nil;
}

+ (NSArray<__kindof CMModel*>*)modelsFromData:(NSData*)data error:(NSError**)error;
{
    return [self modelsFromJSON:[self JSONFromData:data error:error]];
}

+ (Class)modelClassForKey:(NSString*)jsonKey
{
    if ( [_modelClassNames containsObject:jsonKey] )
        return NSClassFromString(jsonKey);
    return nil;
}

+ (NSString*)modelPropertyNameForkey:(NSString*)jsonKey
{
    CMModelProperty* prop = [self modelPropertiesForClass:self][jsonKey];
    return prop.name;
}

+ (NSString*)modelKeyForClassRoot
{
    return nil;
}

+ (id)modelConvertObject:(NSObject*)jsonObj toType:(Class)type
{
    // need to convert value to type class
    if ( [jsonObj isKindOfClass:[NSString class]] && type == [NSDate class] )
    {
        return [[self JSONDateFormatter] dateFromString:(NSString*)jsonObj];
    }
    else if ( [jsonObj isKindOfClass:[NSString class]] && type == [NSURL class] )
    {
        return [NSURL URLWithString:(NSString*)jsonObj];
    }
    else if ( [jsonObj isKindOfClass:[NSNull class]] )
    {
        return nil;
    }
    
    NSLog( @"[CoreModel] <%@> have %@ but want %@", NSStringFromClass(self), NSStringFromClass(((NSObject*)jsonObj).class), NSStringFromClass(type) );
    return nil;
}

+ (NSDateFormatter*)JSONDateFormatter
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

+ (id)modelConvertObject:(NSObject*)jsonObj toTypeEncoding:(char)typeEncoding
{
    // need to convert value to type class
    switch (typeEncoding)
    {
        case _C_SHT:
        case _C_USHT:
        case _C_INT:
        case _C_UINT:
        case _C_LNG:
        case _C_ULNG:
        case _C_LNG_LNG:
        case _C_ULNG_LNG:
        case _C_FLT:
        case _C_DBL:
        case _C_BFLD:
        case _C_BOOL:
        {
            if ( [jsonObj isKindOfClass:[NSNumber class]] )
                return jsonObj;
            if ( [jsonObj isKindOfClass:[NSString class]] )
                return @([(NSString*)jsonObj doubleValue]);
        }
            break;
    }
    
    char c[2] = { typeEncoding, 0 };
    NSString* type = [NSString stringWithUTF8String:c];
    
    NSLog( @"[CoreModel] <%@> have %@ but want %@", NSStringFromClass(self), NSStringFromClass(((NSObject*)jsonObj).class), type );
    return nil;
}

+ (NSArray*)_loadModelFromArray:(NSArray*)array property:(CMModelProperty*)property
{
    Class arrayModelClass = property ? [[self class] modelClassForKey:property.name] : self;
    if ( arrayModelClass )
    {
        NSMutableArray* results = [NSMutableArray array];
        for ( NSObject* it in array )
        {
            if ( [it isKindOfClass:[NSDictionary class]] )
            {
                id item = [[arrayModelClass alloc] initWithPropertyList:(NSDictionary*)it];
                if ( item )
                    [results addObject:item];
            }
            else if ( [it isKindOfClass:[NSNull class]] )
            {
            }
            else
                NSLog( @"[CoreModel] found %@ when expecting NSDictionary", NSStringFromClass(it.class) );
        }
        return [results copy];
    }
    
    return [array copy];
}

+ (id)_loadModelFromDictionary:(NSDictionary*)dict property:(CMModelProperty*)property
{
    Class cls = property ? ( [property.typeClass isSubclassOfClass:[CMModel class]] ? property.typeClass : nil ) : self;
    if ( cls )
        return [[cls alloc] initWithPropertyList:dict];
    return [dict copy];
}

- (void)_loadModelFromJSON:(NSDictionary<NSString*,id>*)json
{
    for ( NSString* inKey in json )
    {
        id obj = json[inKey];
        
        // get the property key we use for this key
        // if the returned key is nil we skip this value completely
        NSString* modelKey = [[self class] modelPropertyNameForkey:inKey];
        if ( !modelKey )
        {
            NSLog( @"[CoreModel] could not find a model for key %@", inKey );
            continue;
        }
        
        // get the ModelProperty used for this key
        // if we can't find one, then we skip
        CMModelProperty* modelProperty = [[self class] modelPropertiesForClass:self.class][modelKey];
        if ( !modelProperty )
        {
            NSLog( @"[CoreModel] could not find a model for property %@", modelKey );
            continue;
        }
        
        id evaluatedObj = nil;
        
        // check the kind of the value and  evaluate it
        if ( [obj isKindOfClass:[NSArray class]] )
        {
            evaluatedObj = [[self class] _loadModelFromArray:obj property:modelProperty];
        }
        else if ( [obj isKindOfClass:[NSDictionary class]] )
        {
            evaluatedObj = [[self class] _loadModelFromDictionary:obj property:modelProperty];
        }
        else if ( modelProperty.typeClass && [obj isKindOfClass:modelProperty.typeClass] )
        {
            evaluatedObj = obj;
        }
        else if ( modelProperty.typeEncoding != 0 )
        {
            evaluatedObj = [[self class] modelConvertObject:obj toTypeEncoding:modelProperty.typeEncoding];
        }
        else
        {
            evaluatedObj = [[self class] modelConvertObject:obj toType:modelProperty.typeClass];
        }
        
        if ( evaluatedObj )
            [self setValue:evaluatedObj forKey:modelProperty.name];
    }
    
}

@end

@implementation CMModel (NSURLSessionDataTask)

+ (NSURLSessionDataTask*)modelTaskWithURLSession:(NSURLSession*)session request:(NSURLRequest*)request completionHandler:(void (^)(NSArray<__kindof CMModel*>* models, NSURLResponse* response, NSError* error))completionHandler
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





