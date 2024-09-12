//
//  SymbolModel.h
//  LinkMap
//
//  Created by Suteki(67111677@qq.com) on 4/8/16.
//  Copyright © 2016 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SymbolModel : NSObject

@property (nonatomic, copy) NSString *file;//文件
@property (nonatomic, assign) NSUInteger size;//大小
@property (nonatomic, strong) NSString * classFile;
- (NSString *)sizeString;
@end

@interface CompareModel : NSObject
@property (nonatomic, strong) SymbolModel * file1;
@property (nonatomic, strong) SymbolModel * file2;
@property (nonatomic,assign) NSInteger differenceSize;
@end
