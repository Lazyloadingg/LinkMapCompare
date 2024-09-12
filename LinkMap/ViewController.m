//
//  ViewController.m
//  LinkMap
//
//  Created by Suteki(67111677@qq.com) on 4/8/16.
//  Copyright © 2016 Apple. All rights reserved.
//

#import "ViewController.h"
#import "SymbolModel.h"
#import "AnalyzeManager.h"

@interface ViewController()
@property (weak) IBOutlet NSTextField *filePathField2;
@property (weak) IBOutlet NSTextField *filePathField;//显示选择的文件路径
@property (weak) IBOutlet NSProgressIndicator *indicator;//指示器
@property (weak) IBOutlet NSTextField *searchField;
@property (weak) IBOutlet NSButton *file2Btn;

@property (weak) IBOutlet NSScrollView *contentView;//分析的内容
@property (unsafe_unretained) IBOutlet NSTextView *contentTextView;
@property (weak) IBOutlet NSButton *groupButton;
@property (weak) IBOutlet NSButton *diffButton;

@property (strong) NSURL *linkMapFileURL;
@property (strong) NSURL *linkMapFileURL2;
@property (strong) NSString *linkMapContent;

@property (strong) NSMutableString *result;//分析的结果

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.indicator.hidden = YES;
    
    self.file2Btn.enabled  = NO;
    _contentTextView.editable = NO;
    
    _contentTextView.string = @"使用方式：\n\
    1.在XCode中开启编译选项Write Link Map File \n\
    XCode -> Project -> Build Settings -> 把Write Link Map File选项设为yes，并指定好linkMap的存储位置 \n\
    2.工程编译完成后，在编译目录里找到Link Map文件（txt类型） \n\
    默认的文件地址：~/Library/Developer/Xcode/DerivedData/XXX-xxxxxxxxxxxxx/Build/Intermediates/XXX.build/Debug-iphoneos/XXX.build/ \n\
    3.回到本应用，点击“选择文件”，打开Link Map文件  \n\
    4.点击“开始”，解析Link Map文件 \n\
    5.点击“输出文件”，得到解析后的Link Map文件 \n\
    6. * 输入目标文件的关键字(例如：libIM)，然后点击“开始”。实现搜索功能 \n\
    7. * 勾选“分组解析”，然后点击“开始”。实现对不同库的目标文件进行分组 \n\
    8. * 勾选“增量对比”，可选择第二个Link Map文件，然后点击“开始”，实现新版本相对于旧版本的增量计算";
}
- (IBAction)chooseFile2:(id)sender {
    [self chooseFIlePanel:1];
}

- (IBAction)chooseFile:(id)sender {
    [self chooseFIlePanel:0];
}

- (void)chooseFIlePanel:(NSInteger)type{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseDirectories = NO;
    panel.resolvesAliases = NO;
    panel.canChooseFiles = YES;
    
    [panel beginWithCompletionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *document = [[panel URLs] objectAtIndex:0];
            if (type == 0) {
                _filePathField.stringValue = document.path;
                self.linkMapFileURL = document;
            }else{
                _filePathField2.stringValue = document.path;
                self.linkMapFileURL2 = document;
            }
        }
    }];
}
- (IBAction)analyze:(id)sender {
    if (self.diffButton.state == 1) {
        [self compareAnalyze];
    }else{
        [self noCompareAnalyze];
    }
}
- (IBAction)diffSwitch:(NSButton *)sender {
    self.file2Btn.enabled = sender.state;
    if (sender.state != 1) {
        self.linkMapFileURL2 = nil;
        _filePathField2.stringValue = @"";
    }else{
        _filePathField2.stringValue = @"文件2路径";
    }
}

- (void)noCompareAnalyze{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (_linkMapFileURL) {
            if (!_linkMapFileURL || ![[NSFileManager defaultManager] fileExistsAtPath:[_linkMapFileURL path] isDirectory:nil]) {
                [self showAlertWithText:@"请选择正确的Link Map文件路径"];
                return;
            }
        }
        NSArray <SymbolModel *>*analyzeSymbols = [self analyzeOperation:_linkMapFileURL type:0];
        NSArray <SymbolModel*>*sortedSymbols = [AnalyzeManager sortSymbols:analyzeSymbols];
        
        __block NSControlStateValue groupButtonState;
        dispatch_sync(dispatch_get_main_queue(), ^{
            groupButtonState = _groupButton.state;
        });
        
        if (1 == groupButtonState) {
            [self buildCombinationResultWithSymbols:sortedSymbols];
        } else {
            [self buildResultWithSymbols:sortedSymbols];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.contentTextView.string = _result;
            self.indicator.hidden = YES;
            [self.indicator stopAnimation:self];
        });
    });
}

- (void)compareAnalyze{
    if (_linkMapFileURL) {
        if (!_linkMapFileURL || ![[NSFileManager defaultManager] fileExistsAtPath:[_linkMapFileURL path] isDirectory:nil]) {
            [self showAlertWithText:@"请选择正确的Link Map文件路径"];
            return;
        }
    }
    
    if (_linkMapFileURL2) {
        if (!_linkMapFileURL2 || ![[NSFileManager defaultManager] fileExistsAtPath:[_linkMapFileURL2 path] isDirectory:nil]) {
            [self showAlertWithText:@"请选择正确的Link Map2文件路径"];
            return;
        }
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSMutableDictionary <NSString *,CompareModel*>* temp = [NSMutableDictionary dictionary];
        NSArray <SymbolModel*>*sortedSymbols = [self analyzeOperation:_linkMapFileURL type:0];
        NSArray <SymbolModel*>*sortedSymbols2 = [self analyzeOperation:_linkMapFileURL2 type:1];
        
        __block NSControlStateValue groupButtonState;
        dispatch_sync(dispatch_get_main_queue(), ^{
            groupButtonState = _groupButton.state;
        });
        
        if (groupButtonState == 1) {
            sortedSymbols = [AnalyzeManager buildCompareCombinationResultWithSymbols:sortedSymbols];
            sortedSymbols2 = [AnalyzeManager buildCompareCombinationResultWithSymbols:sortedSymbols2];
        }
        
        for (SymbolModel * symbol in sortedSymbols) {
            CompareModel * model = CompareModel.new;
            model.file1 = symbol;
            temp[symbol.classFile] = model;
        }
        
        for (SymbolModel * symbol in sortedSymbols2) {
            CompareModel * model = temp[symbol.classFile];
            if (model) {
                model.file2 = symbol;
                model.differenceSize = symbol.size - model.file1.size;
            }else{
                CompareModel * model = CompareModel.new;
                model.file2 = symbol;
                model.differenceSize = symbol.size - model.file1.size;
                temp[symbol.classFile] = model;
            }
        }
        NSArray <CompareModel *>*sortedCompare = [AnalyzeManager sortSymbolsCompare:temp.allValues];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString * searchKey = _searchField.stringValue;
            [AnalyzeManager appendCompareResultsWithSymbols:sortedCompare searchKey:searchKey completed:^(NSString * res) {
                self.result = [res mutableCopy];
                self.contentTextView.string = _result;
                self.indicator.hidden = YES;
                [self.indicator stopAnimation:self];
            }];
        });
    });
}
- (NSArray <SymbolModel *>*)analyzeOperation:(NSURL *)fileURL type:(NSInteger)type {
    if (!fileURL || ![[NSFileManager defaultManager] fileExistsAtPath:[fileURL path] isDirectory:nil]) {
        [self showAlertWithText:[NSString stringWithFormat:@"请选择正确的Link Map文件%ld路径",type+1]];
        return nil;
    }
    
    NSString *content = [NSString stringWithContentsOfURL:fileURL encoding:NSMacOSRomanStringEncoding error:nil];
    
    if (![AnalyzeManager checkContent:content]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showAlertWithText:@"Link Map文件格式有误"];
        });
        return nil;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.indicator.hidden = NO;
        [self.indicator startAnimation:self];
    });
    
    NSDictionary *symbolMap = [AnalyzeManager symbolMapFromContent:content];
    NSArray <SymbolModel *>*symbols = [symbolMap allValues];
    
    return symbols;
}

- (void)buildResultWithSymbols:(NSArray *)symbols {
    self.result = [@"文件大小\t文件名称\r\n\r\n" mutableCopy];
    NSUInteger totalSize = 0;
    
    __block NSString *searchKey;
    dispatch_sync(dispatch_get_main_queue(), ^{
        searchKey = _searchField.stringValue;
    });
    
    for(SymbolModel *symbol in symbols) {
        if (searchKey.length > 0) {
            if ([symbol.file containsString:searchKey]) {
                [self appendResultWithSymbol:symbol];
                totalSize += symbol.size;
            }
        } else {
            [self appendResultWithSymbol:symbol];
            totalSize += symbol.size;
        }
    }
    
    [_result appendFormat:@"\r\n总大小: %.2fM\r\n",(totalSize/1024.0/1024.0)];
}

- (void)buildCombinationResultWithSymbols:(NSArray *)symbols {
    self.result = [@"库大小\t库名称\r\n\r\n" mutableCopy];
    NSUInteger totalSize = 0;
    
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
        } else {
            // symbol可能来自app本身的目标文件或者系统的动态库，在最后的结果中一起显示
            [combinationMap setObject:symbol forKey:symbol.file];
        }
    }
    
    NSArray <SymbolModel *>*combinationSymbols = [combinationMap allValues];
    
    NSArray *sortedSymbols = [AnalyzeManager sortSymbols:combinationSymbols];
    __block NSString *searchKey;
    dispatch_async(dispatch_get_main_queue(), ^{
        searchKey = _searchField.stringValue;
    });
    
    for(SymbolModel *symbol in sortedSymbols) {
        if (searchKey.length > 0) {
            if ([symbol.file containsString:searchKey]) {
                [self appendResultWithSymbol:symbol];
                totalSize += symbol.size;
            }
        } else {
            [self appendResultWithSymbol:symbol];
            totalSize += symbol.size;
        }
    }
    
    [_result appendFormat:@"\r\n总大小: %.2fM\r\n",(totalSize/1024.0/1024.0)];
}

- (IBAction)ouputFile:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:YES];
    [panel setResolvesAliases:NO];
    [panel setCanChooseFiles:NO];
    
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL*  theDoc = [[panel URLs] objectAtIndex:0];
            NSMutableString *content =[[NSMutableString alloc]initWithCapacity:0];
            [content appendString:[theDoc path]];
            [content appendString:@"/linkMap.txt"];
            [_result writeToFile:content atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
    }];
}

- (void)appendResultWithSymbol:(SymbolModel *)model{
    NSString *size = nil;
    if (model.size / 1024.0 / 1024.0 > 1) {
        size = [NSString stringWithFormat:@"%.2fM", model.size / 1024.0 / 1024.0];
    } else {
        size = [NSString stringWithFormat:@"%.2fK", model.size / 1024.0];
    }
    [_result appendFormat:@"%@\t%@\r\n",size, [[model.file componentsSeparatedByString:@"/"] lastObject]];
}

- (void)showAlertWithText:(NSString *)text {
    NSAlert *alert = [[NSAlert alloc]init];
    alert.messageText = text;
    [alert addButtonWithTitle:@"确定"];
    [alert beginSheetModalForWindow:[NSApplication sharedApplication].windows[0] completionHandler:^(NSModalResponse returnCode) {
    }];
}

@end
