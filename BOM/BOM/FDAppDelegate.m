//
//  FDAppDelegate.m
//  BOM
//
//  Created by Denis Bohm on 5/16/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDAppDelegate.h"
#import "FDBillOfMaterials.h"

@interface FDAppDelegate ()

@property (assign) IBOutlet NSPathControl *schematicPathControl;

@end

@implementation FDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *schematicPath = [userDefaults stringForKey:@"schematicPath"];
    if (schematicPath) {
        _schematicPathControl.URL = [[NSURL alloc] initFileURLWithPath:schematicPath];
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    NSString *schematicPath = _schematicPathControl.URL.path;
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:schematicPath forKey:@"schematicPath"];
}

- (IBAction)generateAll:(id)sender
{
    NSString *schematicPath = _schematicPathControl.URL.path;
    if (!schematicPath) {
        return;
    }

    FDBillOfMaterials *bom = [[FDBillOfMaterials alloc] init];
    bom.schematicPath = schematicPath;
    [bom read];
    [bom exportForScreamingCircuits];
    [bom exportForDigikey];
    [bom exportForMouser];
    [bom exportForArrow];
    [bom exportForRichardsonRFPD];
}

@end
