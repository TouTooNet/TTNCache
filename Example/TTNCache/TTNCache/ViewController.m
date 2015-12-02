//
//  ViewController.m
//  TTNCache
//
//  Created by SimMan on 15/12/1.
//  Copyright © 2015年 TouToo.Net. All rights reserved.
//

#import "ViewController.h"

#import "TTNCache.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    TTNCache *cache = [[TTNCache alloc] initWithCacheDirectory:@"TTNCacheDirectory"];
    
    
    cache setObject:<#(id<NSCoding>)#> forKeyedSubscript:<#(NSString *)#>
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
