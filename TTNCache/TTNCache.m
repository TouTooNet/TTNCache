//
//  TTNCache.m
//  TTNCache
//
//  Created by SimMan on 15/11/25.
//  Copyright © 2015年 TouToo.Net All rights reserved.
//

#import "TTNCache.h"

#ifdef DEBUG
#define DLog(fmt, ...) {NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);}
#else
#define DLog(...)
#endif

#if TARGET_OS_IOS
@import UIKit;
#endif

NSString *const TTCacheDefaultPath = @"net.toutoo.ttncache";
NSString *const TTCacheDefaultPathExtension = @"TTNCache";
NSUInteger const TTCacheDefaultCost = 10;

@interface TTNCache()

@property (nonatomic, strong) NSMutableDictionary *memoryCaches;
#if OS_OBJECT_USE_OBJC
@property (strong, nonatomic) dispatch_queue_t cacheQueue;
#else
@property (assign, nonatomic) dispatch_queue_t cacheQueue;
#endif
@property (strong, nonatomic) NSURL *cacheURL;

@end

@implementation TTNCache

static inline NSDictionary * checkCacheFileDuration(NSDictionary *data)
{
    if (data) {
        NSTimeInterval expires = [data[@"expires"] doubleValue];
        
        if (!expires) {
            return data[@"data"];
        }
        
        NSDate *now = [[NSDate alloc] init];
        if ([now timeIntervalSince1970] > expires) {
            return nil;
        }
        return data[@"data"];
    }
    return nil;
}

static inline NSString * encodedString(NSString *string) {
    if (![string length])
        return @"";
    
#ifdef __IPHONE_9_0
    return [string stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@".:/"]];
#else
    CFStringRef static const charsToEscape = CFSTR(".:/");
    CFStringRef escapedString = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                        (__bridge CFStringRef)string,
                                                                        NULL,
                                                                        charsToEscape,
                                                                        kCFStringEncodingUTF8);
    return (__bridge_transfer NSString *)escapedString;
#endif
}


static inline NSString * decodedString(NSString *string) {
    if (![string length])
        return @"";
#ifdef __IPHONE_9_0
    return [string stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@""]];
#else
    CFStringRef unescapedString = CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
                                                                                          (__bridge CFStringRef)string,
                                                                                          CFSTR(""),
                                                                                          kCFStringEncodingUTF8);
    return (__bridge_transfer NSString *)unescapedString;
#endif
}

static inline NSString * keyForEncodedFileURL(NSURL *url) {
    NSString *fileName = [url lastPathComponent];
    if (!fileName)
        return nil;
    return decodedString(fileName);
}

static inline NSDictionary * objToDictionary(id <NSCoding> obj, NSTimeInterval ageLimit) {
    NSTimeInterval expires = 0.0;
    if (ageLimit) {
        expires = [[NSDate date] timeIntervalSince1970] + ageLimit;
    }
    NSDictionary *dic = @{@"expires": [NSNumber numberWithDouble:expires] , @"data": obj};
    return dic;
}

+ (instancetype)sharedCache
{
    static id cache;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        cache = [[self alloc] initWithCacheDirectory:TTCacheDefaultPath];
    });
    return cache;
}


-(instancetype) init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"TTNetworkKitCache should be initialized with the designated initializer initWithCacheDirectory:inMemoryCost:"
                                 userInfo:nil];
    return nil;
}

-(instancetype) initWithCacheDirectory:(NSString*) cacheDirectory
{
    
    NSParameterAssert(cacheDirectory != nil);
    
    if(self = [super init]) {
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        _directoryPath = [paths.firstObject stringByAppendingPathComponent:cacheDirectory];
        
        self.memoryCaches = [NSMutableDictionary dictionaryWithCapacity:TTCacheDefaultCost];
        
        BOOL isDirectory = YES;
        BOOL directoryExists = [[NSFileManager defaultManager] fileExistsAtPath:self.directoryPath isDirectory:&isDirectory];
        
        if(!isDirectory) {
            NSError *error = nil;
            if(![[NSFileManager defaultManager] removeItemAtPath:self.directoryPath error:&error]) {
                DLog(@"%@", error);
            }
            directoryExists = NO;
        }
        
        _cacheURL = [NSURL fileURLWithPath:_directoryPath];
        if(!directoryExists)
        {
            NSError *error = nil;
            if(![[NSFileManager defaultManager] createDirectoryAtPath:self.directoryPath
                                          withIntermediateDirectories:YES
                                                           attributes:nil
                                                                error:&error]) {
                DLog(@"%@", error);
            }
        }
        
        self.cacheQueue = dispatch_queue_create("net.toutoo.cachequeue", DISPATCH_QUEUE_SERIAL);
        
#if TARGET_OS_IPHONE
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(flushCache)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(flushCache)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(flushCache)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        
#elif TARGET_OS_MAC
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(flushCache)
                                                     name:NSApplicationWillHideNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(flushCache)
                                                     name:NSApplicationWillResignActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(flushCache)
                                                     name:NSApplicationWillTerminateNotification
                                                   object:nil];
        
#endif
        [self initializeDiskProperties];
    }
    
    return self;
}

- (void)initializeDiskProperties
{
    NSArray *keys = @[ NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey ];
    
    dispatch_async(self.cacheQueue, ^{
        NSError *error = nil;
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:_cacheURL
                                                       includingPropertiesForKeys:keys
                                                                          options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                            error:&error];
        for (NSURL *fileURL in files) {
            NSString *key = keyForEncodedFileURL(fileURL);
            
            error = nil;
            NSDictionary *dictionary = [fileURL resourceValuesForKeys:keys error:&error];
            
            NSDate *date = [dictionary objectForKey:NSURLContentModificationDateKey];
            if (!date && key) {
                [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
            }
        }
    });
}

#pragma mark -get

-(id <NSCoding>) objectForKeyedSubscript:(NSString *) key {
    
    if (!key)
        return nil;
    
    __block id obj = nil;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [self objectForKeyedSubscript:key block:^(TTNCache *cache, NSString *key, id<NSCoding> object) {
        obj = object;
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
#if !OS_OBJECT_USE_OBJC
    dispatch_release(semaphore);
#endif
    return obj;
}

- (void)objectForKeyedSubscript:(NSString *)key block:(TTNCacheObjectBlock)block
{
    if (!key || !block) {
        return;
    }
    __weak TTNCache *weakSelf = self;
    
    dispatch_async(_cacheQueue, ^{
        TTNCache *strongSelf = weakSelf;
        if (!strongSelf)
            return;
        
        __weak TTNCache *weakSelf = strongSelf;
        
        NSDictionary *cacheDic = (NSDictionary *)weakSelf.memoryCaches[key];
        NSDictionary *cacheData = nil;
        if (cacheDic) {
            
            cacheData = checkCacheFileDuration(cacheDic);
            if (!cacheData) {
                [weakSelf.memoryCaches removeObjectForKey:key];
            }
            block(strongSelf, key, cacheData);

        } else {
            NSString *stringKey = [NSString stringWithFormat:@"%@", key];
            
            NSString *filePath = [[weakSelf.directoryPath stringByAppendingPathComponent:stringKey]
                                  stringByAppendingPathExtension:TTCacheDefaultPathExtension];
            
            if([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                
                @try {
                    cacheDic = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
                }
                @catch (NSException *exception) {
                    NSError *error = nil;
                    [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
                }
                
                cacheData = checkCacheFileDuration((NSDictionary *)cacheDic);
                
                if (!cacheData) {
                    NSError *error;
                    [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
                    if (error) {
                        DLog(@"%@", error);
                    }
                } else {
                    weakSelf.memoryCaches[key] = cacheData;
                }
                block(strongSelf, key, cacheData);
            }
        }
    });
}

#pragma mark - set

- (void)setObject:(id <NSCoding>) obj forKeyedSubscript:(NSString *) key
{
    if (!obj || !key)
        return;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [self setObject:obj forKeyedSubscript:key andAgeLimit:0 block:^(TTNCache *cache, NSString *key, id<NSCoding> object) {
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
#if !OS_OBJECT_USE_OBJC
    dispatch_release(semaphore);
#endif
    
}

- (void)setObject:(id<NSCoding>)obj forKeyedSubscript:(NSString *)key block:(TTNCacheObjectBlock)block
{
    [self setObject:obj forKeyedSubscript:key andAgeLimit:0 block:block];
}

- (void)setObject:(id <NSCoding>) obj forKeyedSubscript:(NSString *) key andAgeLimit:(NSTimeInterval)ageLimit
{
    if (!obj || !key)
        return;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [self setObject:obj forKeyedSubscript:key andAgeLimit:ageLimit block:^(TTNCache *cache, NSString *key, id<NSCoding> object) {
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
#if !OS_OBJECT_USE_OBJC
    dispatch_release(semaphore);
#endif
}

- (void)setObject:(id<NSCoding>)obj forKeyedSubscript:(NSString *)key andAgeLimit:(NSTimeInterval)ageLimit block:(TTNCacheObjectBlock)block
{
    if (!obj || !key || !block) {
        return;
    }
    
    __weak TTNCache *weakSelf = self;
    
    obj = objToDictionary(obj, ageLimit);
    dispatch_async(self.cacheQueue, ^{
        
        TTNCache *strongSelf = weakSelf;
        if (!strongSelf)
            return;
        
        __weak TTNCache *weakSelf = strongSelf;
        
        weakSelf.memoryCaches[key] = obj;
        
        NSString *stringKey = [NSString stringWithFormat:@"%@", key];
        
        NSString *filePath = [[weakSelf.directoryPath stringByAppendingPathComponent:stringKey] stringByAppendingPathExtension:TTCacheDefaultPathExtension];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            
            NSError *error = nil;
            if(![[NSFileManager defaultManager] removeItemAtPath:filePath error:&error]) {
                DLog(@"Cannot remove file: %@", error);
            }
        }
        
        if ([NSKeyedArchiver archiveRootObject:obj toFile:filePath]) {
            block(strongSelf, key, obj);
        } else {
            block(strongSelf, key, nil);
        }
    });
}


- (void) removeObjectForSubscript:(NSString *) key
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [self removeObjectForSubscript:key block:^(TTNCache *cache) {
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
#if !OS_OBJECT_USE_OBJC
    dispatch_release(semaphore);
#endif
}

- (void)removeObjectForSubscript:(NSString *)key block:(TTNCacheBlock)block
{
    __weak TTNCache *weakSelf = self;
    if (key && block) {
        dispatch_async(_cacheQueue, ^{
            TTNCache *strongSelf = weakSelf;
            if (!strongSelf)
                return;
            
            __weak TTNCache *weakSelf = strongSelf;
            
            NSString *stringKey = [NSString stringWithFormat:@"%@", key];
            NSString *filePath = [[weakSelf.directoryPath stringByAppendingPathComponent:stringKey] stringByAppendingPathExtension:TTCacheDefaultPathExtension];
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
            [weakSelf.memoryCaches removeObjectForKey:key];
            
            block(strongSelf);
        });
    }
}


- (void) emptyCache
{
    dispatch_async(_cacheQueue, ^{
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtURL:_cacheURL error:&error];
        if (error) {
            DLog(@"%@", error);
        }
        [self.memoryCaches removeAllObjects];
    });
}

#pragma mark - Private Methods -
-(void) flushCache {
    
    __weak TTNCache *weakSelf = self;
    
    dispatch_async(self.cacheQueue, ^{
        
        [weakSelf.memoryCaches removeAllObjects];
        
        [weakSelf.memoryCaches enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            
            NSString *stringKey = [NSString stringWithFormat:@"%@", key];
            NSString *filePath = [[self.directoryPath stringByAppendingPathComponent:stringKey]
                                  stringByAppendingPathExtension:TTCacheDefaultPathExtension];
            
            if([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                
                NSError *error = nil;
                if(![[NSFileManager defaultManager] removeItemAtPath:filePath error:&error]) {
                    DLog(@"%@", error);
                }
            }
            
            NSData *dataToBeWritten = nil;
            id objToBeWritten = self.memoryCaches[key];
            dataToBeWritten = [NSKeyedArchiver archivedDataWithRootObject:objToBeWritten];
            [dataToBeWritten writeToFile:filePath atomically:YES];
        }];
    });
}

-(void) dealloc {
    
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
#elif TARGET_OS_MAC
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationWillTerminateNotification object:nil];
#endif
}

- (NSURL *)encodedFileURLForKey:(NSString *)key
{
    if (![key length])
        return nil;
    
    return [_cacheURL URLByAppendingPathComponent:encodedString(key)];
}


@end
