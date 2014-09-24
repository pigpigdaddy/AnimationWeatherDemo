//
//  LoginViewController.h
//  Education
//
//  Created by 王尧 on 12-10-16.
//  Copyright (c) 2012年 UReading. All rights reserved.
//

#import <UIKit/UIKit.h>
//#import "MBProgressHUD.h"
#import "URLoadingView.h"
#import "MMLocationManager.h"
#import "LoginServer.h"
#import "LoginView.h"


@interface LoginViewController : UIViewController<LoginServerDelegate,LoginView>

@property (nonatomic, weak)  IBOutlet UILabel       *warnLabel;
@property (nonatomic, weak)  IBOutlet UIView        *warnView;

@property (nonatomic, weak)  IBOutlet UITextField   *tfUsername;
@property (nonatomic, weak)  IBOutlet UITextField   *tfPassword;
@property (nonatomic, weak)  IBOutlet UIButton      *btnRemeber;
@property (nonatomic, weak)  IBOutlet UIButton      *btnAutoLogin;

@property (nonatomic, weak)  IBOutlet  UIImageView     *cloud_1;
@property (nonatomic, weak)  IBOutlet  UIImageView     *cloud_2;
@property (nonatomic, weak)  IBOutlet  UIImageView     *cloud_3;

@property (nonatomic, weak)  IBOutlet  UIView          *boardView;
@property (nonatomic, weak)  IBOutlet  UIView          *loginView;
@property (weak, nonatomic)  IBOutlet  UILabel         *versionLab;
@property (weak, nonatomic)  IBOutlet  UIImageView     *defaultBg;
@property (weak, nonatomic)  IBOutlet  UIImageView     *weatherBg;
@property (weak, nonatomic)  IBOutlet  UIImageView     *sunImg;

@property (weak, nonatomic) IBOutlet UIButton *loginbtn;
@property (weak, nonatomic) IBOutlet UIImageView *offLineImageView;

-(IBAction)loginAction:(id)sender;
-(IBAction)remeberAction:(id)sender;
-(IBAction)autoLoginAction:(id)sender;

-(void)clear;

- (void)reloadUserLoginAccount;

- (void)cancelReconnectTimer;

@end
