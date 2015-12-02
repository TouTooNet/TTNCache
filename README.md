# TTNCache

A simple in-memory and in-disk cache for objective-c, You can customize for any object lifecycle



## Installation

``` 
platform :ios, '6.0'
pod 'TTNCache'
```

## Usage

### Include Header File

```
#import "TTNCache.h"
```

### Create TTNCache

```
TTNCache *cache = [[TTNCache alloc] initWithCacheDirectory:@"TTNCacheDirectory"];
```

### Set Object

> support all \<NSCoding\> object

```
- (void)setObject:(id<NSCoding>)obj forKeyedSubscript:(NSString *) key;
- (void)setObject:(id<NSCoding>)obj forKeyedSubscript:(NSString *) key block:(TTNCacheObjectBlock)block;
- (void)setObject:(id<NSCoding>)obj forKeyedSubscript:(NSString *) key andAgeLimit:(NSTimeInterval)ageLimit;
- (void)setObject:(id<NSCoding>)obj forKeyedSubscript:(NSString *) key andAgeLimit:(NSTimeInterval)ageLimit block:(TTNCacheObjectBlock)block;
```

### Get Object

```
- (id) objectForKeyedSubscript:(NSString *) key;
- (void)objectForKeyedSubscript:(NSString *)key block:(TTNCacheObjectBlock)block;
```

### Remove Object

```
- (void) removeObjectForSubscript:(NSString *) key;
- (void) removeObjectForSubscript:(NSString *) key block:(TTNCacheBlock)block;
```



## Example

The repository includes a [sample application](https://github.com/TouTooNet/TTNCache/tree/master/Example/TTNCache)
which shows all of the inter-app hooks in action.


## License

TTNCache is released under the MIT license. See LICENSE for details.