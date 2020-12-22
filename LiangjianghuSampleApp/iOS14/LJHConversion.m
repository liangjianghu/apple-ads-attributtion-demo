//
//  LJHConversion.m
//  LiangjianghuSampleApp
//
//  Created by lbadvisor on 2020/12/16.
//  Copyright © 2020 lbadvisor. All rights reserved.
//

#import "LJHConversion.h"
#import <StoreKit/SKAdNetwork.h>

@interface Hook : NSObject

@property (nonatomic, strong) NSString *eventName;
@property (nonatomic, strong) NSString *condition;
@property (nonatomic, strong) NSString *attribute;
@property (nonatomic, strong) NSString *value;

- (instancetype)initWithEventName:(NSString *)eventName andConditions:(NSString *)condition andAttribute:(NSString *)attribute andValue:(NSString *)value;

@end

@implementation Hook

- (instancetype)initWithEventName:(NSString *)eventName andConditions:(NSString *)condition andAttribute:(NSString *)attribute andValue:(NSString *)value {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.eventName = eventName;
    self.condition = condition;
    self.attribute = attribute;
    self.value = value;
    
    return self;
}

@end

@interface Conversion : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSArray *hooks;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, assign) int priority;

- (instancetype)initWithName:(NSString *)name andHooks:(NSArray *)hooks andType:(NSString *)type andPriority:(int)priority;

@end
@implementation Conversion

- (instancetype)initWithName:(NSString *)name andHooks:(NSArray *)hooks andType:(NSString *)type andPriority:(int)priority {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.name = name;
    self.hooks = hooks;
    self.type = type;
    self.priority = priority;
    
    return self;
}

@end

static NSString *binaryMatchingTable[8] = {@"000", @"001", @"010", @"011", @"100", @"101", @"110", @"111"};
static NSString *progressMatchingTable[8] = {@"", @"1 level completed", @"5 level completed", @"10 level completed", @"15 level completed", @"20 level completed", @"25 level completed", @"30+ level completed"};
static NSString *revenueMatchingTable[8] = {@"", @"purchase > $1", @"purchase > $2", @"purchase > $3", @"purchase > $5", @"purchase > $10", @"purchase > $15", @"purchase > $20"};

@interface LJHConversion ()

@property (nonatomic, strong) NSString *conversionTableURL;
@property (nonatomic, strong) NSArray *conversionTable;
@property (nonatomic, strong) NSString *progressBinary;
@property (nonatomic, strong) NSString *revenueBinary;

@end

@implementation LJHConversion

+ (instancetype)sharedManager {
    static LJHConversion *shared_manager = nil;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        shared_manager = [[self alloc] init];
    });
    return shared_manager;
}

- (void)initializeWithUrl:(NSString *)url {
    self.progressBinary = @"000";
    self.revenueBinary = @"000";
    self.conversionTableURL = url;
    [self retrieveConversionData];
    [self retrieveLatestBinaries];
}

- (void)retrieveConversionData {
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"conversionTableData"];
    if (data == nil) {
        [self requestConversionFile];
    }
}

- (void)retrieveLatestBinaries {
    NSString *revenueBinary = [[NSUserDefaults standardUserDefaults] objectForKey:@"revenueBinary"];
    NSString *progressBinary = [[NSUserDefaults standardUserDefaults] objectForKey:@"progressBinary"];
    if (revenueBinary != nil) {
        self.revenueBinary = revenueBinary;
    }
    if (progressBinary != nil) {
        self.progressBinary = progressBinary;
    }
}

- (void)requestConversionFile {
    NSURLComponents *components = [NSURLComponents componentsWithString:self.conversionTableURL];
    // Sending an Async GET request to the server to get the Ad data.
    [[[NSURLSession sharedSession] dataTaskWithURL:components.URL
                                 completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"请求JOSN文件出错！");
            return;
        }
        [self store:data];
    }] resume];
}

- (void)store:(NSData *)data {
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"conversionTableData"];
}

- (void)storeRevenueBinary:(NSString *)revenueBinary withProgressBinary:(NSString *)progressBinary {
    [[NSUserDefaults standardUserDefaults] setObject:revenueBinary forKey:@"revenueBinary"];
    [[NSUserDefaults standardUserDefaults] setObject:progressBinary forKey:@"progressBinary"];
}

//withProperties:(NSString *)properties
- (void)logEvent:(NSString *)event withEventAttribute:(NSString *)eventAttribute withValue:(NSString *)toValue {
    [self identifyConversionValueForEvent:event withEventAttribute:eventAttribute withValue:toValue];
    [self storeRevenueBinary:self.revenueBinary withProgressBinary:self.progressBinary];
    NSUInteger value = [self getDecimalByBinary:[NSString stringWithFormat:@"%@%@", self.revenueBinary, self.progressBinary]];
    if (value > 0) {
        if (@available(iOS 14.0, *)) {
            [SKAdNetwork updateConversionValue:value];
        } else {
            // Fallback on earlier versions
        }
    }
}

- (void)decode:(NSData *)data {
    NSMutableArray *conversionsTable = [NSMutableArray array];
    
    NSError* error;
    NSArray *conversions = [[NSMutableArray alloc] initWithArray:[NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error]];
    
    for (NSMutableDictionary *conversion in conversions) {
        NSString *name = [conversion objectForKey:@"ConversionName"];
        NSString *type = [conversion objectForKey:@"Type"];
        int priority = [(NSNumber *)[conversion objectForKey:@"PriorityFactor"] intValue];
        NSMutableDictionary *hook = [conversion objectForKey:@"Hook"][0];
        
        NSString *eventName = [hook objectForKey:@"EventName"];
        NSString *condition = [hook objectForKey:@"WHERE"];
        NSString *attribute = [hook objectForKey:@"eventAttribute"];
        NSString *value = [hook objectForKey:@"toValue"];
        
        Hook *h = [[Hook alloc] initWithEventName:eventName andConditions:condition andAttribute:attribute andValue:value];
        Conversion *conv = [[Conversion alloc] initWithName:name andHooks:@[h] andType:type andPriority:priority];
        
        [conversionsTable addObject:conv];
    }
    
    self.conversionTable = conversionsTable;
}

- (BOOL)confirmMatchForHook:(Hook *)hook withEventAttribute:(NSString *)eventAttribute withValue:(NSString *)toValue {
    int hookvalue = [hook.value intValue];
    int eventValue = [toValue intValue];
    if ([hook.condition isEqualToString:@"isHigher"]) {
        if (eventValue > hookvalue) {
            return YES;
        }
    } else if ([hook.condition isEqualToString:@"isLower"]) {
        if (eventValue < hookvalue) {
            return YES;
        }
    } else if ([hook.condition isEqualToString:@"isEqual"]) {
        if (eventValue == hookvalue) {
            return YES;
        }
    } else if ([hook.condition isEqualToString:@"isNotEqual"]) {
        if (eventValue != hookvalue) {
            return YES;
        }
    }
    return NO;
}

- (void)identifyConversionValueForEvent:(NSString *)event withEventAttribute:(NSString *)eventAttribute withValue:(NSString *)toValue {
    if (self.conversionTable.count == 0) {
        NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"conversionTableData"];
        if (data != nil) {
            [self decode:data];
        }
    }
    
    NSMutableArray *confirmedConversions = [NSMutableArray array];
    for (Conversion *conversion in self.conversionTable) {
        for (Hook *hook in conversion.hooks) {
            if ([hook.eventName isEqualToString:event]) {
                if (hook.attribute == nil || [self confirmMatchForHook:hook withEventAttribute:eventAttribute withValue:toValue]) {
                    [confirmedConversions addObject:conversion];
                }
            }
        }
    }
   
    if (confirmedConversions.count > 0) {
        NSSortDescriptor *sortDescriptor;
        sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"priority"
                                                   ascending:NO];
        NSArray *sortedArray = [confirmedConversions sortedArrayUsingDescriptors:@[sortDescriptor]];
        Conversion *highestConversion = (Conversion *)sortedArray[0];
        NSLog(@"%@", highestConversion.type);
        if ([highestConversion.type isEqualToString:@"Progress"]) {
            self.progressBinary = binaryMatchingTable[highestConversion.priority];
        } else if ([highestConversion.type isEqualToString:@"Revenue"]) {
            self.revenueBinary = binaryMatchingTable[highestConversion.priority];
        }
    }
}

- (NSInteger)getDecimalByBinary:(NSString *)binary {
    
    NSInteger decimal = 0;
    for (int i=0; i<binary.length; i++) {
        
        NSString *number = [binary substringWithRange:NSMakeRange(binary.length - i - 1, 1)];
        if ([number isEqualToString:@"1"]) {
            
            decimal += pow(2, i);
        }
    }
    return decimal;
}

- (NSString *)getBinaryByDecimal:(NSInteger)decimal {
    
    NSString *binary = @"";
    while (decimal) {
        
        binary = [[NSString stringWithFormat:@"%ld", decimal % 2] stringByAppendingString:binary];
        if (decimal / 2 < 1) {
            
            break;
        }
        decimal = decimal / 2 ;
    }
    if (binary.length % 3 != 0) {
        
        NSMutableString *mStr = [[NSMutableString alloc]init];;
        for (int i = 0; i < 3 - binary.length % 3; i++) {
            
            [mStr appendString:@"0"];
        }
        binary = [mStr stringByAppendingString:binary];
    }
    if (binary.length == 0) {
        binary = @"000";
    }
    return binary;
}

- (NSUInteger)retrieveConversionValue {
    [self retrieveLatestBinaries];
    NSUInteger value = [self getDecimalByBinary:[NSString stringWithFormat:@"%@%@", self.revenueBinary, self.progressBinary]];
    self.latestConversionValue = value;
    return value;
}

- (NSData *)getConversionTable {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"conversionTableData"];
}

- (int)indexOfBinaryMatchingTableWithEle:(NSString *)ele {
    int index = -1;
    for (int i = 0; i < 8; i++) {
        if ([binaryMatchingTable[i] isEqualToString:ele]) {
            index = i;
        }
    }
    return index;
}

- (NSString *)getProgressAndRevenueStrWithConversionValue:(int)value {
    NSString *revenue = [self getBinaryByDecimal:(value>>3)];
    NSString *progress = [self getBinaryByDecimal:(value&7)];
    [self storeRevenueBinary:revenue withProgressBinary:progress];
    
    NSString *revenueStr = @"";
    int revenueIndex = [self indexOfBinaryMatchingTableWithEle:revenue];
    if ( revenueIndex > -1) {
        revenueStr = revenueMatchingTable[revenueIndex];
    }
    
    NSString *progressStr = @"";
    int progressIndex = [self indexOfBinaryMatchingTableWithEle:progress];
    if ( progressIndex > -1) {
        progressStr = progressMatchingTable[progressIndex];
    }
    
    NSString *str = @"";
    if (progressStr.length > 0 && revenueStr.length > 0) {
        str = [NSString stringWithFormat:@"%@（%@）", progressStr, revenueStr];
    } else if (progressStr.length == 0) {
        str = revenueStr;
    } else if (revenueStr.length == 0) {
        str = progressStr;
    }
    return str;
}

- (NSString *)getBinaryConversionValue {
    return [NSString stringWithFormat:@"%@%@", self.revenueBinary, self.progressBinary];
}

- (void)resetRevenueAndProgress {
    self.revenueBinary = @"000";
    self.progressBinary = @"000";
    [self storeRevenueBinary:self.revenueBinary withProgressBinary:self.progressBinary];
}

@end

