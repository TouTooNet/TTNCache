//
//  TTNCacheTests.m
//  TTNCacheTests
//
//  Created by SimMan on 15/12/1.
//  Copyright © 2015年 TouToo.Net. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TTNCache.h"

static NSString * const cacheDirectory = @"TTNCacheTest";
static NSString * const subScript = @"testSetObject";

@interface TTNCacheTests : XCTestCase
@property (nonatomic, strong) TTNCache *cache;
@end

@implementation TTNCacheTests

- (void)setUp {
    [super setUp];
    self.cache = [[TTNCache alloc] initWithCacheDirectory:cacheDirectory];
    XCTAssertNotNil(self.cache, @"test cache does not exist");
}


- (void) testSetAndGetObject {
    
    NSDictionary *dic = @{@"name": @"TouToo"};
    [self.cache setObject:dic forKeyedSubscript:subScript];
    
    id obj = [self.cache objectForKeyedSubscript:subScript];
    NSLog(@"obj = %@", obj);
    XCTAssertNotNil(obj, @"object cache does not exist");
}

- (void)tearDown {
    [self.cache emptyCache];
    self.cache = nil;
    XCTAssertNil(self.cache, @"test cache did not deallocate");
    [super tearDown];
}

@end
