//
//  FDAppDelegate.m
//  PcbTo3D
//
//  Created by Denis Bohm on 9/6/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDAppDelegate.h"
#import "FDBoardView.h"
#import "FDRhino.h"

@interface FDAppDelegate ()

@property (assign) IBOutlet NSPathControl *scriptPathControl;
@property (assign) IBOutlet NSPathControl *boardPathControl;
@property (assign) IBOutlet NSTextField *boardThicknessTextField;
@property (assign) IBOutlet FDBoardView *boardView;
@property NSString *scriptPath;
@property NSString *boardPath;
@property NSString *boardName;
@property FDBoard *board;

@end

@implementation FDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSString *boardPath = [userDefaults stringForKey:@"boardPath"];
    if (boardPath) {
        _boardPathControl.URL = [[NSURL alloc] initFileURLWithPath:boardPath];
    }
    
    NSString *boardThickness = [userDefaults stringForKey:@"boardThickness"];
    if (boardThickness) {
        _boardThicknessTextField.stringValue = boardThickness;
    }

    NSString *scriptPath = [userDefaults stringForKey:@"scriptPath"];
    if (scriptPath) {
        _scriptPathControl.URL = [[NSURL alloc] initFileURLWithPath:scriptPath];
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSString *boardThickness = _boardThicknessTextField.stringValue;
    [userDefaults setObject:boardThickness forKey:@"boardThickness"];
    
    NSString *boardPath = _boardPathControl.URL.path;
    [userDefaults setObject:boardPath forKey:@"boardPath"];
    
    NSString *scriptPath = _scriptPathControl.URL.path;
    [userDefaults setObject:scriptPath forKey:@"scriptPath"];
}

- (IBAction)convert:(id)sender
{
    NSString *scriptPath = _scriptPathControl.URL.path;
    if (!scriptPath) {
        return;
    }
    _scriptPath = scriptPath;
    NSString *boardPath = _boardPathControl.URL.path;
    if (!boardPath) {
        return;
    }
    _boardPath = [boardPath stringByDeletingLastPathComponent];
    _boardName = [boardPath lastPathComponent];
    
    NSString *path = [_boardPath stringByAppendingPathComponent:_boardName];
    NSError *error = nil;
    NSString *xml = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    NSXMLDocument *document = [[NSXMLDocument alloc] initWithXMLString:xml options:0 error:&error];

    _board = [[FDBoard alloc] init];
    _board.thickness = [[_boardThicknessTextField stringValue] doubleValue];
    [self loadDocument:document container:_board.container];
    
    _boardView.board = _board;
    [_boardView setNeedsDisplay:YES];
    
    FDRhino *rhino = [[FDRhino alloc] init];
    rhino.board = _board;
    rhino.lines = [NSMutableString stringWithContentsOfFile:[[_scriptPath stringByAppendingPathComponent:@"3d"] stringByAppendingPathExtension:@"py"] encoding:NSUTF8StringEncoding error:&error];
    [rhino convert];
    NSString *output = [[[_scriptPath stringByAppendingPathComponent:_boardName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"py"];
    [rhino.lines writeToFile:output atomically:NO encoding:NSUTF8StringEncoding error:&error];
}

- (void)loadWire:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardWire *wire = [[FDBoardWire alloc] init];
    wire.x1 = [[[element attributeForName:@"x1"] stringValue] doubleValue];
    wire.y1 = [[[element attributeForName:@"y1"] stringValue] doubleValue];
    wire.x2 = [[[element attributeForName:@"x2"] stringValue] doubleValue];
    wire.y2 = [[[element attributeForName:@"y2"] stringValue] doubleValue];
    wire.width = [[[element attributeForName:@"width"] stringValue] doubleValue];
    wire.curve = [[[element attributeForName:@"curve"] stringValue] doubleValue];
    wire.layer = [[[element attributeForName:@"layer"] stringValue] intValue];
    [container.wires addObject:wire];
}

- (void)loadPolygon:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardPolygon *polygon = [[FDBoardPolygon alloc] init];
    polygon.width = [[[element attributeForName:@"width"] stringValue] doubleValue];
    polygon.layer = [[[element attributeForName:@"layer"] stringValue] intValue];
    NSError *error = nil;
    NSArray *elements = [element objectsForXQuery:@"vertex" error:&error];
    for (NSXMLElement *element in elements) {
        FDBoardVertex *vertex = [[FDBoardVertex alloc] init];
        vertex.x = [[[element attributeForName:@"x"] stringValue] doubleValue];
        vertex.y = [[[element attributeForName:@"y"] stringValue] doubleValue];
        vertex.curve = [[[element attributeForName:@"curve"] stringValue] doubleValue];
        [polygon.vertices addObject:vertex];
    }
    [container.polygons addObject:polygon];
}

- (void)loadVia:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardVia *via = [[FDBoardVia alloc] init];
    via.x = [[[element attributeForName:@"x"] stringValue] doubleValue];
    via.y = [[[element attributeForName:@"y"] stringValue] doubleValue];
    via.drill = [[[element attributeForName:@"drill"] stringValue] doubleValue];
    [container.vias addObject:via];
}

- (void)loadHole:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardHole *hole = [[FDBoardHole alloc] init];
    hole.x = [[[element attributeForName:@"x"] stringValue] doubleValue];
    hole.y = [[[element attributeForName:@"y"] stringValue] doubleValue];
    hole.drill = [[[element attributeForName:@"drill"] stringValue] doubleValue];
    [container.holes addObject:hole];
}

- (void)loadCircle:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardCircle *circle = [[FDBoardCircle alloc] init];
    circle.x = [[[element attributeForName:@"x"] stringValue] doubleValue];
    circle.y = [[[element attributeForName:@"y"] stringValue] doubleValue];
    circle.radius = [[[element attributeForName:@"radius"] stringValue] doubleValue];
    circle.width = [[[element attributeForName:@"width"] stringValue] doubleValue];
    circle.layer = [[[element attributeForName:@"layer"] stringValue] intValue];
    [container.circles addObject:circle];
}

- (void)parseRot:(NSString *)rot mirror:(BOOL *)mirror rotate:(double *)rotate
{
    if (rot != nil) {
        if ([rot hasPrefix:@"M"]) {
            *mirror = YES;
            *rotate = [[rot substringFromIndex:2] doubleValue];
        } else {
            *mirror = NO;
            *rotate = [[rot substringFromIndex:1] doubleValue];
        }
    }
}

- (void)loadSmd:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardSmd *smd = [[FDBoardSmd alloc] init];
    smd.x = [[[element attributeForName:@"x"] stringValue] doubleValue];
    smd.y = [[[element attributeForName:@"y"] stringValue] doubleValue];
    smd.dx = [[[element attributeForName:@"dx"] stringValue] doubleValue];
    smd.dy = [[[element attributeForName:@"dy"] stringValue] doubleValue];
    smd.roundness = [[[element attributeForName:@"roundness"] stringValue] doubleValue];
    NSString *rot = [[element attributeForName:@"rot"] stringValue];
    BOOL mirror = NO;
    double rotate = 0.0;
    [self parseRot:rot mirror:&mirror rotate:&rotate];
    smd.mirror = mirror;
    smd.rotate = rotate;
    smd.layer = [[[element attributeForName:@"layer"] stringValue] intValue];
    [container.smds addObject:smd];
}

- (void)loadPad:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardPad *pad = [[FDBoardPad alloc] init];
    pad.x = [[[element attributeForName:@"x"] stringValue] doubleValue];
    pad.y = [[[element attributeForName:@"y"] stringValue] doubleValue];
    pad.drill = [[[element attributeForName:@"drill"] stringValue] doubleValue];
    NSString *rot = [[element attributeForName:@"rot"] stringValue];
    BOOL mirror = NO;
    double rotate = 0.0;
    [self parseRot:rot mirror:&mirror rotate:&rotate];
    pad.mirror = mirror;
    pad.rotate = rotate;
    pad.shape = [[element attributeForName:@"shape"] stringValue];
    [container.pads addObject:pad];
}

- (void)loadInstance:(FDBoardContainer *)container element:(NSXMLElement *)element
{
    FDBoardInstance *instance = [[FDBoardInstance alloc] init];
    instance.x = [[[element attributeForName:@"x"] stringValue] doubleValue];
    instance.y = [[[element attributeForName:@"y"] stringValue] doubleValue];
    NSString *rot = [[element attributeForName:@"rot"] stringValue];
    BOOL mirror = NO;
    double rotate = 0.0;
    [self parseRot:rot mirror:&mirror rotate:&rotate];
    instance.mirror = mirror;
    instance.rotate = rotate;
    instance.library = [[element attributeForName:@"library"] stringValue];
    instance.package = [[element attributeForName:@"package"] stringValue];
    [container.instances addObject:instance];
}

- (FDBoardPackage *)loadPackage:(NSXMLElement *)element
{
    FDBoardPackage *package = [[FDBoardPackage alloc] init];
    package.name = [[element attributeForName:@"name"] stringValue];
    NSError *error = nil;
    NSArray *elements = [element objectsForXQuery:@"*" error:&error];
    [self loadElements:elements container:package.container];
    return package;
}

- (void)loadElements:(NSArray *)elements container:(FDBoardContainer *)container
{
    for (NSXMLElement *element in elements) {
        NSString *name = [element localName];
        if ([@"wire" isEqualToString:name]) {
            [self loadWire:container element:element];
        } else
        if ([@"polygon" isEqualToString:name]) {
            [self loadPolygon:container element:element];
        } else
        if ([@"hole" isEqualToString:name]) {
            [self loadHole:container element:element];
        } else
        if ([@"circle" isEqualToString:name]) {
            [self loadCircle:container element:element];
        } else
        if ([@"smd" isEqualToString:name]) {
            [self loadSmd:container element:element];
        } else
        if ([@"pad" isEqualToString:name]) {
            [self loadPad:container element:element];
        }
    }
}

- (void)loadDocument:(NSXMLDocument *)document container:(FDBoardContainer *)container
{
    NSError *error = nil;
    NSArray *plainElements = [document objectsForXQuery:@"./eagle/drawing/board/plain/*" error:&error];
    [self loadElements:plainElements container:container];
    NSArray *signalElements = [document objectsForXQuery:@"./eagle/drawing/board/signals/signal/*" error:&error];
    [self loadElements:signalElements container:container];
    NSArray *wireElements = [document objectsForXQuery:@"./eagle/drawing/board/signals/signal/wire" error:&error];
    for (NSXMLElement *wireElement in wireElements) {
        [self loadWire:container element:wireElement];
    }
    NSArray *viaElements = [document objectsForXQuery:@"./eagle/drawing/board/signals/signal/via" error:&error];
    for (NSXMLElement *viaElement in viaElements) {
        [self loadVia:container element:viaElement];
    }
    NSArray *packageElements = [document objectsForXQuery:@"./eagle/drawing/board/libraries/library/packages/package" error:&error];
    for (NSXMLElement *packageElement in packageElements) {
        FDBoardPackage *package = [self loadPackage:packageElement];
        _board.packages[package.name] = package;
    }
    NSArray *instanceElements = [document objectsForXQuery:@"./eagle/drawing/board/elements/element" error:&error];
    for (NSXMLElement *instanceElement in instanceElements) {
        [self loadInstance:container element:instanceElement];
    }
}

@end
