//
//  FDSpreadsheet.h
//  enclose
//
//  Created by Denis Bohm on 2/20/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDSpreadsheet : NSObject

- (void)create:(NSArray *)columnNames;

- (void)addRow;
- (void)addRowWithStyle:(NSString *)style;
- (void)addStringCell:(NSString *)value;
- (void)addNumberCell:(NSInteger)value;

- (NSString *)content;

@end
