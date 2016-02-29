//
//  CoreModelTests.m
//  CoreModelTests
//
//  Created by Alexander Cohen on 2016-02-29.
//  Copyright © 2016 X-Rite, Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <CoreModel/CoreModel.h>

@interface CustomNilAdapter : NSObject <CMModelAdapter>
@end

@implementation CustomNilAdapter

- (id)modelAdapterPropertyListFromData:(NSData *)data error:(NSError *__autoreleasing *)error
{
    return nil;
}

@end

@interface Person : CMModel

@property (nonatomic,copy) NSString* identifier;
@property (nonatomic,copy) NSString* name;

@end

@interface Action : CMModel

@property (nonatomic,copy) NSString* name;
@property (nonatomic,copy) NSURL* link;

@end

@interface Item : CMModel

@property (nonatomic,copy) NSString* identifier;
@property (nonatomic,strong) Person* from;
@property (nonatomic,copy) NSString* message;
@property (nonatomic,copy) NSArray<Action*>* actions;
@property (nonatomic,strong) NSString* type;
@property (nonatomic,strong) NSDate* created_time;
@property (nonatomic,strong) NSDate* updated_time;

@end

@interface ItemNilAdapter : Item
@end

@implementation ItemNilAdapter

+ (id<CMModelAdapter>)modelAdapter
{
    return [[CustomNilAdapter alloc] init];
}

@end

@implementation Item

+ (NSString*)modelJSONKeyForClassRoot
{
    return @"data";
}

+ (NSString*)modelPropertyNameForJSONkey:(NSString*)jsonKey
{
    if ( [jsonKey isEqualToString:@"id"] )
        return @"identifier";
    return [super modelPropertyNameForJSONkey:jsonKey];
}

+ (Class)modelClassForJSONKey:(NSString*)jsonKey
{
    if ( [jsonKey isEqualToString:@"actions"] )
        return [Action class];
    return [super modelClassForJSONKey:jsonKey];
}

@end

@implementation Action
@end

@implementation Person

+ (NSString*)modelPropertyNameForJSONkey:(NSString*)jsonKey
{
    if ( [jsonKey isEqualToString:@"id"] )
        return @"identifier";
    return [super modelPropertyNameForJSONkey:jsonKey];
}

@end

@interface ModelSubclass : CMModel

@property (nonatomic,assign) NSInteger integer;
@property (nonatomic,assign) BOOL boolean;
@property (nonatomic,assign) BOOL other_boolean;
@property (nonatomic,strong) NSArray* array;
@property (nonatomic,strong) NSString* string;
@property (nonatomic,strong) NSDictionary* dict;

@end

@implementation ModelSubclass
@end

@interface CoreModelTests : XCTestCase

@end

@implementation CoreModelTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testModelSubclass
{
    NSData* data = [NSData dataWithContentsOfFile: [[NSBundle bundleForClass:[self class]] pathForResource:@"test" ofType:@"json"]];
    
    ModelSubclass* m = [[ModelSubclass alloc] initWithData:data error:nil];
    
    XCTAssertNotNil(m,@"m is nil");
    XCTAssertEqual( m.integer, 1, @"integer property is not euqal to 1", nil );
    XCTAssertEqual( m.boolean, YES, @"boolean property is not euqal to YES", nil );
    XCTAssertEqual( m.other_boolean, YES, @"integer property is not euqal to 1", nil );
    XCTAssertEqualObjects( m.string, @"this is a string" );
    
    NSArray* a = @[ @(1), @"string" ];
    XCTAssertEqualObjects( m.array, a );
    
    NSDictionary* d = @{ @"key1" : @(1), @"key2" : @"hello", @"key3" : @(YES) };
    XCTAssertEqualObjects( m.dict, d );
}

- (void)testLevelsOfModels
{
    NSData* data = [NSData dataWithContentsOfFile: [[NSBundle bundleForClass:[self class]] pathForResource:@"levels" ofType:@"json"]];
    NSArray<Item*>* items = [Item modelsFromData:data error:nil];
    XCTAssertNotNil(items);
    XCTAssertEqual( items.count, 3 );
}

- (void)testNilAdapter
{
    NSData* data = [NSData dataWithContentsOfFile: [[NSBundle bundleForClass:[self class]] pathForResource:@"levels" ofType:@"json"]];
    NSArray<ItemNilAdapter*>* items = [ItemNilAdapter modelsFromData:data error:nil];
    XCTAssertNil(items);
}

@end
