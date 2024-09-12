//
//  AnalyzeManager.h
//  LinkMap
//
//  Created by lazyloading on 2024/9/10.
//  Copyright © 2024 ND. All rights reserved.
//

#import <Foundation/Foundation.h>
@class SymbolModel,CompareModel;

NS_ASSUME_NONNULL_BEGIN

@interface AnalyzeManager : NSObject
+ (NSMutableDictionary *)symbolMapFromContent:(NSString *)content;
+ (NSArray <SymbolModel *>*)buildCompareCombinationResultWithSymbols:(NSArray <SymbolModel *>*)symbols ;
+ (NSArray <SymbolModel*>*)sortSymbols:(NSArray *)symbols;
+ (NSArray <CompareModel*>*)sortSymbolsCompare:(NSArray<CompareModel *> *)symbols;
+ (BOOL)checkContent:(NSString *)content;
+ (NSString *)converSize:(NSInteger)size;
+ (void)appendCompareResultsWithSymbols:(NSArray <CompareModel *>*)symbols searchKey:(NSString *)searchKey completed:(void(^)(NSString *))completed;
+ (NSString *)compareResultWithSymbol:(CompareModel *)model;
@end

NS_ASSUME_NONNULL_END
