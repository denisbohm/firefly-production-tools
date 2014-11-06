//
//  FDBuilderView.m
//  FireflyProduction
//
//  Created by Denis Bohm on 11/3/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import "FDBuilderView.h"

@interface FDBuilderView ()

@property NSView *mainSubView;

@end

@implementation FDBuilderView

- (void)initialize {
}

- (NSView *)firstView:(NSArray *)objects {
    for (NSObject *object in objects) {
        if ([object isKindOfClass:[NSView class]]) {
            return (NSView *)object;
        }
    }
    return nil;
}

- (void)loadViewsFromBundle {
    NSString *class_name = NSStringFromClass([self class]);
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSArray *objects;
    [bundle loadNibNamed:class_name owner:self topLevelObjects:&objects];
    self.mainSubView = [self firstView:objects];
    [self addSubview:self.mainSubView];
    
    [self.mainSubView translatesAutoresizingMaskIntoConstraints];
    NSDictionary *viewsDictionary = @{@"mainSubView":self.mainSubView};
    NSDictionary *metrics = @{@"hMargin": @0, @"vMargin": @0};
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-vMargin-[mainSubView]-vMargin-|"
                                                                 options:0
                                                                 metrics:metrics
                                                                   views:viewsDictionary]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-hMargin-[mainSubView]-hMargin-|"
                                                                 options:0
                                                                 metrics:metrics
                                                                   views:viewsDictionary]];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if(self) {
        [self loadViewsFromBundle];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self loadViewsFromBundle];
        [self initialize];
    }
    return self;
}

@end
