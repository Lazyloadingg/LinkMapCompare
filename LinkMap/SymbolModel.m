//
//  SymbolModel.m
//  LinkMap
//
//  Created by Suteki(67111677@qq.com) on 4/8/16.
//  Copyright © 2016 Apple. All rights reserved.
//

#import "SymbolModel.h"

@implementation SymbolModel


- (NSString *)sizeString{
    NSString * size = @"0K";
    if (self.size / 1024.0 / 1024.0 > 1) {
        size = [NSString stringWithFormat:@"%.2fM", self.size / 1024.0 / 1024.0];
    } else {
        size = [NSString stringWithFormat:@"%.2fK", self.size / 1024.0];
    }
    return  size;
}


- (NSString *)classFile{
    if (_classFile.length > 0 && ![_classFile isKindOfClass:[NSNull class]] && ![_classFile isEqualToString:@"(null)"]) {
        return _classFile;
    }
    return @"/";
}
@end

@implementation CompareModel



@end
