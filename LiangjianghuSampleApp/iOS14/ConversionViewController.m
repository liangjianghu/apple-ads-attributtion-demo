//
//  ConversionViewController.m
//  LiangjianghuSampleApp
//
//  Created by lbadvisor on 2020/12/17.
//  Copyright © 2020 lbadvisor. All rights reserved.
//

#import "ConversionViewController.h"
#import "LJHConversion.h"

@interface ConversionViewController ()

@property (nonatomic, strong) UILabel *descLabel1;
@property (nonatomic, strong) UILabel *descLabel2;
@property (nonatomic, weak) IBOutlet UIView *helpView;

@end

@implementation ConversionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.title = @"updateConversionValue测试";
    // 参考配置文件，实际需根据业务需要进行配置
    [[LJHConversion sharedManager] initializeWithUrl:@"https://jsonkeeper.com/b/9J5B"];
    [self initViews];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)tap:(UITapGestureRecognizer *)gesture {
    UILabel *label = (UILabel *)gesture.view;
    if (label.text.intValue <= [[LJHConversion sharedManager] retrieveConversionValue]) {
        [self alertWithTitle:@"提示" andMessage:@"conversion数值应大于上次数值"];
        return;
    }
    
    NSArray *subviews = [self.view subviews];
    for (UIView *v in subviews) {
        if ([v isKindOfClass:UILabel.class]) {
            ((UILabel *)v).textColor = [UIColor blackColor];
            ((UILabel *)v).font = [UIFont systemFontOfSize:15];
        }
    }
    
    label.textColor = [UIColor blueColor];
    label.font = [UIFont boldSystemFontOfSize:25.0];
    [[LJHConversion sharedManager] getProgressAndRevenueStrWithConversionValue:label.text.intValue];
    [self alertWithTitle:@"更新转化值" andMessage:[NSString stringWithFormat:@"%lu\n计时器被重置，将在24-48小时后发送给广告平台", (unsigned long)[[LJHConversion sharedManager] retrieveConversionValue]]];
    [self refreshDescriptionLabel];
}

- (void)refreshDescriptionLabel {
    unsigned long value = [[LJHConversion sharedManager] retrieveConversionValue];
    NSString *str = [[LJHConversion sharedManager] getProgressAndRevenueStrWithConversionValue:(int)value];
    self.descLabel1.text = [NSString stringWithFormat:@"最新转化值%lu（%@）", value, [[LJHConversion sharedManager] getBinaryConversionValue]];
    self.descLabel2.text = str;
}

- (void)initViews {
    CGSize size = [[UIScreen mainScreen] bounds].size;
    float w = size.width * 4/5;
    
    UILabel *conversionLabel = [[UILabel alloc] initWithFrame:CGRectMake(size.width/8, 100, 200, 20)];
    conversionLabel.text = @"转化值:";
    [self.view addSubview:conversionLabel];
    
    unsigned long lastConversionValue = [[LJHConversion sharedManager] retrieveConversionValue];
    for (int i = 0; i < 64; i++) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(size.width/8 + (i%8)*w/8, 120 + (i/8)*w/8, w/8, w/8)];
        label.text = [NSString stringWithFormat:@"%d", i];
        [label setTextAlignment:NSTextAlignmentCenter];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
        [label addGestureRecognizer:tap];
        label.userInteractionEnabled = YES;
        label.textColor = [UIColor blackColor];
        label.font = [UIFont systemFontOfSize:15];
        if (i == lastConversionValue) {
            label.textColor = [UIColor blueColor];
            label.font = [UIFont boldSystemFontOfSize:25.0];
        }
        [self.view addSubview:label];
    }
    
    UILabel *descLabel1 = [[UILabel alloc] initWithFrame:CGRectMake(size.width/8, 120 + w, w, 30)];
    descLabel1.font = [UIFont systemFontOfSize:13];
    descLabel1.numberOfLines = 3;
    [self.view addSubview:descLabel1];
    self.descLabel1 = descLabel1;
    
    UILabel *descLabel2 = [[UILabel alloc] initWithFrame:CGRectMake(size.width/8, 150 + w, w, 30)];
    descLabel2.font = [UIFont systemFontOfSize:13];
    [self.view addSubview:descLabel2];
    self.descLabel2 = descLabel2;
    
    
    [self refreshDescriptionLabel];
    
    CGRect f = self.helpView.frame;
    self.helpView.frame = CGRectMake(f.origin.x, 120 + w + 30, f.size.width, f.size.height);
}

// TODO
- (void)sendEvent:(id)sender {
    [[LJHConversion sharedManager] logEvent:@"level_completed" withEventAttribute:@"level" withValue:@"5"];
    // OR
    /*
    [[LJHConversion sharedManager] logEvent:@"purchase" withEventAttribute:@"amount" withValue:@"6"];
     */
}

// TODO
- (void)requestConversionValue:(id)sender {
    [self alertWithTitle:@"最新conversion值" andMessage:[NSString stringWithFormat:@"发送给SKADNetwork的值为：%lu", (unsigned long)[[LJHConversion sharedManager] retrieveConversionValue]]];
}

// TODO
- (void)getConversionTable:(id)sender {
    NSData *data = [[LJHConversion sharedManager] getConversionTable];
    NSString *strData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [self alertWithTitle:@"ConversionTable" andMessage:strData];
}

- (IBAction)showProgressEventTable:(id)sender {
    NSString *info = @"000  -       \n001     1 level completed\n010    5 level completed\n011   10 level completed\n100   15 level completed\n101   20 level completed\n110   25 level completed\n111  30+ level completed";
    [self alertWithTitle:@"关卡事件对照表" andMessage:info];
}

- (IBAction)showRevenueEventTable:(id)sender {
    NSString *info = @"000  -       \n001   purchase > $1\n010   purchase > $2\n011   purchase > $3\n100   purchase > $5\n101   purchase > $10\n110   purchase > $15\n111   purchase > $20";
    [self alertWithTitle:@"购买事件对照表" andMessage:info];
}

- (IBAction)reset:(id)sender {
    [[LJHConversion sharedManager] resetRevenueAndProgress];
    [self refreshDescriptionLabel];
    NSArray *subviews = [self.view subviews];
    for (UIView *v in subviews) {
        if ([v isKindOfClass:UILabel.class]) {
            ((UILabel *)v).textColor = [UIColor blackColor];
            ((UILabel *)v).font = [UIFont systemFontOfSize:15];
        }
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

@end
