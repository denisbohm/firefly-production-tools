//
//  FDPartSearch.m
//  BOM
//
//  Created by Denis Bohm on 7/20/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDPartSearch.h"

@interface FDPartStock ()
@property NSString *name;
@end

@implementation FDPartStock

static BOOL _initialized = NO;
static FDPartStock *_notStocked;
static FDPartStock *_notInStock;
static FDPartStock *_inStock;
static FDPartStock *_unknownQuantityInStock;
static FDPartStock *_unknown;

+ (FDPartStock *)partStock:(NSString *)name
{
    FDPartStock *partStock = [[FDPartStock alloc] init];
    partStock.name = name;
    return partStock;
}

+ (void)prepare
{
    if (_initialized) {
        return;
    }
    
    _notStocked = [FDPartStock partStock:@"not stocked"];
    _notInStock = [FDPartStock partStock:@"not in stock"];
    _inStock = [FDPartStock partStock:@"in stock"];
    _unknownQuantityInStock = [FDPartStock partStock:@"unknown quantity in stock"];
    _unknown = [FDPartStock partStock:@"unknown"];
    _initialized = YES;
}

+ (FDPartStock *)NotStocked {
    [FDPartStock prepare];
    return _notStocked;
}

+ (FDPartStock *)NotInStock {
    [FDPartStock prepare];
    return _notInStock;
}

+ (FDPartStock *)InStock {
    [FDPartStock prepare];
    return _inStock;
}

+ (FDPartStock *)UnknownQuantityInStock {
    [FDPartStock prepare];
    return _unknownQuantityInStock;
}

+ (FDPartStock *)Unknown {
    [FDPartStock prepare];
    return _unknown;
}

- (NSString *)description
{
    return _name;
}

@end

@implementation FDPartPriceAtQuantity
@end

@implementation FDPartOffer
@end

@implementation FDPartSeller
@end

@interface FDPartSearch ()
@property NSString *url;
@end

@implementation FDPartSearch

- (id)init
{
    if (self = [super init]) {
        _url = @"http://octopart.com/api/v3/parts/match";
    }
    return self;
}

+ (NSString*)urlEscapeString:(NSString *)unencodedString
{
    CFStringRef originalStringRef = (__bridge_retained CFStringRef)unencodedString;
    NSString *s = (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, originalStringRef, NULL, NULL, kCFStringEncodingUTF8);
    CFRelease(originalStringRef);
    return s;
}

+ (NSString*)addQueryStringToUrlString:(NSString *)urlString withDictionary:(NSDictionary *)dictionary
{
    NSMutableString *urlWithQuerystring = [[NSMutableString alloc] initWithString:urlString];
    
    for (id key in dictionary) {
        NSString *keyString = [key description];
        NSString *valueString = [[dictionary objectForKey:key] description];
        if ([urlWithQuerystring rangeOfString:@"?"].location == NSNotFound) {
            [urlWithQuerystring appendFormat:@"?%@=%@", [self urlEscapeString:keyString], [self urlEscapeString:valueString]];
        } else {
            [urlWithQuerystring appendFormat:@"&%@=%@", [self urlEscapeString:keyString], [self urlEscapeString:valueString]];
        }
    }
    return urlWithQuerystring;
}

+ (NSData *)get:(NSString *)url parameters:(NSDictionary *)parameters
{
    return [NSData dataWithContentsOfURL:[NSURL URLWithString:[FDPartSearch addQueryStringToUrlString:url withDictionary:parameters]]];
}

NSInteger getInteger(id value)
{
    if ([value respondsToSelector:@selector(integerValue)]) {
        NSInteger quantity = [value integerValue];
        return quantity;
    }
    if ([NSNull isSubclassOfClass:[value class]]) {
        return 0;
    }
    @throw [NSException exceptionWithName:@"UnexpectedValueClass" reason:@"unexpected value class" userInfo:nil];
}

/*
 curl -G http://octopart.com/api/v3/parts/match \
     -d queries='[{"mpn":"SN74S74N"}]' \
     -d apikey=EXAMPLE_KEY \
     -d pretty_print=true
 */
- (NSArray *)findOffersWithManufacturerPartNumber:(NSString *)manufacturerPartNumber
{
    // return any previous search result, so we don't use up part search API requests (they cost $)
    NSArray *documentsSearchPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = documentsSearchPath[0];
    NSString *partsPath = [documentsPath stringByAppendingPathComponent:@"FireflyBOM"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:partsPath]) {
        [fileManager createDirectoryAtPath:partsPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSMutableString *partFilename = [NSMutableString stringWithString:manufacturerPartNumber];
    [partFilename replaceOccurrencesOfString:@"/" withString:@"_" options:0 range:NSMakeRange(0, [partFilename length])];
    [partFilename replaceOccurrencesOfString:@":" withString:@"_" options:0 range:NSMakeRange(0, [partFilename length])];
    NSString *partPath = [partsPath stringByAppendingPathComponent:partFilename];
    if (![fileManager fileExistsAtPath:partPath]) {
        NSString *queries = [NSString stringWithFormat:@"[{\"mpn\":\"%@\"}]", manufacturerPartNumber];
        NSData *data = [FDPartSearch get:_url parameters:@{@"queries": queries, @"apikey": _apikey, @"pretty_print": @"true"}];
        if (data != nil) {
            [data writeToFile:partPath atomically:NO];
        }
    }
    
    NSData *data = [NSData dataWithContentsOfFile:partPath];
    if (data == nil) {
        NSLog(@"no part search data for %@", manufacturerPartNumber);
        return nil;
    }
    NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (response == nil) {
        NSLog(@"no part search response for %@", manufacturerPartNumber);
        return nil;
    }
    NSArray *results = response[@"results"];
    if (results.count == 0) {
        NSLog(@"no part search results for %@", manufacturerPartNumber);
        return nil;
    }
    
    NSMutableDictionary *partSellers = [NSMutableDictionary dictionary];
    NSDictionary *result = results[0];
    NSArray *resultItems = result[@"items"];
    if (resultItems.count == 0) {
        NSLog(@"no part search result items for %@", manufacturerPartNumber);
        return nil;
    }
    NSDictionary *resultItem = resultItems[0];
    NSArray *offers = resultItem[@"offers"];
    for (NSDictionary *offer in offers) {
        BOOL isAuthorized = [offer[@"is_authorized"] boolValue];
        if (!isAuthorized) {
            continue;
        }
        NSDictionary *seller = offer[@"seller"];
        NSString *sellerName = seller[@"name"];
        NSString *packaging = offer[@"packaging"];
        if ([@"Custom Reel" isEqualToString:packaging] && [@"Digi-Key" isEqualToString:sellerName]) {
            // Skip Digi-Key Custom Reel because it is the same stock as Cut Tape... -denis
            continue;
        }
        FDPartStock *stock = FDPartStock.Unknown;
        NSInteger inStockQuantity = getInteger(offer[@"in_stock_quantity"]);
        if (inStockQuantity < 0) {
            switch (inStockQuantity) {
                case -1: // Non-Stock
                    stock = FDPartStock.NotStocked;
                    break;
                case -2: // In Stock (quantity unspecified)
                    stock = FDPartStock.UnknownQuantityInStock;
                    break;
                default: // Unknown Stock
                    break;
            }
            inStockQuantity = 0;
        } else {
            stock = inStockQuantity == 0 ? FDPartStock.NotInStock : FDPartStock.InStock;
        }
        NSUInteger minimumOrderQuantity = getInteger(offer[@"moq"]);
        NSUInteger orderMultiple = getInteger(offer[@"order_multiple"]);
        NSUInteger leadDays = getInteger(offer[@"factory_lead_days"]);
        NSMutableArray *partPriceAtQuantitys = [NSMutableArray array];
        NSDictionary *prices = offer[@"prices"];
        NSArray *usd = prices[@"USD"];
        for (NSArray *priceAtQuantity in usd) {
            NSUInteger quantity = [priceAtQuantity[0] unsignedIntegerValue];
            NSString *priceString = priceAtQuantity[1];
            double price = [priceString doubleValue];
            FDPartPriceAtQuantity *partPriceAtQuantity = [[FDPartPriceAtQuantity alloc] init];
            partPriceAtQuantity.quantity = quantity;
            partPriceAtQuantity.price = price;
            [partPriceAtQuantitys addObject:partPriceAtQuantity];
        }
        FDPartOffer *partOffer = [[FDPartOffer alloc] init];
        partOffer.sellerName = sellerName;
        partOffer.stock = stock;
        partOffer.inStockQuantity = inStockQuantity;
        partOffer.minimumOrderQuantity = minimumOrderQuantity;
        partOffer.orderMultiple = orderMultiple;
        partOffer.priceAtQuantitys = partPriceAtQuantitys;
        partOffer.leadDays = leadDays;
        FDPartSeller *partSeller = partSellers[sellerName];
        if (partSeller == nil) {
            partSeller = [[FDPartSeller alloc] init];
            partSeller.name = sellerName;
            partSeller.offers = [NSMutableArray array];
            partSellers[sellerName] = partSeller;
        }
        [partSeller.offers addObject:partOffer];
    }
    return [partSellers allValues];
}

@end
