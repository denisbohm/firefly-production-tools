//
//  FDBillOfMaterials.m
//  enclose
//
//  Created by Denis Bohm on 2/10/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDBillOfMaterials.h"
#import "FDPartSearch.h"
#import "FDSpreadsheet.h"

@implementation FDOption

+ (FDOption *)option:(NSString *)title value:(BOOL)value
{
    FDOption *option = [[FDOption alloc] init];
    option.title = title;
    option.value = value;
    return option;
}

@end

@implementation FDPackage

@end

@implementation FDDevice

@end

@implementation FDPad

@end

@implementation FDPart

- (id)init
{
    if (self = [super init]) {
        _variants = [NSMutableSet set];
    }
    return self;
}

- (void)parseName
{
    NSInteger i;
    for (i = _name.length - 1; i >= 0; --i) {
        unichar c = [_name characterAtIndex:i];
        if (!isdigit(c)) {
            if (i < (_name.length - 1)) {
                _namePrefix = [_name substringToIndex:i + 1];
                _nameNumber = [[_name substringFromIndex:i + 1] integerValue];
            }
            return;
        }
    }
}

@end

@implementation FDItem

- (id)init
{
    if (self = [super init]) {
        _parts = [NSMutableArray array];
    }
    return self;
}

- (void)createReference
{
    [_parts sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        FDPart *a = obj1;
        FDPart *b = obj2;
        if ((a.namePrefix == nil) || (b.namePrefix == nil)) {
            return [a.name compare:b.name];
        }
        if (a.nameNumber < b.nameNumber) {
            return NSOrderedAscending;
        }
        if (a.nameNumber > b.nameNumber) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
    
    NSMutableString *reference = [NSMutableString string];
    FDPart *firstPart = nil;
    FDPart *lastPart = nil;
    for (FDPart *part in _parts) {
        bool inRange = (lastPart != nil) && (part.nameNumber == (lastPart.nameNumber + 1));
        if (inRange) {
            lastPart = part;
        } else {
            if (firstPart != lastPart) {
                [reference appendFormat:@"-%lu", (unsigned long)lastPart.nameNumber];
            }
            
            if (reference.length > 0) {
                [reference appendString:@" "];
            }
            [reference appendFormat:@"%@", part.name];
            if (part.namePrefix != nil) {
                firstPart = part;
                lastPart = part;
            } else {
                firstPart = nil;
                lastPart = nil;
            }
        }
    }
    if (firstPart != lastPart) {
        [reference appendFormat:@"-%lu", (unsigned long)lastPart.nameNumber];
    }
    _reference = reference;
}

@end

@implementation FDPartBuy
@end

@implementation FDBuy
@end

@interface FDBillOfMaterials ()

@property NSString *directory;
@property NSString *filename;
@property NSArray *items;

@end

@implementation FDBillOfMaterials

- (id)init
{
    if (self = [super init]) {
        _quantities = @[ @10, @100, @3000 ];
    }
    return self;
}

- (FDItem *)addExtraItem:(NSMutableDictionary *)itemsByOrderingId
                    name:(NSString *)name
                   value:(NSString *)value
            manufacturer:(NSString *)manufacturer
            orderingCode:(NSString *)orderingCode
             distributor:(NSString *)distributor
 distributorOrderingCode:(NSString *)distributorOrderingCode
{
    // add battery cover
    FDPart *part = [[FDPart alloc] init];
    part.name = name;
    part.value = value;
    part.manufacturer = manufacturer;
    part.orderingCode = orderingCode;
    part.distributor = distributor;
    part.distributorOrderingCode = distributorOrderingCode;
    part.doNotStuff = true;
    part.doNotSubstitute = true;
    FDItem *item = [[FDItem alloc] init];
    item.orderingCode = part.orderingCode;
    itemsByOrderingId[item.orderingCode] = item;
    [item.parts addObject:part];
    return item;
}

- (NSXMLDocument *)getDocument
{
    _directory = [_schematicPath stringByDeletingLastPathComponent];
    _filename = [[_schematicPath lastPathComponent]stringByDeletingPathExtension];
    
    /*
     // Add ! in front of variant to exclude it. -denis
     [_options addObject:@"low-power"];
     [_options addObject:@"efficient-power"];
     [_options addObject:@"efficient-radio"];
     [_options addObject:@"usb-power"];
     [_options addObject:@"usb-charging"];
     [_options addObject:@"usb-data"];
     
     */
    
    NSError *error = nil;
    NSString *xml = [[NSString alloc] initWithContentsOfFile:_schematicPath encoding:NSUTF8StringEncoding error:&error];
    NSXMLDocument *document = [[NSXMLDocument alloc] initWithXMLString:xml options:0 error:&error];
    return document;
}

- (NSArray *)readOptions
{
    NSMutableSet *variants = [NSMutableSet set];
    NSXMLDocument *document = [self getDocument];
    NSError *error = nil;
    NSArray *partElements = [document objectsForXQuery:@"./eagle/drawing/schematic/parts/part" error:&error];
    for (NSXMLElement *partElement in partElements) {
        NSArray *attributes = [partElement objectsForXQuery:@"attribute" error:&error];
        for (NSXMLElement *attribute in attributes) {
            NSString *attributeName = [[attribute attributeForName:@"name"] stringValue];
            NSString *attributeValue = [[attribute attributeForName:@"value"] stringValue];
            if ([attributeName isEqualToString:@"VARIANTS"]) {
                for (NSString *token in [attributeValue componentsSeparatedByString:@","]) {
                    NSString *variant = [token hasPrefix:@"!"] ? [token substringFromIndex:1] : token;
                    [variants addObject:variant];
                }
            }
        }
    }
    NSArray *options = [variants allObjects];
    return options;
}

- (void)read
{
    NSXMLDocument *document = [self getDocument];
    
    NSMutableDictionary *packageByName = [NSMutableDictionary dictionary];
    NSError *error = nil;
    NSArray *packageElements = [document objectsForXQuery:@"./eagle/drawing/schematic/libraries/library/packages/package" error:&error];
    for (NSXMLElement *packageElement in packageElements) {
        NSString *name = [[packageElement attributeForName:@"name"] stringValue];
        NSArray *smds = [packageElement objectsForXQuery:@"smd" error:&error];
        NSMutableArray *pads = [NSMutableArray array];
        for (NSXMLElement *smd in smds) {
            FDPad *pad = [[FDPad alloc] init];
            pad.x = [[[smd attributeForName:@"x"] stringValue] doubleValue];
            pad.y = [[[smd attributeForName:@"y"] stringValue] doubleValue];
            [pads addObject:pad];
        }
        double minSpacing = DBL_MAX;
        for (NSUInteger i = 0; i < pads.count; ++i) {
            FDPad *a = pads[i];
            for (NSUInteger j = i + 1; j < pads.count; ++j) {
                FDPad *b = pads[j];
                double dx = a.x - b.x;
                double dy = a.y - b.y;
                double d2 = dx * dx + dy * dy;
                if (d2 < minSpacing) {
                    minSpacing = d2;
                }
            }
        }
        minSpacing = sqrt(minSpacing);
        FDPackage *package = [[FDPackage alloc] init];
        package.name = name;
        package.minSpacing = minSpacing;
        packageByName[name] = package;
    }
    
    NSMutableDictionary *deviceByFullDeviceName = [NSMutableDictionary dictionary];
    NSArray *devicesetElements = [document objectsForXQuery:@"./eagle/drawing/schematic/libraries/library/devicesets/deviceset" error:&error];
    for (NSXMLElement *devicesetElement in devicesetElements) {
        NSString *devicesetName = [[devicesetElement attributeForName:@"name"] stringValue];
        NSArray *deviceElements = [devicesetElement objectsForXQuery:@"devices/device" error:&error];
        for (NSXMLElement *deviceElement in deviceElements) {
            NSString *deviceName = [[deviceElement attributeForName:@"name"] stringValue];
            NSString *packageName = [[deviceElement attributeForName:@"package"] stringValue];
            NSString *fullDeviceName = [NSString stringWithFormat:@"%@ %@", devicesetName, deviceName];
            
            NSArray *technologyElements = [deviceElement objectsForXQuery:@"technologies/technology" error:nil];
            NSString *orderingCode = nil;
            NSString *manufacturer = nil;
            for (NSXMLElement *technologyElement in technologyElements) {
                NSArray *attributes = [technologyElement objectsForXQuery:@"attribute" error:&error];
                for (NSXMLElement *attribute in attributes) {
                    NSString *attributeName = [[attribute attributeForName:@"name"] stringValue];
                    NSString *attributeValue = [[attribute attributeForName:@"value"] stringValue];
                    if ([attributeName isEqualToString:@"ORDERING-CODE"]) {
                        orderingCode = attributeValue;
                    } else
                    if ([attributeName isEqualToString:@"MANUFACTURER"]) {
                        manufacturer = attributeValue;
                    }
                }
            }
            if ((orderingCode != nil) || (manufacturer != nil)) {
                FDDevice *device = deviceByFullDeviceName[fullDeviceName];
                if (device == nil) {
                    device = [[FDDevice alloc] init];
                    device.orderingCode = orderingCode;
                    device.manufacturer = manufacturer;
                    [deviceByFullDeviceName setValue:device forKey:fullDeviceName];
                }
            }
            
            FDPackage *package = packageByName[packageName];
            if (package == nil) {
                NSLog(@"Cannot Find Package %@ for Device %@", packageName, fullDeviceName);
                continue;
            }
            packageByName[fullDeviceName] = package;
        }
    }

    NSMutableDictionary *itemsByOrderingId = [NSMutableDictionary dictionary];
    NSArray *partElements = [document objectsForXQuery:@"./eagle/drawing/schematic/parts/part" error:&error];
    for (NSXMLElement *partElement in partElements) {
        FDPart *part = [[FDPart alloc] init];
        part.name = [[partElement attributeForName:@"name"] stringValue];
        part.value = [[partElement attributeForName:@"value"] stringValue];
        NSString *device = [[partElement attributeForName:@"device"] stringValue];
        NSString *deviceset = [[partElement attributeForName:@"deviceset"] stringValue];
        NSString *packageName = [NSString stringWithFormat:@"%@ %@", deviceset, device];
        part.package = packageByName[packageName];
        NSArray *attributes = [partElement objectsForXQuery:@"attribute" error:&error];
        for (NSXMLElement *attribute in attributes) {
            NSString *attributeName = [[attribute attributeForName:@"name"] stringValue];
            NSString *attributeValue = [[attribute attributeForName:@"value"] stringValue];
            if ([attributeName isEqualToString:@"ORDERING-CODE"]) {
                part.orderingCode = attributeValue;
            } else
            if ([attributeName isEqualToString:@"MANUFACTURER"]) {
                part.manufacturer = attributeValue;
            } else
            if ([attributeName isEqualToString:@"DISTRIBUTOR"]) {
                part.distributor = attributeValue;
            } else
            if ([attributeName isEqualToString:@"DISTRIBUTOR-ORDERING-CODE"]) {
                part.distributorOrderingCode = attributeValue;
            } else
            if ([attributeName isEqualToString:@"NOTE"]) {
                part.note = attributeValue;
            } else
            if ([attributeName isEqualToString:@"VARIANTS"]) {
                for (NSString *token in [attributeValue componentsSeparatedByString:@","]) {
                    [part.variants addObject:attributeValue];
                }
            } else
            if ([attributeName isEqualToString:@"DNS"]) {
                part.doNotStuff = [attributeValue isEqualToString:@"true"];
            } else
            if ([attributeName isEqualToString:@"NS"]) {
                part.doNotSubstitute = [attributeValue isEqualToString:@"true"];
            } else {
//                NSLog(@"Unknown %@ Attribute %@", part.name, attributeName);
            }
        }
        if (part.manufacturer == nil) {
            NSString *fullDeviceName = [NSString stringWithFormat:@"%@ %@", deviceset, device];
            FDDevice *device = deviceByFullDeviceName[fullDeviceName];
            if (device != nil) {
                part.manufacturer = device.manufacturer;
            }            
        }
        if (part.orderingCode == nil) {
            NSString *fullDeviceName = [NSString stringWithFormat:@"%@ %@", deviceset, device];
            FDDevice *device = deviceByFullDeviceName[fullDeviceName];
            if (device != nil) {
                part.orderingCode = device.orderingCode;
            }
        }
        
        NSString *library = [[partElement attributeForName:@"library"] stringValue];
        if ([library isEqualToString:@"frames"]) {
            continue;
        }
        if ([deviceset isEqualToString:@"GND"]) {
            continue;
        }
        if ([deviceset isEqualToString:@"VCC"]) {
            continue;
        }
        if ([deviceset isEqualToString:@"TARGET-PIN"]) {
            continue;
        }
        if ([deviceset isEqualToString:@"V+"]) {
            continue;
        }

        if (part.variants.count > 0) {
            if (![part.variants intersectsSet:_options]) {
                NSLog(@"do not stuff %@ (not in variants)", part.name);
                part.doNotStuff = YES;
            }
        }

        if (part.package == nil) {
            NSLog(@"Cannot Find Package %@ for Part %@", packageName, part.name);
        }
        if (part.orderingCode == nil) {
            NSLog(@"Missing Ordering Code for Part %@", part.name);
            continue;
        }
        
        [part parseName];
        NSString *orderingId = [NSString stringWithFormat:@"%@ DNS=%@ NS=%@ NOTE=%@", part.orderingCode, part.doNotStuff ? @"YES" : @"NO", part.doNotSubstitute ? @"YES" : @"NO", part.note];
        FDItem *item = itemsByOrderingId[orderingId];
        if (item == nil) {
            item = [[FDItem alloc] init];
            item.orderingCode = part.orderingCode;
            item.doNotStuff = part.doNotStuff;
            item.doNotSubstitute = part.doNotSubstitute;
            itemsByOrderingId[orderingId] = item;
        }
        [item.parts addObject:part];
    }

#if 0
    // extra parts that are not in the schematic
    [self addExtraItem:itemsByOrderingId name:@"BC1" value:@"Battery Cover" manufacturer:@"Memory Protection Devices" orderingCode:@"BHSD-2032-COVER" distributor:nil distributorOrderingCode:nil];
    [self addExtraItem:itemsByOrderingId name:@"BCR1" value:@"Coin Cell" manufacturer:@"Panasonic - BSG" orderingCode:@"CR2032" distributor:@"Digikey" distributorOrderingCode:@"P189-ND"];
#endif
    
    for (FDItem *item in [itemsByOrderingId allValues]) {
        [item createReference];
    }
    _items = [[itemsByOrderingId allValues] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        FDItem *a = obj1;
        FDItem *b = obj2;
        return [FDBillOfMaterials compareItem1:a item2:b];
//        return [a.reference compare:b.reference];
    }];
    NSUInteger number = 0;
    for (FDItem *item in _items) {
        item.number = ++number;
    }
    
    for (FDItem *item in _items) {
        NSMutableArray *orderQuantities = [NSMutableArray array];
        for (NSNumber *boardQuantityNumber in _quantities) {
            NSInteger boardQuantity = [boardQuantityNumber integerValue];
            NSInteger quantity = item.parts.count * boardQuantity;
            FDPart *part = item.parts[0];
            // 10% extra discrete parts (50% for 0201 size parts)
            // One or two spares for larger parts
            if ([self isDiscrete0201:part]) {
                // max of 50% extra or ~1" (20 parts w/ 1mm spacing on tape)
                quantity += MAX(ceil(quantity * 0.50), 20);
            } else
            if ([self isDiscrete:part]) {
                // max of 10% extra or ~1" (10 parts w/ 2mm spacing on tape)
                quantity += MAX(ceil(quantity * 0.10), 10);
            } else {
                // include 1 extra part for non-discretes if building in small qty
                if (quantity < 100) {
                    quantity += 1;
                }
            }
            [orderQuantities addObject:[NSNumber numberWithInteger:quantity]];
        }
        item.orderQuantities = orderQuantities;
    }
}

- (NSArray *)sortPartBuysBySeller:(NSArray *)partBuys
{
    NSArray *partBuysBy = [partBuys sortedArrayUsingComparator:^NSComparisonResult(id oa, id ob) {
        FDPartBuy *a = (FDPartBuy *)oa;
        FDPartBuy *b = (FDPartBuy *)ob;
        return [a.seller.name compare:b.seller.name];
    }];
    return partBuysBy;
}

- (NSArray *)sortPartBuysByPrice:(NSArray *)partBuys
{
    NSArray *partBuysByPrice = [partBuys sortedArrayUsingComparator:^NSComparisonResult(id oa, id ob) {
        FDPartBuy *a = (FDPartBuy *)oa;
        FDPartBuy *b = (FDPartBuy *)ob;
        if (a.price < b.price) {
            return NSOrderedAscending;
        }
        if (a.price > b.price) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
    return partBuysByPrice;
}

- (NSArray *)sortPartBuysByPriceAndLeadTime:(NSArray *)partBuys
{
    NSArray *partBuysByPrice = [partBuys sortedArrayUsingComparator:^NSComparisonResult(id oa, id ob) {
        FDPartBuy *a = (FDPartBuy *)oa;
        FDPartBuy *b = (FDPartBuy *)ob;
        if ((a.leadDays != 0) != (b.leadDays != 0)) {
            return a.leadDays != 0 ? NSOrderedAscending : NSOrderedDescending;
        }
        if (a.price < b.price) {
            return NSOrderedAscending;
        }
        if (a.price > b.price) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
    return partBuysByPrice;
}

- (FDPartBuy *)getSingleSellerFullBuy:(FDItem *)item itemQuantity:(NSUInteger)itemQuantity sellers:(NSArray *)sellers
{
    NSMutableArray *partBuys = [NSMutableArray array];
    for (FDPartSeller *seller in sellers) {
        if ((_sellers != nil) && ![_sellers containsObject:seller.name]) {
            continue;
        }
        for (FDPartOffer *offer in seller.offers) {
            for (FDPartPriceAtQuantity *priceAtQuantity in offer.priceAtQuantitys) {
                if (offer.stock == FDPartStock.InStock) {
                    NSUInteger quantity = itemQuantity;
                    if (quantity < priceAtQuantity.quantity) {
                        quantity = priceAtQuantity.quantity;
                    }
                    if (quantity < offer.minimumOrderQuantity) {
                        quantity = offer.minimumOrderQuantity;
                    }
                    if (offer.orderMultiple) {
                        if ((quantity % offer.orderMultiple) != 0) {
                            quantity += offer.orderMultiple - quantity % offer.orderMultiple;
                        }
                    }
                    if (offer.inStockQuantity >= quantity) {
                        double price = priceAtQuantity.price * quantity;
                        FDPartBuy *buy = [[FDPartBuy alloc] init];
                        buy.item = item;
                        buy.seller = seller;
                        buy.offer = offer;
                        buy.priceAtQuantity = priceAtQuantity;
                        buy.quantity = quantity;
                        buy.price = price;
                        [partBuys addObject:buy];
                    }
                }
            }
        }
    }
    if (partBuys.count == 0) {
        return nil;
    }
    NSArray *partBuysByPrice = [self sortPartBuysByPrice:partBuys];
    return partBuysByPrice[0];
}

- (FDPartBuy *)getBackorderBuy:(FDItem *)item itemQuantity:(NSUInteger)itemQuantity sellers:(NSArray *)sellers
{
    NSMutableArray *partBuys = [NSMutableArray array];
    for (FDPartSeller *seller in sellers) {
        if ((_sellers != nil) && ![_sellers containsObject:seller.name]) {
            continue;
        }
        for (FDPartOffer *offer in seller.offers) {
            for (FDPartPriceAtQuantity *priceAtQuantity in offer.priceAtQuantitys) {
                if ((offer.stock == FDPartStock.InStock) || (offer.stock == FDPartStock.NotInStock)) {
                    NSUInteger quantity = itemQuantity;
                    if (quantity < priceAtQuantity.quantity) {
                        quantity = priceAtQuantity.quantity;
                    }
                    if (quantity < offer.minimumOrderQuantity) {
                        quantity = offer.minimumOrderQuantity;
                    }
                    if (offer.orderMultiple) {
                        if ((quantity % offer.orderMultiple) != 0) {
                            quantity += offer.orderMultiple - quantity % offer.orderMultiple;
                        }
                    }
                    double price = priceAtQuantity.price * quantity;
                    FDPartBuy *buy = [[FDPartBuy alloc] init];
                    buy.item = item;
                    buy.seller = seller;
                    buy.offer = offer;
                    buy.priceAtQuantity = priceAtQuantity;
                    buy.quantity = quantity;
                    buy.price = price;
                    buy.backorder = YES;
                    buy.leadDays = offer.leadDays;
                    [partBuys addObject:buy];
                }
            }
        }
    }
    if (partBuys.count == 0) {
        return nil;
    }
    NSArray *partBuysByPrice = [self sortPartBuysByPriceAndLeadTime:partBuys];
    return partBuysByPrice[0];
}

- (NSArray *)sortPartBuysByPiecePrice:(NSArray *)partBuys
{
    NSArray *partBuysByPrice = [partBuys sortedArrayUsingComparator:^NSComparisonResult(id oa, id ob) {
        FDPartBuy *a = (FDPartBuy *)oa;
        FDPartBuy *b = (FDPartBuy *)ob;
        double aPiecePrice = a.price / a.quantity;
        double bPiecePrice = b.price / b.quantity;
        if (aPiecePrice < bPiecePrice) {
            return NSOrderedAscending;
        }
        if (aPiecePrice > bPiecePrice) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
    return partBuysByPrice;
}

- (FDPartBuy *)getMultipleSellerBuy:(FDItem *)item itemQuantity:(NSUInteger)itemQuantity sellers:(NSArray *)sellers
{
    NSMutableArray *partialPartBuys = [NSMutableArray array];
    for (FDPartSeller *seller in sellers) {
        if ((_sellers != nil) && ![_sellers containsObject:seller.name]) {
            continue;
        }
        NSMutableArray *sellerPartBuys = [NSMutableArray array];
        for (FDPartOffer *offer in seller.offers) {
            for (FDPartPriceAtQuantity *priceAtQuantity in offer.priceAtQuantitys) {
                if (offer.stock == FDPartStock.InStock) {
                    NSUInteger quantity = itemQuantity;
                    if (quantity < priceAtQuantity.quantity) {
                        quantity = priceAtQuantity.quantity;
                    }
                    if (quantity < offer.minimumOrderQuantity) {
                        quantity = offer.minimumOrderQuantity;
                    }
                    if (offer.orderMultiple) {
                        if ((quantity % offer.orderMultiple) != 0) {
                            quantity += offer.orderMultiple - quantity % offer.orderMultiple;
                        }
                    }
                    if (offer.inStockQuantity < quantity) {
                        quantity = offer.inStockQuantity;
                    }
                    if (quantity >= priceAtQuantity.quantity) {
                        double price = priceAtQuantity.price * quantity;
                        FDPartBuy *buy = [[FDPartBuy alloc] init];
                        buy.item = item;
                        buy.seller = seller;
                        buy.offer = offer;
                        buy.priceAtQuantity = priceAtQuantity;
                        buy.quantity = quantity;
                        buy.price = price;
                        [sellerPartBuys addObject:buy];
                    }
                }
            }
        }
        if (sellerPartBuys.count > 0) {
            NSArray *sellerPartBuysByPrice = [self sortPartBuysByPrice:sellerPartBuys];
            [partialPartBuys addObject:sellerPartBuysByPrice[0]];
        }
    }
    NSMutableArray *partBuys = [NSMutableArray array];
    NSArray *partialPartBuysByPrice = [self sortPartBuysByPiecePrice:partialPartBuys];
    NSUInteger totalQuantity = 0;
    double totalPrice = 0.0;
    for (FDPartBuy *partBuy in partialPartBuysByPrice) {
        if (totalQuantity < itemQuantity) {
            totalQuantity += partBuy.quantity;
            totalPrice += partBuy.price;
            [partBuys addObject:partBuy];
        }
    }

    FDPartBuy *buy = [[FDPartBuy alloc] init];
    buy.item = item;
//    buy.seller = seller;
//    buy.offer = offer;
//    buy.priceAtQuantity = priceAtQuantity;
    buy.quantity += totalQuantity;
    buy.price += totalPrice;
    buy.partialPartBuys = partBuys;
    return buy;
}

- (FDBuy *)getBestBuy:(FDPartSearch *)partSearch quantityIndex:(NSUInteger)quantityIndex
{
    NSUInteger leadDays = 0;
    NSMutableArray *partBuys = [NSMutableArray array];
    NSMutableArray *lowStockItems = [NSMutableArray array];
    double totalPrice = 0.0;
    for (FDItem *item in _items) {
        if (item.doNotStuff) {
            NSLog(@"DNS %@", item.orderingCode);
            continue;
        }
        NSUInteger itemQuantity = [item.orderQuantities[quantityIndex] unsignedIntegerValue];
        FDPartBuy *partBuy = nil;
        NSArray *sellers = [partSearch findOffersWithManufacturerPartNumber:item.orderingCode];
        partBuy = [self getSingleSellerFullBuy:item itemQuantity:itemQuantity sellers:sellers];
        if (partBuy == nil) {
            partBuy = [self getMultipleSellerBuy:item itemQuantity:itemQuantity sellers:sellers];
            for (FDPartBuy *buy in partBuy.partialPartBuys) {
                NSLog(@"%@ %lu of %lu %@", item.orderingCode, (unsigned long)buy.quantity, (unsigned long)itemQuantity, buy.seller.name);
            }
        }
        if (partBuy.quantity < itemQuantity) {
            NSLog(@"%@ only %lu of %lu available", item.orderingCode, (unsigned long)partBuy.quantity, (unsigned long)itemQuantity);
            [lowStockItems addObject:item];
            
            NSUInteger backorderQuantity = itemQuantity - partBuy.quantity;
            FDPartBuy *backorderPartBuy = [self getBackorderBuy:item itemQuantity:backorderQuantity sellers:sellers];
            if (backorderPartBuy == nil) {
                NSLog(@"!!! NO SOURCE FOR %@ QTY %lu", item.orderingCode, (unsigned long)backorderQuantity);
            } else {
                NSLog(@"BACKORDER %lu %@ %@ lead time is %lu days", backorderQuantity, item.orderingCode, backorderPartBuy.seller.name, backorderPartBuy.leadDays);
                [partBuy.partialPartBuys addObject:backorderPartBuy];
                if (backorderPartBuy.leadDays > leadDays) {
                    leadDays = backorderPartBuy.leadDays;
                }
            }
        }
        [partBuys addObject:partBuy];
        totalPrice += partBuy.price;
    }
    
    FDBuy *buy = [[FDBuy alloc] init];
    buy.quantity = [_quantities[quantityIndex] unsignedIntegerValue];
    buy.price = totalPrice;
    buy.partBuys = partBuys;
    buy.leadDays = leadDays;
    buy.lowStockItems = lowStockItems;
    return buy;
}

- (void)getPricingAndAvailability:(NSString *)apikey
{
    FDPartSearch *partSearch = [[FDPartSearch alloc] init];
    partSearch.apikey = apikey;
    NSMutableArray *buys = [NSMutableArray array];
    for (NSUInteger i = 0; i < _quantities.count; ++i) {
        [buys addObject:[self getBestBuy:partSearch quantityIndex:i]];
    }
    _buys = buys;
}

+ (NSComparisonResult)compareItem1:(FDItem *)firstObjToCompare item2:(FDItem *)secondObjToCompare
{
    NSString *firstString = firstObjToCompare.reference;
    NSString *secondString = secondObjToCompare.reference;
    
    NSInteger lengthFirstStr = firstString.length;
    NSInteger lengthSecondStr = secondString.length;
    
    int index1 = 0;
    int index2 = 0;
    
    while (index1 < lengthFirstStr && index2 < lengthSecondStr) {
        char ch1 = [firstString characterAtIndex:index1];
        char ch2 = [secondString characterAtIndex:index2];
        
        char* space1 = calloc(lengthFirstStr, sizeof(char));
        char* space2 = calloc(lengthSecondStr, sizeof(char));
        
        int loc1 = 0;
        int loc2 = 0;
        
        NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
        do {
            space1[loc1++] = ch1;
            index1++;
            
            if (index1 < lengthFirstStr) {
                ch1 = [firstString characterAtIndex:index1];
            } else {
                break;
            }
        } while ([digits characterIsMember:ch1] == [digits characterIsMember:space1[0]]);
        
        do {
            space2[loc2++] = ch2;
            index2++;
            
            if (index2 < lengthSecondStr) {
                ch2 = [secondString characterAtIndex:index2];
            } else {
                break;
            }
        } while ([digits characterIsMember:ch2] == [digits characterIsMember:space2[0]]);
        
        NSString *str1 = [NSString stringWithUTF8String:space1];
        NSString *str2 = [NSString stringWithUTF8String:space2];
        
        free(space1);
        free(space2);
        
        int result;
        
        if (
            [digits characterIsMember:[str1 characterAtIndex:0]] &&
            [digits characterIsMember:[str2 characterAtIndex:0]]
        ) {
            NSInteger firstNumberToCompare = [[FDBillOfMaterials trim:str1] integerValue];
            NSInteger secondNumberToCompare = [[FDBillOfMaterials trim:str2] integerValue];
            if (firstNumberToCompare < secondNumberToCompare) {
                return NSOrderedAscending;
            }
            if (firstNumberToCompare > secondNumberToCompare) {
                return NSOrderedDescending;
            }
            return NSOrderedSame;
        } else {
            result = [str1 compare:str2];
        }
        
        if (result != NSOrderedSame) {
            return result;
        }
    }
    return lengthFirstStr - lengthSecondStr;
}

+ (NSString *)trim:(NSString *)s
{
    NSInteger i = 0;
    while (
        (i < s.length) &&
        [[NSCharacterSet whitespaceCharacterSet] characterIsMember:[s characterAtIndex:i]]
    ) {
        i++;
    }
    return [s substringFromIndex:i];
}

- (BOOL)isDiscrete0201:(FDPart *)part
{
    return [part.package.name hasSuffix:@"0201"];
}

- (BOOL)isDiscrete:(FDPart *)part
{
    NSString *name = part.package.name;
    return
    [name hasSuffix:@"0201"] ||
    [name hasSuffix:@"0402"] ||
    [name hasSuffix:@"0603"] ||
    [name hasSuffix:@"0805"];
}

- (void)write:(NSString *)suffix content:(NSString *)content
{
    NSString *path = [_directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", _filename, suffix]];
    NSError *error = nil;
    BOOL result = [content writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:&error];
    if (!result) {
        NSLog(@"cannot write %@: %@", path, error);
    }
}

- (void)exportForScreamingCircuits
{
    FDSpreadsheet *spreadsheet = [[FDSpreadsheet alloc] init];
    [spreadsheet create:@[@"Item #", @"Qty", @"Ref Des", @"Manufacturer", @"Mfg Part #", @"Distributor", @"Description", @"Package", @"Type", @"DNS", @"NS"]];
    
    NSMutableString *export = [NSMutableString string];
    NSLog(@"Screaming Circuits Export");
    [export appendString:@"Item #\tQty\tRef Des\tManufacturer\tMfg Part #\tDistributor\tDescription\tPackage\tType\tDNS\tNS\n"];
    NSUInteger uniquePartCount = 0;
    NSUInteger surfaceMountCount = 0;
    NSUInteger finePitchCount = 0;
    for (FDItem *item in _items) {
        NSString *type = @"";
        FDPart *part = item.parts[0];
        if (!part.doNotStuff) {
            ++uniquePartCount;
        }
        bool surfaceMount = true;
        bool finePitch = false;
        NSString *packageName = @"";
        if (part.package != nil) {
            packageName = part.package.name;
            if (surfaceMount) {
                if (!item.doNotStuff) {
                    surfaceMountCount += item.parts.count;
                }
                type = @"smt";
            }
            finePitch = part.package.minSpacing <= 0.5;
            if (finePitch) {
                NSLog(@"%@ %f Min Spacing", part.package.name, part.package.minSpacing);
                if (!item.doNotStuff) {
                    finePitchCount += item.parts.count;
                }
                type = @"fine pitch";
            }
        }
        NSString *distributor = part.distributor;
        if (distributor == nil) {
            distributor = @"Digikey";
        }
        NSMutableString *description = [NSMutableString string];
        if (part.value != nil) {
            [description appendString:part.value];
        }
        if (part.note != nil) {
            if (description.length > 0) {
                [description appendString:@" "];
            }
            [description appendString:part.note];
        }
        if (part.doNotStuff) {
            if (description.length > 0) {
                [description appendString:@" "];
            }
            [description appendString:@"(do not stuff)"];
        }
        if (part.doNotSubstitute) {
            if (description.length > 0) {
                [description appendString:@" "];
            }
            [description appendString:@"(do not substitute)"];
        }

        [export appendFormat:@"%lu\t%lu\t%@\t%@\t%@\t%@\t%@\t%@\t%@\t%@\t%@\n", (unsigned long)item.number, (unsigned long)item.parts.count, item.reference, part.manufacturer, part.orderingCode, distributor, description, packageName, type, part.doNotStuff ? @"TRUE" : @"FALSE", part.doNotSubstitute ? @"TRUE" : @"FALSE"];

        [spreadsheet addRowWithStyle:part.doNotStuff ? @"s21" : nil];
        [spreadsheet addNumberCell:item.number];
        [spreadsheet addNumberCell:item.parts.count];
        [spreadsheet addStringCell:item.reference];
        [spreadsheet addStringCell:part.manufacturer];
        [spreadsheet addStringCell:part.orderingCode];
        [spreadsheet addStringCell:distributor];
        [spreadsheet addStringCell:description];
        [spreadsheet addStringCell:packageName];
        [spreadsheet addStringCell:type];
        [spreadsheet addStringCell:part.doNotStuff ? @"TRUE" : @"FALSE"];
        [spreadsheet addStringCell:part.doNotSubstitute ? @"TRUE" : @"FALSE"];
    }
    [export appendFormat:@"Total # of unique parts\t%lu\n", uniquePartCount];
    [export appendFormat:@"SMT placements per board\t%lu\n", surfaceMountCount];
    [export appendFormat:@"Thru-hole placements per board\t%lu\n", (unsigned long)0];
    [export appendFormat:@"Fine pitch placements per board\t%lu\n", finePitchCount]; // 0.5mm or less lead spacing
    [export appendFormat:@"BGA placements per board\t%lu\n", (unsigned long)0]; // leadless (BGA, etc)
    NSLog(@"%@", export);
    [self write:@"bom-screaming-circuits.txt" content:export];
    
    [spreadsheet addRow];
    
    [spreadsheet addRow];
    [spreadsheet addStringCell:@"Total # of unique parts"];
    [spreadsheet addNumberCell:uniquePartCount];
    
    [spreadsheet addRow];
    [spreadsheet addStringCell:@"SMT placements per board"];
    [spreadsheet addNumberCell:surfaceMountCount];
    
    [spreadsheet addRow];
    [spreadsheet addStringCell:@"Thru-hole placements per board"];
    [spreadsheet addNumberCell:0];
    
    [spreadsheet addRow];
    [spreadsheet addStringCell:@"Fine pitch placements per board"];
    [spreadsheet addNumberCell:finePitchCount]; // 0.5mm or less lead spacing
    
    [spreadsheet addRow];
    [spreadsheet addStringCell:@"BGA placements per board"];
    [spreadsheet addNumberCell:0]; // leadless (BGA, etc)
    
    [self write:@"bom-screaming-circuits.xml" content:[spreadsheet content]];
}

+ (NSString *)eta:(NSUInteger)leadDays
{
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:leadDays*24*60*60];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MMM dd"];
    return [dateFormatter stringFromDate:date];
}

- (void)appendPartBuy:(NSMutableString *)export partBuy:(FDPartBuy *)partBuy
{
    [export appendFormat:@"%@ %@ %lu $%0.2f (%lu $%0.5f)", partBuy.item.orderingCode, partBuy.seller.name,(unsigned long)partBuy.quantity, partBuy.price, partBuy.priceAtQuantity.quantity, partBuy.priceAtQuantity.price];
    if (partBuy.backorder) {
        if (partBuy.leadDays == 0) {
            [export appendString:@" BACKORDER - UNKNOWN LEAD TIME"];
        } else {
            [export appendFormat:@" BACKORDER - %@ ETA", [FDBillOfMaterials eta:partBuy.leadDays]];
        }
    }
    [export appendString:@"\n"];
}

- (void)appendPartBuys:(NSMutableString *)export partBuys:(NSArray *)partBuys
{
    for (FDPartBuy *partBuy in partBuys) {
        if (partBuy.partialPartBuys != nil) {
            for (FDPartBuy *partialPartBuy in partBuy.partialPartBuys) {
                [self appendPartBuy:export partBuy:partialPartBuy];
            }
        } else {
            [self appendPartBuy:export partBuy:partBuy];
        }
    }
}

- (NSArray *)flattenPartBuys:(NSArray *)partBuys
{
    NSMutableArray *flatPartBuys = [NSMutableArray array];
    for (FDPartBuy *partBuy in partBuys) {
        if (partBuy.partialPartBuys != nil) {
            for (FDPartBuy *partialPartBuy in partBuy.partialPartBuys) {
                [flatPartBuys addObject:partialPartBuy];
            }
        } else {
            [flatPartBuys addObject:partBuy];
        }
    }
    return flatPartBuys;
}

- (void)exportBuy:(FDBuy *)buy partBuysForDigikey:(NSArray *)partBuys
{
    NSString *seller = @"Digi-Key";
    NSMutableString *export = [NSMutableString string];
    NSLog(@"%@ Export", seller);
    for (FDPartBuy *partBuy in partBuys) {
        if (![seller isEqualToString:partBuy.seller.name]) {
            continue;
        }
        FDItem *item = partBuy.item;
        NSString *distributorOrderingCode = @"";
        FDPart *part = item.parts[0];
        if ((part.distributor != nil) && [part.distributor isEqualToString:@"Digikey"]) {
            distributorOrderingCode = part.distributorOrderingCode;
        }
        [export appendFormat:@"%lu\t%@\t%@\t%@\n", (unsigned long)partBuy.quantity, item.orderingCode, distributorOrderingCode, partBuy.item.reference];
    }
    NSLog(@"%@", export);
    [self write:[NSString stringWithFormat:@"bom-%lu-%@.txt", (unsigned long)buy.quantity, seller] content:export];
}

- (void)exportBuy:(FDBuy *)buy partBuys:(NSArray *)partBuys seller:(NSString *)seller
{
    if ([@"Digi-Key" isEqualToString:seller]) {
        [self exportBuy:buy partBuysForDigikey:partBuys];
        return;
    }
    
    NSMutableString *export = [NSMutableString string];
    NSLog(@"%@ Export", seller);
    for (FDPartBuy *partBuy in partBuys) {
        if (![seller isEqualToString:partBuy.seller.name]) {
            continue;
        }
        [export appendFormat:@"%@|%lu|%@\n", partBuy.item.orderingCode, (unsigned long)partBuy.quantity, partBuy.item.reference];
    }
    NSLog(@"%@", export);
    [self write:[NSString stringWithFormat:@"bom-%lu-%@.txt", (unsigned long)buy.quantity, seller] content:export];
}

- (void)exportBuy:(FDBuy *)buy
{
    NSMutableArray *backorderPartBuys = [NSMutableArray array];
    for (FDPartBuy *partBuy in buy.partBuys) {
        if (partBuy.partialPartBuys != nil) {
            for (FDPartBuy *partialPartBuy in partBuy.partialPartBuys) {
                if (partialPartBuy.backorder) {
                    [backorderPartBuys addObject:partialPartBuy];
                }
            }
        } else {
            if (partBuy.backorder) {
                [backorderPartBuys addObject:partBuy];
            }
        }
    }

    NSMutableString *export = [NSMutableString string];
    
    [export appendFormat:@"qty %lu $%0.2f/ea $%0.2f", buy.quantity, buy.price / buy.quantity, buy.price];
    if (buy.lowStockItems.count == 0) {
        [export appendString:@" in stock\n"];
    } else {
        [export appendFormat:@" %lu BACKORDERS", (unsigned long)buy.lowStockItems.count];
        if (buy.leadDays == 0) {
            [export appendString:@" - UNKNOWN LEAD TIME\n"];
        } else {
            [export appendFormat:@" - %@ ETA\n", [FDBillOfMaterials eta:buy.leadDays]];
        }
        for (FDItem *item in buy.lowStockItems) {
            [export appendFormat:@"  %@\n", item.orderingCode];
        }
    }
    [export appendString:@"\n"];
    
    if (backorderPartBuys.count > 0) {
        NSArray *sortedPartBuys = [backorderPartBuys sortedArrayUsingComparator:^NSComparisonResult(id oa, id ob) {
            FDPartBuy *a = (FDPartBuy *)oa;
            FDPartBuy *b = (FDPartBuy *)ob;
            if ((a.leadDays == 0) != (b.leadDays == 0)) {
                return a.leadDays == 0 ? NSOrderedAscending : NSOrderedDescending;
            }
            if (a.quantity > b.quantity) {
                return NSOrderedAscending;
            }
            if (a.quantity < b.quantity) {
                return NSOrderedDescending;
            }
            return [a.item.orderingCode compare:b.item.orderingCode];
        }];
        [export appendString:@"BACKORDERS:\n"];
        [self appendPartBuys:export partBuys:sortedPartBuys];
        [export appendString:@"\n"];
    }
    
    NSArray *partBuys = [[self flattenPartBuys:buy.partBuys] sortedArrayUsingComparator:^NSComparisonResult(id oa, id ob) {
        FDPartBuy *a = (FDPartBuy *)oa;
        FDPartBuy *b = (FDPartBuy *)ob;
        return [a.item.orderingCode compare:b.item.orderingCode];
    }];

    [export appendString:@"Buys By Part:\n"];
    [self appendPartBuys:export partBuys:partBuys];
    [export appendString:@"\n"];
    
    NSArray *partBuysBySeller = [self sortPartBuysBySeller:partBuys];
    [export appendString:@"Buys By Seller:\n"];
    [self appendPartBuys:export partBuys:partBuysBySeller];
    [export appendString:@"\n"];
    
    NSArray *partBuysByPrice = [[[self sortPartBuysByPrice:partBuys] reverseObjectEnumerator] allObjects];
    [export appendString:@"Buys By Price:\n"];
    [self appendPartBuys:export partBuys:partBuysByPrice];
    [export appendString:@"\n"];
    
    [self write:[NSString stringWithFormat:@"buy-%lu.txt", (unsigned long)buy.quantity] content:export];
    
    NSMutableSet *sellers = [NSMutableSet set];
    for (FDPartBuy *partBuy in partBuys) {
        [sellers addObject:partBuy.seller.name];
    }
    for (NSString *seller in sellers) {
        [self exportBuy:buy partBuys:partBuys seller:seller];
    }
}

- (void)exportBuys
{
    for (FDBuy *buy in _buys) {
        [self exportBuy:buy];
    }
}

@end
