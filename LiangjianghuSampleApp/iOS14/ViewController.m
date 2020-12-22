//
//  ViewController.m
//  iOS14
//
//  Created by lbadvisor on 2020/12/4.
//  Copyright © 2020 lbadvisor. All rights reserved.
//

#import "ViewController.h"
#import <AdSupport/AdSupport.h>
#import <iAd/iAd.h>
#import <StoreKit/SKAdNetwork.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import "LJHConversion.h"
#import "ConversionViewController.h"

NSError *gError = nil;

@interface ViewController ()

@property (nonatomic, weak) IBOutlet UILabel *statusLabel;
@property (nonatomic, weak) IBOutlet UILabel *idfaLabel;

@end

@implementation ViewController

- (NSString *)permissionStatusStr {
    NSString *permissionStr = @"";
    if (@available(iOS 14.0, *)) {
        
        ATTrackingManagerAuthorizationStatus status = [ATTrackingManager trackingAuthorizationStatus];
        
        switch (status) {
            case ATTrackingManagerAuthorizationStatusNotDetermined:
                permissionStr = @"权限未确定";
                break;
            case ATTrackingManagerAuthorizationStatusRestricted:
                permissionStr = @"权限受到限制";
                break;
            case ATTrackingManagerAuthorizationStatusDenied:
                permissionStr = @"没有权限,检查系统 设置->隐私->跟踪";
                break;
            case ATTrackingManagerAuthorizationStatusAuthorized:
                permissionStr = @"权限已经获取";
                break;
        }
        
    } else {
        if ([[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled]) {
            permissionStr = @"权限已经获取(当前系统低于iOS14)";
        }
        else {
            permissionStr = @"没有权限，请检查系统设置(当前系统低于iOS14)";
        }
    }
    return permissionStr;
}

- (NSString *)getIdfa {
    NSString *idfa = [[ASIdentifierManager sharedManager].advertisingIdentifier UUIDString];
    return idfa;
}

- (void)refreshStatus {
    self.statusLabel.text = [NSString stringWithFormat:@"权限状态: %@",[self permissionStatusStr]];
    self.idfaLabel.text = [NSString stringWithFormat:@"IDFA: %@", [self getIdfa]];
}

- (void)alertSystemTrackingDialog {
    if (@available(iOS 14, *)) {
        __typeof__(self) weakSelf = self;
        [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
           
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf refreshStatus];
            });
        }];
    } else {
        [self alertWithTitle:@"提示" andMessage:@"iOS14版本以下不支持系统跟踪弹框提示"];
    }
}

- (void)alertWithTitle:(NSString *)title andMessage:(NSString *)message {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
        
    }];
    
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)alertTrackingConsentIsAlreadySet {
    [self alertWithTitle:@"提示" andMessage:@"不能显示系统跟踪同意对话框，因为它已经显示过。"@"如果想再次显示系统跟踪同意对话框，请删除该DEMO并重新进行安装。"];
}

- (void)alertCustomTrackingConsentDialog {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                   message:@"是否同意本App获取跟踪权限？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    //cancel
    UIAlertAction *agreeAction = [UIAlertAction actionWithTitle:@"同意" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self alertSystemTrackingDialog];
    }];
    [alert addAction:agreeAction];
            
    //ok
    UIAlertAction *disagreeAction = [UIAlertAction actionWithTitle:@"不同意" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    }];
    [alert addAction:disagreeAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)requestAttributionRetryingNumberOfTimes:(NSUInteger)ntimes success:(void (^)(id responseObject))success
                                        failure:(void (^)(NSError *error))failure {
    
    if (ntimes <= 0) {
        if (failure) {
            failure(gError);
        }
    } else {
        // 获取归因数据
        if ([[ADClient sharedClient] respondsToSelector:@selector(requestAttributionDetailsWithBlock:)]) {
            [[ADClient sharedClient] requestAttributionDetailsWithBlock:^(NSDictionary *attributionDetails, NSError *error) {
                if (error == nil) {
                    // 归因数据正确
                    success(attributionDetails);
                } else {
                    // 归因数据错误
                    gError = error;
                    [self requestAttributionRetryingNumberOfTimes:ntimes - 1 success:success failure:failure];
                }
            }];
        } else {
            [self alertWithTitle:@"提示" andMessage:@"系统不支持归因API"];
        }
    }
}

- (IBAction)requestAttribution:(id)sender {
    __typeof__(self) weakSelf = self;
    // 若获取归因失败，则重试3次
    [self requestAttributionRetryingNumberOfTimes:3 success:^(id responseObject) {
        NSString *str = @"";
        str = [NSString stringWithFormat:@"能正确获取归因数据 resDic=%@", responseObject];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf alertWithTitle:@"提示" andMessage:[NSString stringWithFormat:@"%@", str]];
        });
    } failure:^(NSError *error) {
        NSString *str = @"";
        str = [NSString stringWithFormat:@"归因数据有误 resDic=%@", error];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf alertWithTitle:@"提示" andMessage:[NSString stringWithFormat:@"%@", str]];
        });
    }];
}

- (IBAction)showDialog:(id)sender {
    if (@available(iOS 14, *)) {
        if ([ATTrackingManager trackingAuthorizationStatus] != ATTrackingManagerAuthorizationStatusNotDetermined){
            [self alertTrackingConsentIsAlreadySet];
        } else {
            [self alertCustomTrackingConsentDialog];
        }
    } else {
        // iOS 14以下
        // 判断在设置-隐私里用户是否打开了广告跟踪
        if ([[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled]) {
            [self alertWithTitle:@"提示" andMessage:@"广告跟踪已允许"];
        } else {
            [self alertWithTitle:@"提示" andMessage:@"请在设置-隐私里打开广告跟踪"];
        }
        [self refreshStatus];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    self.title = @"iOS14跟踪权限测试";
    if (@available(iOS 11.3, *)) {
        [SKAdNetwork registerAppForAdNetworkAttribution];
    }
    [self refreshStatus];
}


@end
