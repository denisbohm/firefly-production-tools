//
//  FDBillOfMaterials.h
//  enclose
//
//  Created by Denis Bohm on 2/10/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDPartSearch.h"

@interface FDOption : NSObject

@property NSString *title;
@property BOOL value;

+ (FDOption *)option:(NSString *)title value:(BOOL)value;

@end

@interface FDPackage : NSObject

@property NSString *name;
@property double minSpacing;

@end

@interface FDDevice : NSObject

@property NSString *manufacturer;
@property NSString *orderingCode;

@end

@interface FDPad : NSObject

@property double x;
@property double y;

@end

@interface FDPart : NSObject

@property NSString *name;
@property NSString *value;
@property FDPackage *package;
@property NSString *manufacturer;
@property NSString *brand;
@property NSString *orderingCode;
@property NSString *distributor;
@property NSString *distributorOrderingCode;
@property NSString *note;
@property NSMutableSet *variants;
@property BOOL doNotStuff;
@property BOOL doNotSubstitute;

@property NSString *namePrefix;
@property NSUInteger nameNumber;

- (void)parseName;

- (FDPart *)copyInstance:(NSString *)instanceName;

@end

@interface FDModule : NSObject

@property NSString *name;
@property NSArray *parts;

@end

@interface FDModuleInstance : NSObject

@property NSString *name;
@property NSString *module;

@end

@interface FDItem : NSObject

@property NSString *brand;
@property NSString *orderingCode;
@property BOOL doNotStuff;
@property BOOL doNotSubstitute;
@property NSMutableArray *parts;
@property NSString *reference;
@property NSUInteger number;
@property NSArray *orderQuantities;

- (void)createReference;

@end

@interface FDPartBuy : NSObject
@property FDItem *item;
@property NSUInteger quantity;
@property double price;
@property BOOL backorder;
@property NSUInteger leadDays;

@property FDPartSeller *seller;
@property FDPartOffer *offer;
@property FDPartPriceAtQuantity *priceAtQuantity;

@property NSMutableArray *partialPartBuys;
@end

@interface FDBuy : NSObject
@property NSUInteger quantity;
@property double price;
@property NSArray *partBuys;
@property NSUInteger leadDays;
@property NSArray *lowStockItems;
@end

@interface FDBillOfMaterials : NSObject

@property NSString *schematicPath;
@property NSSet *options;
@property NSArray *quantities;
@property NSSet *sellers;

@property NSArray *buys;

- (NSArray *)readOptions;

- (void)read;

- (void)getPricingAndAvailability:(NSString *)apikey;

- (void)exportForScreamingCircuits;

- (void)exportBuys;

+ (NSString *)eta:(NSUInteger)leadDays;

@end
