//
//  FDTargetOptionsView.h
//  FireflyProduction
//
//  Created by Denis Bohm on 11/3/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import "FDBuilderView.h"

@class FDTargetOptionsView;

@protocol FDTargetOptionsViewDelegate <NSObject>

- (void)targetOptionsViewChange:(FDTargetOptionsView *)view;

@end

@interface FDTargetOptionsView : FDBuilderView

@property id<FDTargetOptionsViewDelegate> delegate;

@property NSMutableDictionary *resources;

@end
