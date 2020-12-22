//
//  LJHConversion.h
//  LiangjianghuSampleApp
//
//  Created by lbadvisor on 2020/12/16.
//  Copyright © 2020 lbadvisor. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LJHConversion : NSObject

@property (nonatomic, assign) NSUInteger latestConversionValue;

+ (instancetype)sharedManager;

- (void)initializeWithUrl:(NSString *)url;
- (void)logEvent:(NSString *)event withEventAttribute:(NSString *)eventAttribute withValue:(NSString *)toValue;
- (NSUInteger)retrieveConversionValue;
- (NSData *)getConversionTable;
- (NSString *)getProgressAndRevenueStrWithConversionValue:(int)value;
- (NSString *)getBinaryConversionValue;
- (void)resetRevenueAndProgress;

@end

NS_ASSUME_NONNULL_END
