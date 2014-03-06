//
//  FDPartSearch.h
//  BOM
//
//  Created by Denis Bohm on 7/20/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDPartStock : NSObject
+ (FDPartStock *)NotStocked;
+ (FDPartStock *)NotInStock;
+ (FDPartStock *)InStock;
+ (FDPartStock *)UnknownQuantityInStock;
+ (FDPartStock *)Unknown;
@end

@interface FDPartPriceAtQuantity : NSObject
@property NSUInteger quantity;
@property double price;
@end

@interface FDPartOffer : NSObject
@property NSString *sellerName;
@property FDPartStock *stock;
@property NSUInteger inStockQuantity;
@property NSUInteger minimumOrderQuantity;
@property NSUInteger orderMultiple;
@property NSMutableArray *priceAtQuantitys;
@property NSUInteger leadDays;
@end

@interface FDPartSeller : NSObject
@property NSString *name;
@property NSMutableArray *offers;
@end

@interface FDPartSearch : NSObject

@property NSString *apikey;

- (NSArray *)findOffersWithManufacturerPartNumber:(NSString *)manufacturerPartNumber;

@end
