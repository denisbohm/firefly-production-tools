//
//  FDSpreadsheet.m
//  enclose
//
//  Created by Denis Bohm on 2/20/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDSpreadsheet.h"

@interface FDSpreadsheet ()

@property NSXMLDocument *document;
@property NSXMLElement *table;
@property NSXMLElement *row;

@end

@implementation FDSpreadsheet

- (id)init
{
    if (self = [super init]) {
    }
    return self;
}

- (void)create:(NSArray *)columnNames
{
    NSBundle* bundle = [NSBundle mainBundle];
    NSString* path = [bundle pathForResource:@"spreadsheet" ofType:@"xml"];
    NSError *error = nil;
    NSString *xml = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    _document = [[NSXMLDocument alloc] initWithXMLString:xml options:0 error:&error];
    _table = [[_document objectsForXQuery:@"./ss:Workbook/ss:Worksheet/ss:Table" error:&error] objectAtIndex:0];
    
    [self addRow];
    for (NSString *columnName in columnNames) {
        [self addStringCell:columnName];
    }
}

- (void)addRowWithStyle:(NSString *)style
{
    _row = [NSXMLElement elementWithName:@"ss:Row"];
    if (style != nil) {
        [_row addAttribute:[NSXMLNode attributeWithName:@"ss:StyleID" stringValue:style]];
    }
    [_table addChild:_row];
}

- (void)addRow
{
    [self addRowWithStyle:nil];
}

- (NSXMLElement *)addCell:(NSString *)type value:(NSString *)value
{
    NSXMLElement *cell = [NSXMLElement elementWithName:@"ss:Cell"];
    NSXMLElement *data = [NSXMLElement elementWithName:@"ss:Data"];
    [data addAttribute:[NSXMLNode attributeWithName:@"ss:Type" stringValue:type]];
    [data addChild:[NSXMLNode textWithStringValue:value]];
    [cell addChild:data];
    [_row addChild:cell];
    return cell;
}

- (void)addNumberCell:(NSInteger)value
{
    [self addCell:@"Number" value:[NSString stringWithFormat:@"%lu", (unsigned long)value]];
}

- (void)addStringCell:(NSString *)value
{
    [self addCell:@"String" value:value];
}

- (NSString *)content
{
    return [[NSString alloc] initWithData:[_document XMLData] encoding:NSUTF8StringEncoding];
}

@end
