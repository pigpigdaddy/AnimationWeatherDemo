//
//  LoginViewController.m
//  Education
//
//  Created by 王尧 on 12-10-16.
//  Copyright (c) 2012年 UReading. All rights reserved.
//

#import "FMDatabase.h"
#import "FMDatabasePool.h"
#import "PrivateServerInfo.h"
#import "LoginViewController.h"
#import "URFileTool.h"
#import "UserInfo.h"
#import "ServerInfo.h"
#import "EducationAppDelegate.h"
#import "UConstants.h"
#import "AboutUsView.h"
#import "ChangeIpView.h"
#import "LoginSettingView.h"
#import "AFHTTPRequestOperationManager.h"
#import "FMIWebDav.h"
#import "LessonsInfo.h"
#import "OfflineCacheData.h"
#import "SVHTTPRequest.h"

#define LOGIN_SNOW_IMAGENAME         @"login_snow"
#define LOGIN_RAIN_IMAGENAME         @"login_rain"
#define LOGIN_SUN_IMAGENAME          @"sun"
#define LOGIN_SUNBG_IMAGENAME        @"sun_login_bg"
#define LOGIN_RAINBG_IMAGENAME       @"rain_login_bg"
#define LOGIN_SNOWBG_IMAGENAME       @"snow_login_bg"


#define LOGIN_ACCOUNT_CACHE @"LOGIN_ACCOUNT_CACHE"

#define LOGIN_IMAGE_X                arc4random()%(int)Main_Screen_Width
#define LOGIN_IMAGE_ALPHA            ((float)(arc4random()%10))/10
#define LOGIN_IMAGE_WIDTH            arc4random()%20 + 10
#define LOGIN_PLUS_HEIGHT            Main_Screen_Height/25


@interface LoginViewController ()<AboutUsViewDelegate>
{
    NSTimer            *_time;
    NSMutableArray     *_snowImagesArray;
    
    int                _snowFlag;
    
    BOOL               _isShowKeyboard;
    
    // 正在自动登录
    BOOL               _isAutoLogin;
    
    // 天气索引
    int                _weatherIndex;
    // 角度
    float                _angle;
}

@property (nonatomic, strong) URLoadingView   *loadingView;
@property (nonatomic, strong) LoginServer     *loginServer;
@property (nonatomic, strong) FMIWebDav       *webDav;

@property (nonatomic, strong) NSTimer         *reconnectTimer;
@property (nonatomic, strong) NSString        *accountName;

@end

@implementation LoginViewController


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)reloadUserLoginAccount{
    NSString *username=[[NSUserDefaults standardUserDefaults] objectForKey:LOGIN_USERNAME];
    NSString *password=[[NSUserDefaults standardUserDefaults] objectForKey:LOGIN_PASSWORD];
    self.tfPassword.text=password;
    self.tfUsername.text=username;
}

/**   函数名称 :initView
 **   函数作用 :初始化界面
 **   函数参数 :
 **   函数返回值:
 **/

- (void)initView
{
    NSString *username=[[NSUserDefaults standardUserDefaults] objectForKey:LOGIN_USERNAME];
    NSString *password=[[NSUserDefaults standardUserDefaults] objectForKey:LOGIN_PASSWORD];
    self.tfPassword.text=password;
    self.tfUsername.text=username;
    
    self.tfPassword.font=[UIFont fontWithName:@"Microsoft YaHei" size:18];
    self.tfUsername.font=[UIFont fontWithName:@"Microsoft YaHei" size:18];
   
    self.warnLabel.font=[UIFont fontWithName:@"Microsoft YaHei" size:16];
    self.warnView.hidden=YES;
    
    BOOL isAuto=[[[NSUserDefaults standardUserDefaults] objectForKey:LOGIN_ISAUTOLOGIN] boolValue];
    BOOL isRemeber=[[[NSUserDefaults standardUserDefaults] objectForKey:LOGIN_REMEBERPASSWORD] boolValue];
    [self.btnAutoLogin setSelected:isAuto];
    if ([[NSUserDefaults standardUserDefaults] objectForKey:LOGIN_REMEBERPASSWORD]) {
        [self.btnRemeber setSelected:YES];
    }else{
        [self.btnRemeber setSelected:isRemeber];
    }
    
    //初始化加载框
    [self initProgressView];
    
    // 自动登录
    if (isAuto) {
        NSLog(@"autoLogin");
        [self login];
    }
}
- (void)dealloc
{
    _loginServer.delegate = nil;
    [_loginServer clear];
    NSLog(@"LoginViewController dealloc");
}
/**
 ** @Desc   TODO:初始化加载框 ProgressView
 ** @author 王尧
 ** @param  N/A
 ** @return N/A 
 ** @since
 */
- (void)initProgressView
{
    //加载进度条
    self.loadingView = [[URLoadingView alloc] initWithView:self.view];
    [self.view addSubview:self.loadingView];
}

-(void)initData{
    _isShowKeyboard=NO;

    _time=[NSTimer scheduledTimerWithTimeInterval:1.0f/30.0f target:self selector:@selector(update) userInfo:nil repeats:YES];
    
    
    [URLog debug:[NSString stringWithFormat:@"add!!!===Notification%s,%d",__func__,__LINE__]];
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(keyboardWillShow:)
//                                                 name:UIKeyboardWillShowNotification
//                                               object:nil];
//
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(keyboardWillHide:)
//                                                 name:UIKeyboardWillHideNotification
//                                               object:nil];
    
    //版本号
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey];
    [_versionLab setText:[NSString stringWithFormat:@"版本号:%@",version]];
}

- (void)loadConnector{
    _loginServer=[[LoginServer alloc] init];
    _loginServer.delegate=self;
    
    
    NSString *ip=[[NSUserDefaults standardUserDefaults] objectForKey:SERVER_IP_KEY];
    if (ip && [ip length] > 0) {
        [self.loadingView show];
        [_loginServer connectServer];
    }
}

/*!
 *  显示天气
 *
 *  @author gujun
 *  @since
 */
-(void)showWeather:(NSString *)name{
    if ([name rangeOfString:@"晴"].location != NSNotFound) {
        //晴天
        _weatherIndex = 1;
        _sunImg.hidden = NO;
        app.weatherCode=WEATHER_SUN;
    }else if([name rangeOfString:@"雨"].location != NSNotFound){
        //下雨
        _weatherIndex = 2;
        [self showSnowOrRain:YES];
        app.weatherCode=WEATHER_RAIN;
    }else if([name rangeOfString:@"雪"].location != NSNotFound){
        //下雪
        _weatherIndex = 3;
        [self showSnowOrRain:NO];
        app.weatherCode=WEATHER_SNOW;
    }
    if (_weatherIndex != 0) {
        [self changeWeatherBg];
        
        app.weatherCode=WEATHER_CLOUD;
    }
}

/*!
 *  切换天气背景
 *
 *  @author gujun
 *  @since
 */
-(void)changeWeatherBg{
    _weatherBg.alpha = 0.0f;
    switch (_weatherIndex) {
        case 1:
            [_weatherBg setImage:IMAGENAMED(LOGIN_SUNBG_IMAGENAME)];
            break;
        case 2:
            [_weatherBg setImage:IMAGENAMED(LOGIN_RAINBG_IMAGENAME)];
            break;
        case 3:
            [_weatherBg setImage:IMAGENAMED(LOGIN_SNOWBG_IMAGENAME)];
            break;
        default:
            break;
    }
    
    [UIView animateWithDuration:1.2f animations:^{
        _defaultBg.alpha = 0.0f;
    } completion:^(BOOL finished) {
        
    }];
    [UIView animateWithDuration:1.2f animations:^{
        _weatherBg.alpha = 1.0f;
    } completion:^(BOOL finished) {
        
    }];
    
}

/*!
 *  显示下雨或下雪
 *
 *  @author gujun
 *  @since
 */
-(void)showSnowOrRain:(BOOL)isRain{
    _snowFlag=0;
    _snowImagesArray=[[NSMutableArray alloc] init];
    UIImageView *imageView;
    for (int i = 0; i < 120; ++ i) {
        float x = LOGIN_IMAGE_WIDTH;
        if (isRain) {
            imageView = [[UIImageView alloc] initWithImage:IMAGENAMED(LOGIN_RAIN_IMAGENAME)];
            imageView.frame = CGRectMake(LOGIN_IMAGE_X, -47, imageView.frame.size.width, imageView.frame.size.height);
            if (LOGIN_IMAGE_ALPHA < 0.3) {
                imageView.alpha = LOGIN_IMAGE_ALPHA + 0.2;
            }else if(LOGIN_IMAGE_ALPHA < 0.6){
                imageView.alpha = LOGIN_IMAGE_ALPHA + 0.2;
            }else{
                imageView.alpha = LOGIN_IMAGE_ALPHA;
            }
        }else{
            imageView = [[UIImageView alloc] initWithImage:IMAGENAMED(LOGIN_SNOW_IMAGENAME)];
            imageView.frame = CGRectMake(LOGIN_IMAGE_X, -30, x, x);
            imageView.alpha = LOGIN_IMAGE_ALPHA;
        }
        
        [self.view insertSubview:imageView belowSubview:_cloud_3];
        [_snowImagesArray addObject:imageView];
    }
}

//界面加载
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initData];
    [self initView];
    
    [self getCity];
    
    NSString *port=[[NSUserDefaults standardUserDefaults] objectForKey:SERVER_PORT_KEY];
    NSString *ip=[[NSUserDefaults standardUserDefaults] objectForKey:SERVER_IP_KEY];
    if( port==nil && ip==nil){
        [self changeIp];
    }
    
    [self loadConnector];
}

/*!
 *  获取城市
 *
 *  @author gujun
 *  @since
 */
-(void)getCity
{
    [[MMLocationManager shareLocation] getCity:^(NSString *cityString) {
        [URLog debug:@"当前城市--->%@",cityString];
        if ([[cityString substringFromIndex:cityString.length - 1] isEqualToString:@"市"]) {
            NSRange range = NSMakeRange(0, cityString.length - 1);
            cityString = [cityString substringWithRange:range];
        }

        NSString *cityCode = [self getCityCode:cityString];
        [self getCurrentWeather:cityCode];
    }];
}

/*!
 *  根据城市名获取城市code
 *
 *  @param name <#name description#>
 *
 *  @return <#return value description#>
 *
 *  @author gujun
 *  @since
 */
-(NSString *)getCityCode:(NSString *)name{
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"citycode" ofType:@"plist"];
    NSDictionary *dictionary = [[NSDictionary alloc] initWithContentsOfFile:plistPath];
    return  [dictionary objectForKey:name];
}

-(void)excuteJson:(id)response{
    if (response==nil) return;
    
    id dict=[NSJSONSerialization JSONObjectWithData:response options:NSJSONReadingAllowFragments error:nil];
    
    NSString *weather = [[dict objectForKey:@"weatherinfo"] objectForKey:@"weather"];
    [self showWeather:weather];
    [URLog debug:@"天气:%@",weather];
}


/*!
 *  Description
 *
 *  @param nameCode <#nameCode description#>
 *
 *  @author gujun
 *  @since
 */
-(void)getCurrentWeather:(NSString *)nameCode{
    if (!nameCode) {
        return;
    }
    NSString *url=@"http://www.weather.com.cn/data/cityinfo/cityNumber.html";
    //将城市代码替换到天气解析网址cityNumber 部分！
    url=[url stringByReplacingOccurrencesOfString:@"cityNumber" withString:nameCode];
    __block LoginViewController *blockSelf=self;
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    [manager GET:url parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [blockSelf excuteJson:responseObject];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
       
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation{
    if (toInterfaceOrientation==UIInterfaceOrientationLandscapeLeft ||
        toInterfaceOrientation==UIInterfaceOrientationLandscapeRight) {
        return YES;
    }else{
        return NO;
    }
}


- (UIStatusBarStyle)preferredStatusBarStyle{
    return  UIStatusBarStyleLightContent;
}


- (BOOL)prefersStatusBarHidden{
    return NO;
}

-(void)clear{
    [URLog debug:[NSString stringWithFormat:@"remove!!!===Notification%s,%d",__func__,__LINE__]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    
    [_time invalidate];
    _time=nil;
    
    
    [_snowImagesArray removeAllObjects];
    _snowImagesArray=nil;
    
    [_loadingView removeFromSuperview];
    _loadingView=nil;
    
    for (UIView  *view in self.view.subviews) {
        [view removeFromSuperview];
    }
    
    _warnView=nil;
    
    _cloud_1=nil;
    _cloud_2=nil;
    _cloud_3=nil;
    _boardView=nil;
    
    
    [_loginServer clear];
}


#pragma mark=======================动画======================
static int i = 0;
- (void)makeSnow
{
    i = i + 1;
    if ([_snowImagesArray count] > 0) {
        UIImageView *imageView = [_snowImagesArray objectAtIndex:0];
        imageView.tag = i;
        [_snowImagesArray removeObjectAtIndex:0];
        [self snowFall:imageView];
    }
    
}

- (void)snowFall:(UIImageView *)aImageView
{
    [UIView beginAnimations:[NSString stringWithFormat:@"%i",aImageView.tag] context:nil];
    if (_weatherIndex == 2) {
        //下雨
        if (aImageView.alpha <= 0.3) {
            [UIView setAnimationDuration:4];
        }else if(aImageView.alpha <= 0.6){
            [UIView setAnimationDuration:3];
        }else{
            [UIView setAnimationDuration:2];
        }
    }else{
        [UIView setAnimationDuration:6];
    }
    [UIView setAnimationDelegate:self];
    aImageView.frame = CGRectMake(aImageView.frame.origin.x, Main_Screen_Height, aImageView.frame.size.width, aImageView.frame.size.height);
    //NSLog(@"%@",aImageView);
    [UIView commitAnimations];
}

- (void)addImage
{
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
    UIImageView *imageView = (UIImageView *)[self.view viewWithTag:[animationID intValue]];
    float x = LOGIN_IMAGE_WIDTH;
    if (_weatherIndex == 2) {
        imageView.frame = CGRectMake(LOGIN_IMAGE_X, -43, imageView.frame.size.width, imageView.frame.size.height);
    }else{
        imageView.frame = CGRectMake(LOGIN_IMAGE_X, -30, x, x);
    }
    
    [_snowImagesArray addObject:imageView];
}

-(void)update{
    CGPoint  point_1=_cloud_1.center;
    if(point_1.x-_cloud_1.frame.size.width/2>1024){
        point_1.x=-_cloud_1.frame.size.width/2;
    }else{
        point_1.x+=1;
    }
    _cloud_1.center=point_1;
    
    CGPoint  point_2=_cloud_2.center;
    if(point_2.x-_cloud_2.frame.size.width/2>1024){
        point_2.x=-_cloud_2.frame.size.width/2;
    }else{
        point_2.x+=1.5;
    }
    _cloud_2.center=point_2;
    
    CGPoint  point_3=_cloud_3.center;
    if(point_3.x-_cloud_3.frame.size.width/2>1024){
        point_3.x=-_cloud_3.frame.size.width/2;
    }else{
        point_3.x+=1.2;
    }
    _cloud_3.center=point_3;
    
    if (_weatherIndex == 1 && _sunImg.hidden == NO) {

        //晴天
        CGAffineTransform endAngle = CGAffineTransformMakeRotation(_angle * (M_PI / 180.0f));
        _sunImg.transform = endAngle;
        _angle += 0.2;
        
    }else if (_weatherIndex == 2){
        //下雨
        _snowFlag++;
        if (_snowFlag==2) {
            [self makeSnow];
            _snowFlag=0;
        }
    }else if (_weatherIndex == 3){
        //下雪
        _snowFlag++;
        if (_snowFlag==9) {
            [self makeSnow];
            _snowFlag=0;
        }
    }
}
#pragma mark=============================================

- (void)keyboardWillShow:(NSNotification *)notif {
    if (_isShowKeyboard==YES) {
        return;
    }
    
    _isShowKeyboard=YES;
    [UIView animateWithDuration:0.1 animations:^{
        CGPoint point=self.loginView.center;
        point.y-=60;
        self.loginView.center=point;
        
        point=self.boardView.center;
        point.y-=60;
        self.boardView.center=point;
    } completion:^(BOOL finished) {
        
    }];
}

- (void)keyboardWillHide:(NSNotification *)notif {
    if (_isShowKeyboard==NO) {
        return;
    }
    
    _isShowKeyboard=NO;
    [UIView animateWithDuration:0.1 animations:^{
        CGPoint point=self.loginView.center;
        point.y+=60;
        self.loginView.center=point;
        
        point=self.boardView.center;
        point.y+=60;
        self.boardView.center=point;
    } completion:^(BOOL finished) {

    }];
}

-(void)login{
    [self hideErr];
    
    NSString *ip=[[NSUserDefaults standardUserDefaults] objectForKey:SERVER_IP_KEY];
    NSString *port=[[NSUserDefaults standardUserDefaults] objectForKey:SERVER_PORT_KEY];
    if (ip==nil || port==nil || ip.length==0 || port.length==0) {
        [self loginErr:@"请先设置服务器信息"];
        return;
    }
    
    if (_tfPassword.text.length>0 && _tfUsername.text.length>0) {
        [_tfUsername resignFirstResponder];
        [_tfPassword resignFirstResponder];
        
        [self loginWithName:_tfUsername.text password:_tfPassword.text];
    }
}

-(IBAction)loginAction:(id)sender{
    [self login];
}

-(IBAction)remeberAction:(id)sender{
    [self.btnRemeber setSelected:!self.btnRemeber.selected];
}

-(IBAction)autoLoginAction:(id)sender{
    [self.btnAutoLogin setSelected:!self.btnAutoLogin.selected];
    if (self.btnAutoLogin.selected) {
        [self.btnRemeber setSelected:YES];
        [self.btnRemeber setUserInteractionEnabled:NO];
    }else{
        [self.btnRemeber setUserInteractionEnabled:YES];
    }
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    int tag=textField.tag;
    if (tag==1) {
        //用户名
        [_tfPassword becomeFirstResponder];
    }else{
        //密码
        [self login];
    }
    
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField{
    [self hideErr];
}

#pragma mark=======================LoginViewDelegate======================

/**
 ** @Desc   TODO:登陆的错误信息
 ** @author 王尧
 ** @param  (NSString *)error 显示登陆错误info
 ** @return N/A
 ** @since
 */
- (void)loginFailedWithError:(NSString *)error
{
    //TODO:关闭加载框
    [self.loadingView close];
}
/**
 ** @Desc   TODO:登陆成功调用
 ** @author 王尧
 ** @param  N/A
 ** @return N/A
 ** @since
 */
- (void)loginSuccess
{
    //TODO:关闭加载框
    [self.loadingView close];

    NSString *loginName = self.tfUsername.text;
    NSString *password  = self.tfPassword.text;
    
    app.loginUserName = loginName;
    app.loginPassWord = password;
    
    if (self.btnRemeber.selected) {
        [[NSUserDefaults standardUserDefaults] setObject:loginName forKey:LOGIN_USERNAME];
        [[NSUserDefaults standardUserDefaults] setObject:password forKey:LOGIN_PASSWORD];
        
    }else {
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:LOGIN_USERNAME];
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:LOGIN_PASSWORD];
    }
    
    
    //保存用户名密码至缓存
    /*
     =========================================================================================================
    */
    NSMutableDictionary *dict = [[NSUserDefaults standardUserDefaults] objectForKey:LOGIN_ACCOUNT_CACHE];
    if (!dict) {
        dict = [NSMutableDictionary dictionary];
    }else{
        dict = [NSMutableDictionary dictionaryWithDictionary:dict];
    }
    [dict setObject:password forKey:loginName];
    
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:LOGIN_ACCOUNT_CACHE];
    /*
     =========================================================================================================
     */
    
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%d",self.btnAutoLogin.selected] forKey:LOGIN_ISAUTOLOGIN];
    
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%d",self.btnRemeber.selected] forKey:LOGIN_REMEBERPASSWORD];
    
    NSLog(@"loginUserName saved:%@",loginName);
    NSLog(@"loginPassword saved:%@",password);
    NSLog(@"isAutoLoging  saved:%d",self.btnAutoLogin.selected);
    
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/**函数名称：loginWithName
 **函数作用：用户登录
 **参数：loginUserName 用户名  password 密码
 **返回值：N/A
 **/
- (void)loginWithName:(NSString *)loginUserName password:(NSString *)password
{
    [self.loadingView show];
    self.accountName = loginUserName;
//    if (_loginServer) {
//        [_loginServer clear];
//        _loginServer=nil;
//    }
//    
//    _loginServer=[[LoginServer alloc] init];
//    _loginServer.delegate=self;
    
    if (app.isOfflineLogin) {
        BOOL isValid = [self offLineCheckLogin];
        if (!isValid) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"用户名或密码错误" delegate:nil cancelButtonTitle:@"确认" otherButtonTitles:nil, nil];
            [alert show];
            return;
        }
        
        NSDictionary *dict = [OfflineCacheData getLoginOfflineCacheDataWithRoute:@"logindoneData" accountName:self.accountName];
        [self paserLoginInfo:dict];
        
        [self cancelReconnectTimer];
        
    }else{
        [self cancelReconnectTimer];
        
        [_loginServer login:loginUserName password:password delegate:self selector:@selector(loginDone:) errSelector:@selector(loginErr:)];
    }
}

-(void)loginDone:(NSDictionary *)dict{
    
    _loginServer.delegate=nil;
    
    [OfflineCacheData cacheLoginOfflineData:dict route:@"logindoneData" accountName:self.accountName];
    [self paserLoginInfo:dict];
}

- (void)paserLoginInfo:(NSDictionary *)dict{
    NSDictionary *userDict=[dict objectForKey:@"userinfo"];
    
    [[UserInfo shareInfo] setUid:[[userDict objectForKey:@"uid"] intValue]];
    [[UserInfo shareInfo] setSex:[[userDict objectForKey:@"sex"] intValue]];
    [[UserInfo shareInfo] setEmail:[userDict objectForKey:@"email"]];
    [[UserInfo shareInfo] setName:[userDict objectForKey:@"name"]];
    [[UserInfo shareInfo] setNumber:[userDict objectForKey:@"number"]];
    [[UserInfo shareInfo] setPhoto:[userDict objectForKey:@"photo"]];
    [[UserInfo shareInfo] setPhone:[userDict objectForKey:@"phone"]];
    [[UserInfo shareInfo] setRealname:[userDict objectForKey:@"realname"]];
    [[UserInfo shareInfo] setUsername:[userDict objectForKey:@"username"]];
    [[UserInfo shareInfo] setClassName:[userDict objectForKey:@"className"]];
    [[UserInfo shareInfo] setGradeName:[userDict objectForKey:@"gradeName"]];
    [[UserInfo shareInfo] setSchoolName:[userDict objectForKey:@"schoolName"]];
    
    
    [[UserInfo shareInfo] setSchool_id:[[userDict objectForKey:@"school_id"] intValue]];
    [[UserInfo shareInfo] setGrade:[[userDict objectForKey:@"grade"] intValue]];
    [[UserInfo shareInfo] setClass_id:[[userDict objectForKey:@"class_id"] intValue]];
    [[UserInfo shareInfo] setColumn:[[userDict objectForKey:@"column"] intValue]];
    [[UserInfo shareInfo] setRow:[[userDict objectForKey:@"row"] intValue]];
    [[UserInfo shareInfo] setIdentity:[[userDict objectForKey:@"position"] intValue]];
    
    NSDictionary *classroomDict=[dict objectForKey:@"classroom"];
    [[ServerInfo shareInfo] setClassroomIP:[classroomDict objectForKey:@"ip"]];
    [[ServerInfo shareInfo] setClassroomPort:[[classroomDict objectForKey:@"port"] intValue]];
    
    NSDictionary *educationDict=[dict objectForKey:@"education"];
    [[ServerInfo shareInfo] setEducationIP:[educationDict objectForKey:@"ip"]];
    [[ServerInfo shareInfo] setEducationPort:[[educationDict objectForKey:@"port"] intValue]];
    
    NSDictionary *queryDict=[dict objectForKey:@"query"];
    [[ServerInfo shareInfo] setQueryIP:[queryDict objectForKey:@"ip"]];
    [[ServerInfo shareInfo] setQueryPort:[[queryDict objectForKey:@"port"] intValue]];
    
    NSDictionary *webdavDict=[dict objectForKey:@"webdav"];
    [[ServerInfo shareInfo] setWebdavIP:[webdavDict objectForKey:@"ip"]];
    [[ServerInfo shareInfo] setWebdavPassword:[webdavDict objectForKey:@"password"]];
    [[ServerInfo shareInfo] setWebdavUserName:[webdavDict objectForKey:@"username"]];
    
    NSDictionary *webDict=[dict objectForKey:@"webserver"];
    [[ServerInfo shareInfo] setWebIP:[webDict objectForKey:@"ip"]];
    
    NSDictionary *netWorkDisk = [dict objectForKey:@"networkDisk"];
    
    [[PrivateServerInfo shareInfo] setWebdavIP:[netWorkDisk objectForKey:@"ip"]];
    [[PrivateServerInfo shareInfo] setWebdavDir:[netWorkDisk objectForKey:@"WEBDAV_DIR"]];
    [[PrivateServerInfo shareInfo] setWebdavUserName:[netWorkDisk objectForKey:@"username"]];
    [[PrivateServerInfo shareInfo] setWebdavPassword:[netWorkDisk objectForKey:@"password"]];
    
    [self createWebDavDefaultDir];
    
    [self loginSuccess];
    
    [app performSelector:@selector(loginSuccess) withObject:nil afterDelay:0.2];
    
    [URFileTool createLocalDirectory:[NSString stringWithFormat:@"%@/%d",USER_DIR,[[UserInfo shareInfo] uid]]];
    
    //拷贝数据库
    NSString *localPath=[URFileTool getLocalFilePath:[NSString stringWithFormat:@"USER/%d/%@",[[UserInfo shareInfo] uid],BLOG_DATABASE_NAME]];
    if (![URFileTool isExistsFilePath:localPath]) {
        [URFileTool copyFile:[URFileTool getResourcesFile:BLOG_DATABASE_NAME] desPath:localPath];
    }
    [self getAllUserInfo];
}

- (void)getAllUserInfo{
    NSString *url = [NSString stringWithFormat:@"http://%@:%d/alluser",SERVER_IP,HTTP_SERVER_PORT1];
    
    __block LoginViewController *weekSelf = self;
    [SVHTTPRequest GET:url
            parameters:nil
            completion:^(id response, NSHTTPURLResponse *urlResponse, NSError *error) {
                NSDictionary *dict;
                if ([response isKindOfClass:[NSData class]]) {
                    dict=[NSJSONSerialization JSONObjectWithData:response options:NSJSONReadingAllowFragments error:nil];
                }else{
                    dict=response;
                }
                [weekSelf getAllUserInfoDone:dict];
            }];
}

- (void)getAllUserInfoDone:(NSDictionary *)dict{
    int code = [[dict objectForKey:@"code"] intValue];
    if (code!=200) {
        NSLog(@"获取好友信息失败");
        return;
    }
    
    NSArray *array = [dict objectForKey:@"info"];
    
    FMDatabasePool *dbPool = [FMDatabasePool databasePoolWithPath:BLOG_DATABASE_PATH];
    [dbPool inDatabase:^(FMDatabase *db) {
        for (NSDictionary *user in array) {
            NSString *sql = [NSString stringWithFormat:@"delete from friends where id=%d",[[user objectForKey:@"id"] intValue]];
            [db executeUpdate:sql];
            
            NSString *sql1 = [NSString stringWithFormat:@"INSERT INTO friends(`id`,`nick`) VALUES('%d','%@')",[[user objectForKey:@"id"] intValue],[user objectForKey:@"nick"]];
            [db executeUpdate:sql1];
        }
    }];
    [dbPool releaseAllDatabases];
    NSLog(@"获取好友信息成功");
}


- (void)createWebDavDefaultDir{
    self.webDav=[[FMIWebDav alloc] initWithDelegate:self];
    
    [self.webDav createDir:[NSString stringWithFormat:@"%d",[[LessonsInfo shareInfo] lessonsID]]];
}

#pragma mark====================webdav回掉=========================
/**
 *  TODO:创建文件夹成功
 *
 *  @param dirPath 文件夹地址
 *
 *  @author 沈桢
 *  @since
 */
-(void)createDirDone:(NSString *)dirPath{
    [self.webDav createDir:[NSString stringWithFormat:@"%d/%@",[[LessonsInfo shareInfo] lessonsID],WEBDAV_EXERCISE_DIR]];
    [URLog debug:@"创建webdav目录成功"];
    [self.loadingView close];
}

/**
 TODO:创建文件夹错误
 
 @author 王尧
 @since 3.0
 */
- (void)createDirFailed:(NSString *)error{
    [URLog debug:@"创建webdav目录失败"];
    [self.loadingView close];
}

-(void)loginErr:(NSString *)err{
    self.warnLabel.text=err;
    
    [self.loadingView close];
    
    CATransition *animation = [CATransition animation];
    [animation setDuration:1.0];
    [animation setFillMode:kCAFillModeForwards];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    [animation setType:@"rippleEffect"];// rippleEffect
    [animation setSubtype:kCATransitionFromTop];
    [self.view.layer addAnimation:animation forKey:nil];
    
    [self performSelector:@selector(showErr) withObject:nil afterDelay:0.3];
}


- (void)showNormalLoginView{
    [self.loginbtn setImage:[UIImage imageNamed:@"login_btn.png"] forState:UIControlStateNormal];
    [self.loginbtn setImage:[UIImage imageNamed:@"login_btn_1.png"] forState:UIControlStateHighlighted];
    
    [self.offLineImageView setHidden:YES];
}

- (void)showOffLineLoginView{
    [self.loginbtn setImage:[UIImage imageNamed:@"offLineLogin_btn.png"] forState:UIControlStateNormal];
    [self.loginbtn setImage:[UIImage imageNamed:@"offLineLogin_btn_dn.png"] forState:UIControlStateHighlighted];
    
    [self.offLineImageView setHidden:NO];
}

- (void)serverConnectSuccess{
    [app setIsOfflineLogin:NO];
    [URLog debug:@"Login 连接成功"];
    [self.loadingView close];
    [self showNormalLoginView];
    [self cancelReconnectTimer];
}

- (void)startReconnectTimer{
    [URLog debug:@"Login  启动重连定时器"];
    [self cancelReconnectTimer];
    self.reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f target:self selector:@selector(reconnect) userInfo:nil repeats:YES];
}

- (void)cancelReconnectTimer{
     [URLog debug:@"Login 销毁重连定时器"];
    if (self.reconnectTimer) {
        [self.reconnectTimer invalidate];
        self.reconnectTimer = nil;
    }
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(reconnect) object:nil];
}

- (void)reconnect{
    [URLog debug:@"Login  开始重连"];
    [self.loadingView show];
    [_loginServer connectServer];
}

/*!
 *  TODO:服务器连接错误
 *
 *  @param err
 *
 *  @author 沈桢
 *  @since
 */
-(void)serverConnectError:(NSString *)err code:(int)code{
    //登录失败会返回2个code  一次500 一次0     gujun
    /*
        打开离线功能
     */
    [self.loadingView close];
    
    
    //FIXME:wangyao
    [self showOffLineLoginView];
    [app setIsOfflineLogin:YES];
    
    //启动重新连接定时
    [self startReconnectTimer];
    
    
    /*
    if ([self offLineCheckLogin]) {
    }else{
        if (code == 0) {
            return;
        }
        if (code==61) {
            [self loginErr:@"服务器连接错误"];
        }else{
            [self loginErr:@"服务器连接错误,请检测网络"];
        }
    }
     */
}

/**
 TODO:离线登录，校验sandbox中的用户名密码是否正确
 
 @return  是否允许登录成功
 
 @author 王尧
 @since 3.0
 */
- (BOOL)offLineCheckLogin{
    NSString *loginName = self.tfUsername.text;
    NSString *password  = self.tfPassword.text;
    
    NSDictionary *cacheAccountDict = [[NSUserDefaults standardUserDefaults] objectForKey:LOGIN_ACCOUNT_CACHE];
    
    NSString *cachePassword = [cacheAccountDict objectForKey:loginName];
    
    if (cachePassword && [cachePassword isEqualToString:password]) {
        return YES;
    }
    
    return NO;
}

-(void)showErr{
    self.warnView.hidden=NO;
    self.warnView.center=CGPointMake(1024+self.view.frame.size.width/2, self.warnView.center.y);
    [UIView animateWithDuration:0.6 animations:^{
        self.warnView.center=CGPointMake(self.view.frame.size.width/2+70, self.warnView.center.y);
    } completion:^(BOOL finished) {

    }];
}

-(void)hideErr{
    if (self.warnView.hidden==YES) return;
    
    [UIView animateWithDuration:0.6 animations:^{
        self.warnView.center=CGPointMake(-self.view.frame.size.width/2, self.warnView.center.y);
    } completion:^(BOOL finished) {
        self.warnView.hidden=YES;
    }];
}

/*!
 *  选择
 *
 *  @param sender <#sender description#>
 *
 *  @author gujun
 *  @since
 */
- (IBAction)aboutUsAction:(id)sender {
    LoginSettingView *view=[[[NSBundle mainBundle] loadNibNamed:@"LoginSettingView" owner:self options:nil] lastObject];
    view.frame=CGRectMake(0, 0, view.frame.size.width, view.frame.size.height);
    view.delegate = self;
    [self.view addSubview:view];
}

/*!
 *  更改ip
 *
 *  @author gujun
 *  @since
 */
-(void)changeIp{
    ChangeIpView *view=[[[NSBundle mainBundle] loadNibNamed:@"ChangeIpView" owner:self options:nil] lastObject];
    view.frame=CGRectMake(0, 0, view.frame.size.width, view.frame.size.height);
    [self.view addSubview:view];
}

/*!
 *  关于我们
 *
 *  @author gujun
 *  @since
 */
-(void)showAboutUs{
    AboutUsView *view=[[AboutUsView alloc] initWithFrame:self.view.bounds];
    view.delegate = self;
    [self.view addSubview:view];
}

#pragma mark
#pragma mark ============ AboutUsViewDelegate ============
- (void)openUrl:(NSURL *)url
{
    [[UIApplication sharedApplication] openURL:url];
}

@end
