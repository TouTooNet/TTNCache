//
//  TTNCache.h
//  TTNCache
//
//  Created by SimMan on 15/11/25.
//  Copyright © 2015年 TouToo.Net All rights reserved.
//

#import <Foundation/Foundation.h>

@class TTNCache;

typedef void (^TTNCacheObjectBlock)(TTNCache *cache, NSString *key, id<NSCoding> object);
typedef void (^TTNCacheBlock)(TTNCache *cache);

@interface TTNCache : NSObject

/**
 The directoryPath of this cache, used to create a directory under Library/Caches and also appearing in stack traces.
 */
@property(nonatomic, copy, readonly)   NSString *directoryPath;

/**
 A shared cache.
 
 @result The shared singleton cache instance.
 */
+ (instancetype)sharedCache;

/**
 Multiple instances with the same name are allowed and can safely access
 the same data on disk thanks to the magic of seriality. Also used to create the <TTNetworkKitCache>.
 
 @see cacheDirectory
 @param cacheDirectory The directory of the cache.
 @result A new cache with the specified name.
 */
-(instancetype) initWithCacheDirectory:(NSString*) cacheDirectory;

/**
 Retrieves the object for the specified key.
 
 @param key The key associated with the requested object.
 */
- (id) objectForKeyedSubscript:(NSString *) key;
- (void)objectForKeyedSubscript:(NSString *)key block:(TTNCacheObjectBlock)block;

/**
 Stores an object in the cache for the specified key.
 
 @see setObject:forKeyedSubscript:
 @param object An object to store in the cache.
 @param key A key to associate with the object. This string will be copied.
 */
- (void)setObject:(id<NSCoding>)obj forKeyedSubscript:(NSString *) key;
- (void)setObject:(id<NSCoding>)obj forKeyedSubscript:(NSString *) key block:(TTNCacheObjectBlock)block;

/**
 Stores an object in the cache for the specified key.
 
 @see setObject:forKeyedSubscript:
 @param object An object to store in the cache.
 @param key A key to associate with the object. This string will be copied.
 @Param ageLimit The maximum number of seconds an object is allowed to exist in the cache. Setting this to a value
        greater than `0.0` will start a recurring GCD timer with the same period that calls <ageLimit:>.
        Setting it back to `0.0` will stop the timer. Defaults to `0.0`, meaning no limit.
 */
- (void)setObject:(id<NSCoding>)obj forKeyedSubscript:(NSString *) key andAgeLimit:(NSTimeInterval)ageLimit;
- (void)setObject:(id<NSCoding>)obj forKeyedSubscript:(NSString *) key andAgeLimit:(NSTimeInterval)ageLimit block:(TTNCacheObjectBlock)block;

/**
 Removes the object for the specified key. This method returns immediately and executes the passed
 
 @param key The key associated with the object to be removed.
 */
- (void) removeObjectForSubscript:(NSString *) key;
- (void) removeObjectForSubscript:(NSString *) key block:(TTNCacheBlock)block;

/**
 Removes all objects from the cache. 
 */
- (void) emptyCache;

@end
