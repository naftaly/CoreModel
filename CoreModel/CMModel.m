/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2017 Alexander Cohen
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

#if TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

@interface ModelJSONAdapter : NSObject <CMModelAdapter>
@end

@implementation ModelJSONAdapter

- (id)modelAdapterPropertyListFromData:(NSData *)data error:(NSError *__autoreleasing *)error
{
    if ( !data )
        return nil;
    
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

@property (nonatomic,assign) char typeEncoding;
@property (nonatomic,assign) Class typeClass;

@property (nonatomic,strong) NSString* customGetterSelectorName;
@property (nonatomic,strong) NSString* customSetterSelectorName;

@end

@implementation CMModelProperty
@end

typedef NSMutableDictionary<NSString*,CMModelProperty*>* ModelMap;

@interface CMModel () {
    id _originalValue;
}

@end

@implementation CMModel

static NSMutableDictionary<NSString*,ModelMap>* _mappings = nil;
static NSMutableSet<NSString*>* _modelClassNames = nil;
static NSRecursiveLock* _lock = nil;

- (NSString*)description
{
    NSDictionary* dict = self.jsonDictionary;
    NSData* data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _lock = [[NSRecursiveLock alloc] init];
        _lock.name = @"com.bedroomcode.coremodel.lock";
        _mappings = [NSMutableDictionary dictionary];
        _modelClassNames = [NSMutableSet set];
    });
    
    [_lock lock];
    [_modelClassNames addObject: NSStringFromClass(self.class)];
    [_lock unlock];;
}

+ (void)setModelProperties:(ModelMap)mp forClass:(Class)cls
{
    [_lock lock];
    _mappings[NSStringFromClass(cls)] = mp;
    [_lock unlock];
}

+ (ModelMap)modelPropertiesForClass:(Class)cls
{
    ModelMap map = nil;
    [_lock lock];
    map = _mappings[NSStringFromClass(cls)];
    [_lock unlock];
    return map;
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
                        
                        /* 
                         commenting since we can't test this
                    case 'P':
                    {
                        modelProperty.eligibleForGarbageCollection = YES;
                    }
                        break;
                        */

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

- (id)_jsonForContainerValue:(id)value
{
    if ( [value isKindOfClass:[NSArray class]] )
    {
        NSMutableArray* array = [NSMutableArray array];
        for ( id obj in (NSArray*)value )
            [array addObject:[self _jsonForValue:obj]];
        return array;
    }
    else if ( [value isKindOfClass:[NSDictionary class]] )
    {
        NSMutableDictionary* dict = [NSMutableDictionary dictionary];
        [(NSDictionary*)value enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            id k = [self _jsonForValue:key];
            id v = [self _jsonForValue:obj];
            dict[k] = v;
        }];
        return [dict copy];
    }
    
    return nil;
}

- (id)_jsonForValue:(id)value
{
    if ( !value )
        return [NSNull null];
    
    static NSArray* jsonValueClasses = nil;
    static NSArray* jsonValueContainerClasses = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        jsonValueClasses = @[ [NSString class],
                              [NSNumber class],
                              [NSNull class] ];
        
        jsonValueContainerClasses = @[ [NSArray class],
                                       [NSDictionary class] ];
        
    });
    
    for ( Class cls in jsonValueContainerClasses )
    {
        if ( [value isKindOfClass:cls] )
            return [self _jsonForContainerValue:value];
    }
    
    for ( Class cls in jsonValueClasses )
    {
        if ( [value isKindOfClass:cls] )
            return value;
    }
    
    if ( [value isKindOfClass:[CMModel class]] )
        return [((CMModel*)value) jsonDictionary];
    
#if TARGET_OS_IOS || TARGET_OS_TV
    if ( [value isKindOfClass:[UIColor class]] )
    {
        CGFloat r,g,b;
        if ( [(UIColor*)value getRed:&r green:&g blue:&b alpha:NULL] )
            return @[ @(r*255), @(g*255), @(b*255) ];
    }
#else
    if ( [value isKindOfClass:[NSColor class]] )
    {
        CGFloat r,g,b;
        [(NSColor*)value getRed:&r green:&g blue:&b alpha:NULL];
        return @[ @(r*255), @(g*255), @(b*255) ];
    }
#endif
    
    if ( [value isKindOfClass:[NSDate class]] )
        return @( ((NSDate*)value).timeIntervalSince1970 );
    
    if ( [value respondsToSelector:@selector(stringValue)] )
        return [value stringValue];
    
    return [value description];
}

+ (BOOL)ignoresKeyDuringEncoding:(NSString*)key
{
    return NO;
}

- (id)originalValue
{
    return _originalValue;
}

- (NSDictionary*)jsonDictionaryIgnoringKeys:(NSArray<NSString*>*)keysToIgnore
{
    NSMutableDictionary* json = [NSMutableDictionary dictionary];
    
    Class cls = self.class;
    
    unsigned int count = 0;
    objc_property_t* properties = class_copyPropertyList(cls,&count);
    for ( unsigned int i = 0; i < count; i++ )
    {
        objc_property_t p = properties[i];
        const char* propName = property_getName(p);
        NSString* key = [NSString stringWithUTF8String:propName];
        if ( [[self class] ignoresKeyDuringEncoding:key] || [keysToIgnore containsObject:key] )
            continue;
        id value = [self valueForKey:key];
        json[key] = [self _jsonForValue:value];
    }
    free( properties );
    
    //cls = class_getSuperclass(cls);
    
    return [json copy];
}

- (NSDictionary*)jsonDictionary
{
    return [self jsonDictionaryIgnoringKeys:nil];
}

- (instancetype)init
{
    self = [super init];
    [self _loadProperties];
    return self;
}

- (instancetype)initWithPropertyList:(NSDictionary<NSString*,id>*)plist
{
    if ( !plist || plist.count == 0 )
        return nil;
    self = [self init];
    _originalValue = [plist copy];
    [self _loadModelFromJSON:plist];
    return self;
}

- (void)updateFromPropertyList:(NSDictionary<NSString*,id>*)plist
{
    [self _loadModelFromJSON:plist];
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

+ (id)_valueForKeyPath:(NSString*)keyPath inDictionary:(NSDictionary*)dict
{
    NSMutableArray* comps = [[keyPath componentsSeparatedByString:@"."] mutableCopy];
    id              currentObject = dict;
    while ( comps.count )
    {
        NSString* key = comps.firstObject;
        [comps removeObjectAtIndex:0];
        
        static NSRegularExpression* expr = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            expr = [NSRegularExpression regularExpressionWithPattern:@"\[([0-9]+)]" options:0 error:nil];
        });
        
        NSTextCheckingResult* match = [expr firstMatchInString:key options:0 range:NSMakeRange(0, key.length)];
        if ( match.range.length > 0 )
        {
            NSString*   baseKey = [key substringToIndex:match.range.location-1]; // -1 becuase it's the [
            NSUInteger  index = [[key substringWithRange:match.range] integerValue];
            
            currentObject = [currentObject valueForKey:baseKey];
            if ( [currentObject isKindOfClass:[NSArray class]] )
            {
                currentObject = [currentObject objectAtIndex:index];
            }
        }
        else
            currentObject = [currentObject valueForKey:key];
        
    }
    
    return currentObject;
}

+ (BOOL)scanString:(NSString*)string forPrefix:(NSString**)outPrefix index:(NSInteger*)outIndex
{
    NSString*       prefix = nil;
    NSInteger       index = 0;
    NSCharacterSet* numbersSet = [NSCharacterSet characterSetWithCharactersInString:@"1234567890"];
    NSScanner*      scanner = [NSScanner scannerWithString:string];
    
    // find the prefix and number
    if ( ![scanner scanUpToCharactersFromSet:numbersSet intoString:&prefix] )
        return NO;
    
    if ( ![scanner scanInteger:&index] )
        return NO;
    
    if ( ![scanner isAtEnd] )
        return NO;
    
    if ( outPrefix )
        *outPrefix = [prefix copy];
    if ( outIndex )
        *outIndex = index;
    
    return YES;
}

+ (NSArray*)_convertDictionaryToArrayIfPossible:(NSDictionary*)obj
{
    if ( !obj || obj.count == 0 || ![obj.allKeys.firstObject isKindOfClass:[NSString class]] )
        return nil;
    
    NSMutableArray*     results = [NSMutableArray array];
    NSString*           foundPrefix = nil;
    
    NSMutableArray*     originalObjects = [NSMutableArray array];
    NSMutableArray*     originalIndexes = [NSMutableArray array];
    
    for ( id key in obj )
    {
        if ( ![key isKindOfClass:[NSString class]] )
            return nil;
        
        NSString*   prefix = nil;
        NSInteger   index = 0;
        if ( ![self scanString:key forPrefix:&prefix index:&index] )
            return nil;
        
        if ( !foundPrefix )
            foundPrefix = [prefix copy];
        else if ( ![foundPrefix isEqualToString:prefix] )
            return nil;
        
        [originalObjects addObject:obj[key]];
        [originalIndexes addObject:@(index)];
        [results addObject:[NSNull null]];
    }

    [originalIndexes enumerateObjectsUsingBlock:^(NSNumber*  _Nonnull num, NSUInteger idx, BOOL * _Nonnull stop) {
        results[ [num integerValue] ] = originalObjects[idx];
    }];
    
    return [results copy];
}

+ (BOOL)convertsRootDictionaryToArray
{
    return NO;
}

+ (NSArray<__kindof CMModel*>*)modelsFromJSON:(id)inJson
{
    if ( !inJson )
        return nil;
    
    id          json = inJson;
    
    if ( [json isKindOfClass:[NSDictionary class]] && [self convertsRootDictionaryToArray] )
        json = ((NSDictionary*)json).allValues;
    
    NSArray*    convertedDict = [json isKindOfClass:[NSDictionary class]] ? [self _convertDictionaryToArrayIfPossible:json] : nil;
    if ( convertedDict )
        json = convertedDict;
    
    if ( [json isKindOfClass:[NSArray class]] )
    {
        return [self _loadModelFromArray:json property:nil];
    }
    else if ( [json isKindOfClass:[NSDictionary class]] || [json isKindOfClass:NSClassFromString(@"PFObject")] )
    {
        if ( [json isKindOfClass:NSClassFromString(@"PFObject")] )
            json = [self modelConvertObject:json toType:[NSDictionary class]];

        NSDictionary<NSString*,id>* dict = json;
        
        NSString*   rootKey = [self modelKeyForClassRoot];
        id          rootVal = rootKey ? [self _valueForKeyPath:rootKey inDictionary:dict] : nil;
        if ( rootVal )
        {
            return [self modelsFromJSON:rootVal];
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

+ (NSArray<__kindof CMModel*>*)modelsFromPropertyList:(id)plist error:(NSError**)error;
{
    return [self modelsFromJSON:plist];
}

+ (Class)modelClassForKey:(NSString*)jsonKey
{
    Class cls = nil;
    [_lock lock];
    if ( [_modelClassNames containsObject:jsonKey] )
        cls = NSClassFromString(jsonKey);
    [_lock unlock];
    return cls;
}

+ (Class)modelClassForKey:(NSString*)jsonKey object:(NSDictionary*)object
{
    return nil;
}

+ (BOOL)shouldBypassObject:(id)obj forKey:(NSString*)key
{
    return NO;
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
        id ret = [[self JSONDateFormatter] dateFromString:(NSString*)jsonObj];
        if ( ret )
            return ret;
        ret = [[self JSONDateFormatter2] dateFromString:(NSString*)jsonObj];
        if ( ret )
            return ret;
        ret = [[self JSONDateFormatter3] dateFromString:(NSString*)jsonObj];
        if ( ret )
            return ret;
        
        ret = [[self JSONDateFormatter4] dateFromString:(NSString*)jsonObj];
        if ( ret )
            return ret;
        
        NSTimeInterval time = [(NSString*)jsonObj doubleValue];
        return [NSDate dateWithTimeIntervalSince1970:time];
        
    }
    else if ( [jsonObj isKindOfClass:[NSNumber class]] && type == [NSDate class] )
    {
        NSDate* date = [NSDate dateWithTimeIntervalSince1970: ((NSNumber*)jsonObj).doubleValue];
        return date;
    }
    else if ( [jsonObj isKindOfClass:[NSNumber class]] && type == [NSDate class] )
    {
        return [NSDate dateWithTimeIntervalSince1970:[(NSNumber*)jsonObj doubleValue]];
    }
    else if ( [jsonObj isKindOfClass:[NSString class]] && type == [NSURL class] )
    {
        if ( ((NSString*)jsonObj).length )
        {
            NSURL* url = nil;
            NSString* jsStr = (NSString*)jsonObj;
            if ( [jsStr hasPrefix:@"/"] || [jsStr hasPrefix:@"file://"] )
            {
                url = [NSURL fileURLWithPath:jsStr];
                return url;
            }
            else
            {
                url = [NSURL URLWithString:(NSString*)jsonObj];
                if ( url.scheme.length )
                    return url;
            }
        }
        return nil;
    }
    else if ( [jsonObj isKindOfClass:[NSNull class]] )
    {
        return nil;
    }
    else if ( [jsonObj isKindOfClass:[NSNumber class]] && type == [NSString class] )
    {
        return [((NSNumber*)jsonObj) stringValue];
    }
    else if ( type == [NSDecimalNumber class] )
    {
        if ( [jsonObj isKindOfClass:[NSNumber class]] )
            return [NSDecimalNumber decimalNumberWithDecimal:[(NSNumber*)jsonObj decimalValue]];
        else if ( [jsonObj isKindOfClass:[NSString class]] )
            return [NSDecimalNumber decimalNumberWithString:(NSString*)jsonObj];
    }
    
    if ( [self.class logWhenDataIsMissing] )
        NSLog( @"[CoreModel-%@] have %@ but want %@", NSStringFromClass(self), NSStringFromClass(((NSObject*)jsonObj).class), NSStringFromClass(type) );

    return nil;
}

+ (NSDateFormatter*)JSONDateFormatter3
{
    static NSDateFormatter* _fmt = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _fmt = [[NSDateFormatter alloc] init];
        [_fmt setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        [_fmt setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    });
    return _fmt;
}

+ (NSDateFormatter*)JSONDateFormatter2
{
    static NSDateFormatter* _fmt = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _fmt = [[NSDateFormatter alloc] init];
        [_fmt setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        [_fmt setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    });
    return _fmt;
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

+ (NSDateFormatter*)JSONDateFormatter4
{
    static NSDateFormatter* _fmt = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _fmt = [[NSDateFormatter alloc] init];
        [_fmt setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        [_fmt setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
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
        case _C_CHR:
        case _C_BOOL:
        {
            if ( [jsonObj isKindOfClass:[NSNumber class]] )
                return jsonObj;
            if ( [jsonObj isKindOfClass:[NSString class]] )
                return @([(NSString*)jsonObj doubleValue]);
        }
            break;
    }
    
    if ( [self.class logWhenDataIsMissing] )
    {
        char c[2] = { typeEncoding, 0 };
        NSString* type = [NSString stringWithUTF8String:c];
        NSLog( @"[CoreModel-%@] have %@ but want %@", NSStringFromClass(self), NSStringFromClass(((NSObject*)jsonObj).class), type );
    }
    
    return nil;
}

+ (NSArray*)_loadModelFromArray:(NSArray*)array property:(CMModelProperty*)property
{
    if ( [self shouldBypassObject:array forKey:property.name] )
        return nil;
    
    Class arrayModelClass = property ? [[self class] modelClassForKey:property.name] : self;
    if ( arrayModelClass )
    {
        NSMutableArray* results = [NSMutableArray array];
        for ( NSObject* inIt in array )
        {
            NSObject* it = inIt;
            if ( [it isKindOfClass:NSClassFromString(@"PFObject")] )
                it = [self modelConvertObject:it toType:[NSDictionary class]];
            
            if ( [it isKindOfClass:[NSDictionary class]] )
            {
                Class cls = [self.class modelClassForKey:property.name object:(NSDictionary*)it];
                id item = [[ cls ? cls : arrayModelClass alloc] initWithPropertyList:(NSDictionary*)it];
                if ( item )
                    [results addObject:item];
            }
            else if ( [it isKindOfClass:[NSNull class]] )
            {
            }
            else
            {
                id item = [self modelConvertObject:it toType:arrayModelClass];
                if ( item )
                    [results addObject:item];
            }
            
        }
        return [results copy];
    }
    
    return [array copy];
}

+ (id)_loadModelFromDictionary:(NSDictionary*)dict property:(CMModelProperty*)property
{
    if ( [self shouldBypassObject:dict forKey:property.name] )
        return nil;
    
    Class cls = property ? ( [property.typeClass isSubclassOfClass:[CMModel class]] ? property.typeClass : nil ) : self;
    if ( cls )
        return [[cls alloc] initWithPropertyList:dict];
    return [dict copy];
}

- (void)_loadModelFromJSON:(NSDictionary<NSString*,id>*)json
{
    if ( ![json isKindOfClass:[NSDictionary class]] )
    {
        NSLog( @"[CoreModel-%@] _loadModelFromJSON, json is not NSDictionary", NSStringFromClass(self.class) );
        return;
    }
    
    for ( NSString* inKey in json )
    {
        id obj = json[inKey];

        if ( [self.class shouldBypassObject:obj forKey:inKey] )
            continue;

        // get the property key we use for this key
        // if the returned key is nil we skip this value completely
        NSString* modelKey = [[self class] modelPropertyNameForkey:inKey];
        if ( !modelKey )
        {
            //id val = [[self class] objectForUnhandledModelKey:inKey object:obj];
            //if ( !val )
            if ( [self.class logWhenDataIsMissing] )
                NSLog( @"[CoreModel-%@] could not find a model for key %@", NSStringFromClass(self.class), inKey );
            continue;
        }

        // get the ModelProperty used for this key
        // if we can't find one, then we skip
        CMModelProperty* modelProperty = [[self class] modelPropertiesForClass:self.class][modelKey];
        if ( !modelProperty )
        {
            if ( [self.class logWhenDataIsMissing] )
                NSLog( @"[CoreModel-%@] could not find a model for property %@", NSStringFromClass(self.class), modelKey );
            continue;
        }

        id evaluatedObj = nil;
        
        NSArray*    convertedDict = nil;
        if ( [obj isKindOfClass:[NSDictionary class]] )
        {
            convertedDict = [[self class] _convertDictionaryToArrayIfPossible:obj];
            
            if ( modelProperty.typeClass == [NSArray class] && !convertedDict )
                convertedDict = ((NSDictionary*)obj).allValues;
            
            if ( convertedDict )
                obj = convertedDict;
        }

        // check the kind of the value and  evaluate it
        if ( [obj isKindOfClass:[NSArray class]] )
        {
            evaluatedObj = [[self class] _loadModelFromArray:obj property:modelProperty];
        }
        else if ( [obj isKindOfClass:[NSDictionary class]] )
        {
            evaluatedObj = [[self class] _loadModelFromDictionary:obj property:modelProperty];
        }
        else if ( [obj isKindOfClass:NSClassFromString(@"PFObject")] )
        {
            obj = [[self class] modelConvertObject:obj toType:[NSDictionary class]];
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
        {
            if ( [evaluatedObj isKindOfClass:[NSString class]] && ((NSString*)evaluatedObj).length == 0 )
                evaluatedObj = nil;
            
            // post process it
            evaluatedObj = [[self class] postProcessObject:evaluatedObj forKey:modelProperty.name instance:self];
            
            @try {
                [self setValue:evaluatedObj forKey:modelProperty.name];
            } @catch (NSException *exception) {
            }
            
        }
    }
    
}

+ (id)postProcessObject:(id)object forKey:(NSString*)key instance:(nonnull id)instance
{
    return object;
}

+ (BOOL)logWhenDataIsMissing { return NO; }

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
            return;
        }
        
        if ( completionHandler )
            completionHandler( results, response, nil );
    }];
}

@end






