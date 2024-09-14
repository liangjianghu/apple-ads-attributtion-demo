//
//  ViewController.m
//  Example-Objc
//
//  Created by liujie on 2024/9/13.
//

#import "ViewController.h"
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <AdSupport/AdSupport.h>
#import <AdServices/AdServices.h>

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
                permissionStr = @"Permission not determined";
                break;
            case ATTrackingManagerAuthorizationStatusRestricted:
                permissionStr = @"Permission is restricted";
                break;
            case ATTrackingManagerAuthorizationStatusDenied:
                permissionStr = @"No permission, check system Settings -> Privacy -> Tracking";
                break;
            case ATTrackingManagerAuthorizationStatusAuthorized:
                permissionStr = @"Permission has been granted";
                break;
        }
        
    } else {
        if ([[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled]) {
            permissionStr = @"Permission granted (System is below iOS 14)";
        }
        else {
            permissionStr = @"No permission, please check system settings (System is below iOS 14)";
        }
    }
    return permissionStr;
}

- (NSString *)getIdfa {
    NSString *idfa = [[ASIdentifierManager sharedManager].advertisingIdentifier UUIDString];
    return idfa;
}

- (void)refreshStatus {
    self.statusLabel.text = [NSString stringWithFormat:@"Permission status: %@",[self permissionStatusStr]];
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
        [self alertWithTitle:@"Notice" andMessage:@"System tracking prompt is not supported below iOS 14"];
    }
}

- (void)alertWithTitle:(NSString *)title andMessage:(NSString *)message {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
        
    }];
    
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)alertTrackingConsentIsAlreadySet {
    [self alertWithTitle:@"Notice" andMessage:@"The system tracking consent dialog cannot be displayed because it has already been shown. To display the system tracking consent dialog again, please uninstall and reinstall the demo."];
}

- (void)alertCustomTrackingConsentDialog {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Notice"
                                                                   message:@"Do you consent to this app obtaining tracking permission?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    //cancel
    UIAlertAction *agreeAction = [UIAlertAction actionWithTitle:@"Allow" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self alertSystemTrackingDialog];
    }];
    [alert addAction:agreeAction];
            
    //ok
    UIAlertAction *disagreeAction = [UIAlertAction actionWithTitle:@"Don’t Allow" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    }];
    [alert addAction:disagreeAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)showDialog:(id)sender {
    if (@available(iOS 14, *)) {
        if ([ATTrackingManager trackingAuthorizationStatus] != ATTrackingManagerAuthorizationStatusNotDetermined){
            [self alertTrackingConsentIsAlreadySet];
        } else {
            [self alertCustomTrackingConsentDialog];
        }
    } else {
        // Below iOS 14
        // Check if the user has enabled ad tracking in Settings > Privacy
        if ([[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled]) {
            [self alertWithTitle:@"Notice" andMessage:@"Ad tracking is allowed"];
        } else {
            [self alertWithTitle:@"Notice" andMessage:@"Please enable ad tracking in Settings > Privacy"];
        }
        [self refreshStatus];
    }
}

- (void)postRequestWithToken:(NSString *)token
                retryCount:(NSInteger)retryCount
                   success:(void (^)(NSDictionary *responseDict))success
                   failure:(void (^)(NSError *error))failure {

    NSURL *url = [NSURL URLWithString:@"https://api-adservices.apple.com/api/v1/"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:60.0];

    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPMethod:@"POST"];

    NSData *postData = [token dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:postData];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *postDataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            // If there are retry attempts left, decrement retryCount and retry
            if (retryCount > 0) {
                NSLog(@"Request failed, retrying... Remaining retries: %ld", (long)(retryCount - 1));
                if (weakSelf) {
                    [weakSelf postRequestWithToken:token retryCount:retryCount - 1 success:success failure:failure];
                }
            } else {
                // If no retries are left, trigger the failure callback
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (failure) {
                        failure(error);
                    }
                });
            }
            return;
        }

        NSError *jsonError;
        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            if (retryCount > 0) {
                NSLog(@"Failed to parse JSON, retrying... Remaining retries: %ld", (long)(retryCount - 1));
                [weakSelf postRequestWithToken:token retryCount:retryCount - 1 success:success failure:failure];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (failure) {
                        failure(jsonError);
                    }
                });
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    success(jsonResponse);
                }
            });
        }
    }];
    
    [postDataTask resume];
}

- (IBAction)requestAttribution:(id)sender {
    if (@available(iOS 14.3, *)) {
        NSError *error;
        NSString *token = [AAAttribution attributionTokenWithError:&error];
        NSLog(@"token=%@", token);
        if (token != nil) {
            [self postRequestWithToken:token
                           retryCount:3
                              success:^(NSDictionary *responseDict) {
                                  NSLog(@"Request succeeded with response: %@", responseDict);
                                  [self alertWithTitle:@"Notice" andMessage:[NSString stringWithFormat:@"%@", [responseDict description]]];
                              }
                              failure:^(NSError *error) {
                                  NSLog(@"Request failed with error: %@", error.localizedDescription);
                                    [self alertWithTitle:@"Notice" andMessage:[NSString stringWithFormat:@"%@",error.localizedDescription]];
                              }];
        }
    } else {
        // Fallback on earlier versions
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = @"Attribution Demo";
    [self refreshStatus];
}


@end
