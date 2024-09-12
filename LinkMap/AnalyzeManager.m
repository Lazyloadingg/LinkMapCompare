//
//  AnalyzeManager.m
//  LinkMap
//
//  Created by lazyloading on 2024/9/10.
//  Copyright © 2024 ND. All rights reserved.
//

#import "AnalyzeManager.h"
#import "SymbolModel.h"

@implementation AnalyzeManager
+ (NSMutableDictionary *)symbolMapFromContent:(NSString *)content {
    NSMutableDictionary <NSString *,SymbolModel *>*symbolMap = [NSMutableDictionary new];
    // 符号文件列表
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    
    BOOL reachFiles = NO;
    BOOL reachSymbols = NO;
    BOOL reachSections = NO;
    
    for(NSString *line in lines) {
        if([line hasPrefix:@"#"]) {
            if([line hasPrefix:@"# Object files:"])
                reachFiles = YES;
            else if ([line hasPrefix:@"# Sections:"])
                reachSections = YES;
            else if ([line hasPrefix:@"# Symbols:"])
                reachSymbols = YES;
        } else {
            if(reachFiles == YES && reachSections == NO && reachSymbols == NO) {
                NSRange range = [line rangeOfString:@"]"];
                if(range.location != NSNotFound) {
               
                    NSString * file = [line substringFromIndex:range.location+1];
                    SymbolModel *symbol = [SymbolModel new];
                    symbol.file = file;
                    NSString *key = [line substringToIndex:range.location+1];
                    symbolMap[key] = symbol;
                    
                    NSString *name = [[file componentsSeparatedByString:@"/"] lastObject];
                    if ([name hasSuffix:@")"] &&
                        [name containsString:@"("]) {
                        NSRange rangeS = [name rangeOfString:@"("];
                        NSString *classFile = [name substringFromIndex:rangeS.location];
                        classFile = [classFile substringWithRange:NSMakeRange(1, classFile.length -2)];
                        symbol.classFile = classFile;
                    }else{
                        symbol.classFile = name;
                    }
                }
            } else if (reachFiles == YES && reachSections == YES && reachSymbols == YES) {
                NSArray <NSString *>*symbolsArray = [line componentsSeparatedByString:@"\t"];
                if(symbolsArray.count == 3) {
                    NSString *fileKeyAndName = symbolsArray[2];
                    NSUInteger size = strtoul([symbolsArray[1] UTF8String], nil, 16);
                    
                    NSRange range = [fileKeyAndName rangeOfString:@"]"];
                    if(range.location != NSNotFound) {
                        NSString *key = [fileKeyAndName substringToIndex:range.location+1];
                        SymbolModel *symbol = symbolMap[key];
                        if(symbol) {
                            symbol.size += size;
                        }
                    }
                }
            }
        }
    }
    return symbolMap;
}

+ (NSArray <SymbolModel *>*)buildCompareCombinationResultWithSymbols:(NSArray <SymbolModel *>*)symbols {
    
    NSMutableDictionary *combinationMap = [[NSMutableDictionary alloc] init];
    
    for(SymbolModel *symbol in symbols) {
        NSString *name = [[symbol.file componentsSeparatedByString:@"/"] lastObject];
        if ([name hasSuffix:@")"] &&
            [name containsString:@"("]) {
            NSRange range = [name rangeOfString:@"("];
            NSString *component = [name substringToIndex:range.location];
            
            SymbolModel *combinationSymbol = [combinationMap objectForKey:component];
            if (!combinationSymbol) {
                combinationSymbol = [[SymbolModel alloc] init];
                [combinationMap setObject:combinationSymbol forKey:component];
            }
            
            combinationSymbol.size += symbol.size;
            combinationSymbol.file = component;
            combinationSymbol.classFile = component;
        } else {
            // symbol可能来自app本身的目标文件或者系统的动态库，在最后的结果中一起显示
            [combinationMap setObject:symbol forKey:symbol.file];
        }
    }
    
    NSArray <SymbolModel *>*combinationSymbols = [combinationMap allValues];
    return combinationSymbols;
}

+ (NSArray <SymbolModel*>*)sortSymbols:(NSArray *)symbols {
    NSArray *sortedSymbols = [symbols sortedArrayUsingComparator:^NSComparisonResult(SymbolModel *  _Nonnull obj1, SymbolModel *  _Nonnull obj2) {
        if(obj1.size > obj2.size) {
            return NSOrderedAscending;
        } else if (obj1.size < obj2.size) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }];
    
    return sortedSymbols;
}

+ (NSArray <CompareModel*>*)sortSymbolsCompare:(NSArray<CompareModel *> *)symbols {
    NSArray *sortedSymbols = [symbols sortedArrayUsingComparator:^NSComparisonResult(CompareModel *  _Nonnull obj1, CompareModel *  _Nonnull obj2) {
        if(obj1.differenceSize > obj2.differenceSize) {
            return NSOrderedAscending;
        } else if (obj1.differenceSize < obj2.differenceSize) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }];
    
    return sortedSymbols;
}
+ (void)appendCompareResultsWithSymbols:(NSArray <CompareModel *>*)symbols searchKey:(NSString *)searchKey completed:(void(^)(NSString *))completed{
    __block NSMutableString * res = [@"增量大小\t\t文件1大小\t\t文件2大小\t\t文件1名称\t\t文件2名称\n\n" mutableCopy];
    __block NSInteger total = 0;
    dispatch_async(dispatch_get_main_queue(), ^{
        
        for (CompareModel * model in symbols) {
            if (searchKey.length > 0) {
                if ([model.file1.file containsString:searchKey] || [model.file2.file containsString:searchKey]) {
                    total += model.differenceSize;
                    [res appendString:[AnalyzeManager compareResultWithSymbol:model]];
                }
            }else{
                total += model.differenceSize;
                [res appendString:[AnalyzeManager compareResultWithSymbol:model]];
            }
        }
        [res appendFormat:@"总增量：%@\n",[AnalyzeManager converSize:total]];
        completed(res);
    });
}
+ (NSString *)compareResultWithSymbol:(CompareModel *)model {
    NSString *size = nil;
    if (model.differenceSize / 1024.0 / 1024.0 > 1) {
        size = [NSString stringWithFormat:@"%.2fM", model.differenceSize / 1024.0 / 1024.0];
    } else {
        size = [NSString stringWithFormat:@"%.2fK", model.differenceSize / 1024.0];
    }
    return [NSString stringWithFormat:@"%@\t\t%@\t%@\t%@\t%@\t\n",size,model.file1.sizeString ?: @"0K",model.file2.sizeString ?: @"0K",model.file1.classFile ?: @"/", model.file2.classFile ?: @"/"];
}
+ (BOOL)checkContent:(NSString *)content {
    NSRange objsFileTagRange = [content rangeOfString:@"# Object files:"];
    if (objsFileTagRange.length == 0) {
        return NO;
    }
    NSString *subObjsFileSymbolStr = [content substringFromIndex:objsFileTagRange.location + objsFileTagRange.length];
    NSRange symbolsRange = [subObjsFileSymbolStr rangeOfString:@"# Symbols:"];
    if ([content rangeOfString:@"# Path:"].length <= 0||objsFileTagRange.location == NSNotFound||symbolsRange.location == NSNotFound) {
        return NO;
    }
    return YES;
}

+ (NSString *)converSize:(NSInteger)size{
    NSString * res = @"0K";
    if (size / 1024.0 / 1024.0 > 1) {
        res = [NSString stringWithFormat:@"%.2fM", size / 1024.0 / 1024.0];
    } else {
        res = [NSString stringWithFormat:@"%.2fK", size / 1024.0];
    }
    return res;
}
@end
