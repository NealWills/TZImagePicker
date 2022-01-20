//
//  TZPhotoEditViewController.m
//  TZImagePickerController
//
//  Created by Administer on 2022/1/19.
//

#import "TZPhotoEditViewController.h"
#import "UIView+TZLayout.h"
#import "TZImagePickerController.h"

#define tz_kSize(x) ceilf(((x)*[[UIScreen mainScreen] bounds].size.width/375.f))

#define TZImageEditToolFilePath(file) [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:file]

/// 状态栏高度(来电等情况下，状态栏高度会发生变化，所以应该实时计算，iOS 13 起，来电等情况下状态栏高度不会改变)
#define tz_StatusBarHeight (UIApplication.sharedApplication.statusBarHidden ? 0 : UIApplication.sharedApplication.statusBarFrame.size.height)
/// navigationBar 的静态高度
#define tz_NavigationBarHeight 44
/// 代表(导航栏+状态栏)，这里用于获取其高度
#define tz_NavigationContentTop (tz_StatusBarHeight + tz_NavigationBarHeight)

typedef NS_ENUM(NSInteger, TZImageEditToolCurrentMoveItemStyle) {
    TZImageEditToolCurrentMoveItemStyleNone = 0,
    TZImageEditToolCurrentMoveItemStylePoint = 1,
    TZImageEditToolCurrentMoveItemStyleMask = 2,
    TZImageEditToolCurrentMoveItemStyleImage = 3,
};


@interface ZTImageEditToolViewControllerPinView : UIView

@end

@implementation ZTImageEditToolViewControllerPinView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return [super hitTest:point withEvent:event];
}

@end

@interface TZPhotoEditViewController ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;

@property (nonatomic, strong) NSArray <UIButton *>*moveButtonList;
@property (nonatomic, strong) NSArray <UIView *>*areaViewList;
@property (nonatomic, strong) NSArray <UIView *>*circleMaskList;
@property (nonatomic, strong) UIImageView *avatarCircle;

@property (nonatomic, assign) int currentMoveIndex;
@property (nonatomic, assign) TZImageEditToolCurrentMoveItemStyle currentMoveItemStyle;

@property (nonatomic, assign) CGPoint touchBeginPoint;
@property (nonatomic, assign) CGPoint maskTouchBeginPoint;
@property (nonatomic, assign) CGPoint iconTouchBeginPoint;

@property (nonatomic, assign) CGFloat iconScaleLeftValue;
@property (nonatomic, assign) CGFloat iconScaleTopValue;
@property (nonatomic, assign) CGFloat iconScaleCurrentValue;
@property (nonatomic, assign) CGPoint iconScaleBeginPoint;

@property (nonatomic, assign) CGSize iconStartSize;

@property (nonatomic, strong) ZTImageEditToolViewControllerPinView *pinView;

@property (nonatomic, strong) UIView *navBackGroundView;
@property (nonatomic, strong) UIView *toolBar;

@end

@implementation TZPhotoEditViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    CGFloat safeBottom = screenHeight / screenWidth > 1.9 ? 34 : 20;
    
    self.touchBeginPoint = CGPointMake(-1, -1);
    self.currentMoveIndex = -1;
    self.currentMoveItemStyle = TZImageEditToolCurrentMoveItemStyleNone;
        
    self.imageView = [[UIImageView alloc] init];
    [self.view addSubview:self.imageView];
    
    UIView *leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 60, 44)];
    UIButton *leftButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 60, 44)];
    [leftView addSubview:leftButton];
    [leftButton setTitleColor:[UIColor colorWithWhite:1 alpha:1] forState:(UIControlStateNormal)];
    leftButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [leftButton setTitle:@"取消" forState:(UIControlStateNormal)];
    [leftButton addTarget:self action:@selector(cancelButtonClickAction:) forControlEvents:(UIControlEventTouchUpInside)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:leftView];
    
    UIView *rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 60, 44)];
    UIButton *rightButton = [[UIButton alloc] initWithFrame:rightView.bounds];
    [rightView addSubview:rightButton];
    [rightButton setTitleColor:[UIColor colorWithWhite:1 alpha:1] forState:(UIControlStateNormal)];
    rightButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [rightButton setTitle:@"确定" forState:(UIControlStateNormal)];
    [rightButton addTarget:self action:@selector(sureButtonClickAction:) forControlEvents:(UIControlEventTouchUpInside)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:rightView];
    
    [self.areaViewList enumerateObjectsUsingBlock:^(UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self.view addSubview:obj];
        if (idx != 4) {
            obj.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
        }
    }];
    
    [self.circleMaskList enumerateObjectsUsingBlock:^(UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self.view addSubview:obj];
        obj.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    }];
    
    [self.moveButtonList enumerateObjectsUsingBlock:^(UIButton * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self.view addSubview:obj];
        obj.userInteractionEnabled = NO;
        obj.frame = CGRectMake(-10, -10, 10, 10);
        obj.clipsToBounds = YES;
        obj.layer.cornerRadius = 5;
        obj.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3];
        obj.layer.borderColor = [UIColor colorWithWhite:0 alpha:0.5].CGColor;
        obj.layer.borderWidth = 3;
    }];
    
    self.avatarCircle = [[UIImageView alloc] init];
    [self.view addSubview:self.avatarCircle];
    self.avatarCircle.contentMode = UIViewContentModeScaleAspectFit;
    self.avatarCircle.image = [UIImage imageNamed:@"edit_avatar_circle"];
    
    self.pinView = [[ZTImageEditToolViewControllerPinView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.pinView];
    self.pinView.userInteractionEnabled = YES;
    
    UIPinchGestureRecognizer *pinGes = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinGesAction:)];
    [self.pinView addGestureRecognizer:pinGes];
    self.pinView.userInteractionEnabled = YES;
    
    self.navBackGroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.tz_width, tz_NavigationContentTop)];
    [self.view addSubview:self.navBackGroundView];
    self.navBackGroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:1];
    
    self.toolBar = [[UIView alloc] initWithFrame:CGRectMake(0, screenHeight - safeBottom - tz_kSize(50), screenWidth, tz_kSize(50) + safeBottom)];
    [self.view addSubview:self.toolBar];
    self.toolBar.backgroundColor = [UIColor colorWithWhite:0 alpha:1];
    
    self.navigationController.navigationBar.backgroundColor = [UIColor colorWithWhite:0 alpha:1];
    UIImage *imageBG = [UIImage tz_imageNamedFromMyBundle:@"TZNavigationBarBlackBG"];
    [self.navigationController.navigationBar setBackgroundImage:imageBG forBarMetrics:(UIBarMetricsDefault)];
    
}

- (void)cancelButtonClickAction:(UIButton *)sender {
    if (self.cancelHandel) {
        self.cancelHandel();
    }
//    [self.navigationController popViewControllerAnimated:YES];
}

- (void)sureButtonClickAction:(UIButton *)sender {
//    [XDHubTool xd_showLoadingHUB];
    
    [self.moveButtonList enumerateObjectsUsingBlock:^(UIButton * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.hidden = YES;
    }];
    self.avatarCircle.hidden = YES;
    [self.circleMaskList enumerateObjectsUsingBlock:^(UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.hidden = YES;
    }];
    
    UIGraphicsBeginImageContextWithOptions(self.areaViewList[4].tz_size, NO, [UIScreen mainScreen].scale);

    CGContextRef context = UIGraphicsGetCurrentContext();

    if (context == NULL)
    {
        return;
    }
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, -self.areaViewList[4].tz_left, -self.areaViewList[4].tz_top);
    [self.view snapshotViewAfterScreenUpdates:YES];
    if( [self respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)])
    {
        [self.view drawViewHierarchyInRect:self.view.bounds afterScreenUpdates:NO];
    }else
    {
         [self.view.layer renderInContext:context];
    }

    CGContextRestoreGState(context);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();

    UIGraphicsEndImageContext();
    
    [self.moveButtonList enumerateObjectsUsingBlock:^(UIButton * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.hidden = NO;
    }];
    self.avatarCircle.hidden = NO;
    self.avatarCircle.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    [self.circleMaskList enumerateObjectsUsingBlock:^(UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.hidden = NO;
    }];
    
    NSData *imageData = UIImageJPEGRepresentation(image, 1);
    NSString *filePath = TZImageEditToolFilePath(@"documents");
    filePath = [NSString stringWithFormat:@"%@/ImageEditToolFilePath/", filePath];
    BOOL isDir;
    BOOL isDirExt = [NSFileManager.defaultManager fileExistsAtPath:filePath isDirectory:&isDir];
    if (isDir && isDirExt) {
//                NSLog(@"文件夹 sqlite 存在");
    } else {
        NSError *error;
        if (error) {
            if (self.errorHandel) {
                self.errorHandel(error);
            }
            return;
        }
        BOOL isCreateSuccess = [NSFileManager.defaultManager createDirectoryAtPath:filePath withIntermediateDirectories:true attributes:nil error:&error];
        if (isCreateSuccess) {
//                    NSLog(@"文件夹 sqlite 创建成功");
        } else {
//                    NSLog(@"error:%@", error.localizedDescription);
        }
    }
    
    NSString *path = [NSString stringWithFormat:@"%@_edit_icon_%.0f.jpg", filePath, [[NSDate alloc] init].timeIntervalSince1970];
    NSError *error;
    [imageData writeToFile:path options:0 error:&error];
    if (error) {
        if (self.errorHandel) {
            self.errorHandel(error);
        }
        return;
    }
    
    
    if (self.finishHandel) {
        self.finishHandel(image, path);
    }
    
    
}

- (void)setIcon:(UIImage *)icon {
    _icon = icon;
    
    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    CGFloat safeBottom = screenHeight / screenWidth > 1.9 ? 34 : 20;
    
    CGSize iconSize = self.icon.size;
    CGFloat x = 0;
    CGFloat y = 0;
    CGFloat width = 0;
    CGFloat height = 0;
    
    CGFloat judge = (screenHeight - self.toolBar.tz_height - self.navBackGroundView.tz_height) / screenWidth;
    if (iconSize.height / iconSize.width > judge) {
        height = screenHeight - self.toolBar.tz_height - self.navBackGroundView.tz_height;
        width = iconSize.width / iconSize.height * height;
    } else {
        width = screenWidth;
        height = iconSize.height / iconSize.width * width;
    }
    
    y = (screenHeight - self.toolBar.tz_height - self.navBackGroundView.tz_height - height) / 2.0 + self.navBackGroundView.tz_height;
    x = (screenWidth - width) / 2.0;
    self.imageView.frame = CGRectMake(x, y, width, height);
    self.imageView.image = self.icon;
    
    CGFloat minLength = MIN(width, height);
    minLength = MIN(minLength, screenWidth);
    CGPoint movePoint0 = CGPointMake(x, y);
    CGPoint movePoint1 = CGPointMake(movePoint0.x + width, movePoint0.y);
    CGPoint movePoint2 = CGPointMake(movePoint0.x, movePoint0.y + height);
    CGPoint movePoint3 = CGPointMake(movePoint0.x + width, movePoint0.y + height);
    self.moveButtonList[0].center = movePoint0;
    self.moveButtonList[1].center = movePoint1;
    self.moveButtonList[2].center = movePoint2;
    self.moveButtonList[3].center = movePoint3;
        
    [self areaChange];
    
    self.maskTouchBeginPoint = CGPointMake(self.areaViewList[4].tz_left, self.areaViewList[4].tz_right);
    self.iconTouchBeginPoint = CGPointMake(self.imageView.tz_left, self.imageView.tz_top);
    self.iconStartSize = self.imageView.tz_size;
    self.iconScaleCurrentValue = 1;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.currentMoveIndex = -1;
    
    UITouch *touch = touches.allObjects.lastObject;
    CGPoint p = [touch locationInView:self.view];
    for (int i = 0; i < self.moveButtonList.count; i++) {
        UIButton *obj = self.moveButtonList[i];
        if ([self point:p isInPoint:obj.center withCorner:obj.tz_width * 2]) {
            self.currentMoveIndex = i;
            self.currentMoveItemStyle = TZImageEditToolCurrentMoveItemStylePoint;
            return;
        }
    }
    self.touchBeginPoint = p;
    if ([self point:p isInPoint:self.areaViewList[4].center withCorner:MIN(self.areaViewList[4].tz_width / 2.0, self.areaViewList[4].tz_height / 2.0)]) {
        self.iconTouchBeginPoint = CGPointMake(self.imageView.tz_left, self.imageView.tz_top);
        self.currentMoveIndex = -1;
        self.currentMoveItemStyle = TZImageEditToolCurrentMoveItemStyleImage;
        return;
    }
    CGPoint pMask = [touch locationInView:self.areaViewList[4]];
    if (pMask.x < 0 || pMask.y < 0 || pMask.x > self.areaViewList[4].tz_width || pMask.y > self.areaViewList[4].tz_height) {
        self.iconTouchBeginPoint = CGPointMake(self.imageView.tz_left, self.imageView.tz_top);
        self.currentMoveIndex = -1;
        self.currentMoveItemStyle = TZImageEditToolCurrentMoveItemStyleImage;
        return;
    }
    
    self.maskTouchBeginPoint = CGPointMake(self.areaViewList[4].tz_left, self.areaViewList[4].tz_top);
    self.currentMoveIndex = -1;
    self.currentMoveItemStyle = TZImageEditToolCurrentMoveItemStyleMask;
    
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = touches.allObjects.lastObject;
    CGPoint p = [touch locationInView:self.view];
    if (self.currentMoveIndex >= 0 && self.currentMoveItemStyle == TZImageEditToolCurrentMoveItemStylePoint) {
        [self point:self.currentMoveIndex moveToNewPoint:p];
    } else if (self.currentMoveItemStyle == TZImageEditToolCurrentMoveItemStyleMask) {
        CGFloat offsetX = p.x - self.touchBeginPoint.x;
        CGFloat offsetY = p.y - self.touchBeginPoint.y;
        CGPoint newPoint = CGPointMake(self.maskTouchBeginPoint.x + offsetX, self.maskTouchBeginPoint.y + offsetY);
        [self maskViewMoveToNewPoint:newPoint];
    } else if (self.currentMoveItemStyle == TZImageEditToolCurrentMoveItemStyleImage) {
        CGFloat offsetX = p.x - self.touchBeginPoint.x;
        CGFloat offsetY = p.y - self.touchBeginPoint.y;
        CGPoint newPoint = CGPointMake(self.iconTouchBeginPoint.x + offsetX, self.iconTouchBeginPoint.y + offsetY);
        [self imageViewMoveToNewPoint:newPoint];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.currentMoveIndex = -1;
    self.currentMoveItemStyle = TZImageEditToolCurrentMoveItemStyleNone;
    self.touchBeginPoint = CGPointMake(-1, -1);
}

- (void)imageViewMoveToNewPoint:(CGPoint)point {
    
    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    CGFloat safeBottom = screenHeight / screenWidth > 1.9 ? 34 : 20;
    
    CGPoint newP = CGPointMake(point.x, point.y);
    if (self.imageView.tz_width > screenWidth) {
        CGFloat minX = MIN(1, newP.x);
        CGFloat maxX = MAX(screenWidth - 1, newP.x);
        if (minX + self.imageView.tz_width > screenWidth) {
            self.imageView.tz_left = minX;
        } else {
            self.imageView.tz_left = maxX - self.imageView.tz_width;
        }
    } else {
        self.imageView.tz_left = (screenWidth - self.imageView.tz_width) / 2.0;
    }
    if (self.imageView.tz_height > screenHeight - self.toolBar.tz_height - self.navBackGroundView.tz_height) {
        CGFloat minY = MIN(self.navBackGroundView.tz_bottom, newP.y);
        CGFloat maxY = MAX(self.toolBar.tz_top, newP.y);
        if (minY + self.imageView.tz_height > self.toolBar.tz_top) {
            self.imageView.tz_top = minY;
        } else {
            self.imageView.tz_top = maxY - self.imageView.tz_height;
        }
    } else {
        self.imageView.tz_top = (screenHeight - self.toolBar.tz_height - self.navBackGroundView.tz_height - self.imageView.tz_height) / 2.0 + self.navBackGroundView.tz_height;
    }
}

- (void)maskViewMoveToNewPoint:(CGPoint)point {
    
    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    CGFloat safeBottom = screenHeight / screenWidth > 1.9 ? 34 : 20;
    
    CGFloat maxWidth = MIN(screenWidth - 2, self.imageView.tz_width);
    if (self.areaViewList[4].tz_width > maxWidth) {
        self.areaViewList[4].tz_width = maxWidth;
    }
    CGPoint newP = CGPointMake(point.x, point.y);
    CGFloat minX = MAX(1, self.imageView.tz_left);
    if (newP.x < minX) {
        newP.x = minX;
    }
    
    CGFloat maxX = MIN(screenWidth - 1, self.imageView.tz_right);
    if (newP.x + self.areaViewList[4].tz_width > maxX) {
        newP.x = maxX - self.areaViewList[4].tz_width;
    }
    CGFloat minY = MAX(tz_NavigationContentTop + 1, self.imageView.tz_top);
    if (newP.y < minY) {
        newP.y = minY;
    }
    CGFloat maxY = MIN(self.toolBar.tz_top - 1, self.imageView.tz_bottom);
    if (newP.y > maxY - self.areaViewList[4].tz_height) {
        newP.y = maxY - self.areaViewList[4].tz_height;
    }
    self.areaViewList[4].tz_left = newP.x;
    self.areaViewList[4].tz_top = newP.y;
    self.moveButtonList[0].tz_centerX = self.areaViewList[4].tz_left + 1;
    self.moveButtonList[0].tz_centerY = self.areaViewList[4].tz_top;
    self.moveButtonList[1].tz_centerX = self.areaViewList[4].tz_right - 1;
    self.moveButtonList[1].tz_centerY = self.areaViewList[4].tz_top;
    self.moveButtonList[2].tz_centerX = self.areaViewList[4].tz_left;
    self.moveButtonList[2].tz_centerY = self.areaViewList[4].tz_bottom;
    self.moveButtonList[3].tz_centerX = self.areaViewList[4].tz_right;
    self.moveButtonList[3].tz_centerY = self.areaViewList[4].tz_bottom;
    UIView *obj = self.areaViewList[4];
    self.areaViewList[0].frame = CGRectMake(0, 0, obj.tz_left, obj.tz_top);
    self.areaViewList[1].frame = CGRectMake(obj.tz_left, 0, obj.tz_width, obj.tz_top);
    self.areaViewList[2].frame = CGRectMake(obj.tz_right, 0, screenWidth - obj.tz_right, obj.tz_top);
    self.areaViewList[3].frame = CGRectMake(0, obj.tz_top, obj.tz_left, obj.tz_height);
    self.areaViewList[5].frame = CGRectMake(obj.tz_right, obj.tz_top, screenWidth - obj.tz_right, obj.tz_height);
    self.areaViewList[6].frame = CGRectMake(0, obj.tz_bottom, obj.tz_left, screenHeight - obj.tz_bottom);
    self.areaViewList[7].frame = CGRectMake(obj.tz_left, obj.tz_bottom, obj.tz_width, screenHeight - obj.tz_bottom);
    self.areaViewList[8].frame = CGRectMake(obj.tz_right, obj.tz_bottom, screenWidth - obj.tz_right, screenHeight - obj.tz_bottom);
    self.avatarCircle.frame = self.areaViewList[4].frame;
    
    CGFloat maskMin = MIN(obj.tz_width, obj.tz_height);
    CGFloat offsetX = obj.tz_width - maskMin;
    CGFloat offsetY = obj.tz_height - maskMin;
    if (offsetX > 0) {
        self.circleMaskList[0].frame = CGRectMake(obj.tz_left, obj.tz_top, offsetX / 2.0, obj.tz_height);
        self.circleMaskList[1].frame = CGRectMake(obj.tz_right - offsetX / 2.0, obj.tz_top, offsetX / 2.0, obj.tz_height);
    } else {
        self.circleMaskList[0].frame = CGRectMake(obj.tz_left, obj.tz_top, obj.tz_width, offsetY/2.0);
        self.circleMaskList[1].frame = CGRectMake(obj.tz_left, obj.tz_bottom - offsetY / 2.0, obj.tz_width, offsetY/2.0);
    }
}

- (void)pinGesAction:(UIPinchGestureRecognizer *)ges {
    CGPoint point0;
    CGPoint point1;
    switch (ges.state) {
        case UIGestureRecognizerStateBegan:
            point0 = [ges locationOfTouch:0 inView:self.view];
            point1 = [ges locationOfTouch:1 inView:self.view];
            self.iconScaleBeginPoint = CGPointMake((point0.x + point1.x) / 2.0, (point0.y + point1.y) / 2.0);
            self.iconScaleLeftValue = (self.iconScaleBeginPoint.x - self.imageView.tz_left) / self.imageView.tz_width;
            self.iconScaleTopValue = (self.iconScaleBeginPoint.y - self.imageView.tz_top) / self.imageView.tz_height;
            break;
        case UIGestureRecognizerStateChanged:
            [self imageScaleWithPoint:self.iconScaleBeginPoint scale:ges.scale - 1];
            break;
        default:
            self.iconScaleCurrentValue = self.iconScaleCurrentValue + (ges.scale - 1);
            self.iconScaleCurrentValue = self.iconScaleCurrentValue > 4 ? 4 : self.iconScaleCurrentValue;
            [self imageScaleEndAction];
            break;
    }
}

- (void)imageScaleWithPoint:(CGPoint)point scale:(CGFloat)scale {
    
    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    CGFloat safeBottom = screenHeight / screenWidth > 1.9 ? 34 : 20;
    
    CGFloat newScale = self.iconScaleCurrentValue + scale;
    newScale = newScale >= 4 ? 4 : newScale;
    
    CGSize newSize = CGSizeMake(self.iconStartSize.width * newScale, self.iconStartSize.height * newScale);
    CGFloat leftX = newSize.width * self.iconScaleLeftValue;
    CGFloat leftY = newSize.height * self.iconScaleTopValue;
    self.imageView.frame = CGRectMake(self.iconScaleBeginPoint.x - leftX, self.iconScaleBeginPoint.y - leftY, newSize.width, newSize.height);
}

- (void)imageScaleEndAction {
    
    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    CGFloat safeBottom = screenHeight / screenWidth > 1.9 ? 34 : 20;
    
    if (self.imageView.tz_width > screenWidth && self.imageView.tz_height > screenHeight - self.navBackGroundView.tz_height - self.toolBar.tz_height) {
        return;
    }
    if (self.imageView.tz_width < screenWidth && self.imageView.tz_height < screenHeight - self.navBackGroundView.tz_height - self.toolBar.tz_height) {
        
        CGSize iconSize = self.icon.size;
        CGFloat x = 0;
        CGFloat y = 0;
        CGFloat width = 0;
        CGFloat height = 0;
        
        CGFloat judge = (screenHeight - self.toolBar.tz_height - self.navBackGroundView.tz_height) / screenWidth;
        if (iconSize.height / iconSize.width > judge) {
            height = screenHeight - self.toolBar.tz_height - self.navBackGroundView.tz_height;
            width = iconSize.width / iconSize.height * height;
        } else {
            width = screenWidth;
            height = iconSize.height / iconSize.width * width;
        }
        y = (screenHeight - self.toolBar.tz_height - self.navBackGroundView.tz_height - height) / 2.0 + self.navBackGroundView.tz_height;
        x = (screenWidth - width) / 2.0;
        self.iconScaleCurrentValue = 1;
        [UIView animateWithDuration:0.2 animations:^{
            self.imageView.frame = CGRectMake(x, y, width, height);
        } completion:^(BOOL finished) {
            [self imageScaleReSizeMaskView];
        }];
        return;
    }
    if (self.imageView.tz_width < screenWidth) {
        [UIView animateWithDuration:0.2 animations:^{
            self.imageView.tz_left = (screenWidth - self.imageView.tz_width) / 2.0;
        } completion:^(BOOL finished) {
            [self imageScaleReSizeMaskView];
        }];
        return;
    }
    if (self.imageView.tz_height < screenHeight - self.navBackGroundView.tz_height - self.toolBar.tz_height) {
        [UIView animateWithDuration:0.2 animations:^{
            self.imageView.tz_top = (screenHeight - self.navBackGroundView.tz_height - self.toolBar.tz_height - self.imageView.tz_height) / 2.0 + self.navBackGroundView.tz_height;
        } completion:^(BOOL finished) {
            [self imageScaleReSizeMaskView];
        }];
        return;
    }
}

- (void)imageScaleReSizeMaskView {
    
    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    CGFloat safeBottom = screenHeight / screenWidth > 1.9 ? 34 : 20;

    CGFloat minX = MAX(1, self.imageView.tz_left);
    CGFloat maxX = MIN(screenWidth - 1, self.imageView.tz_right);
    CGFloat minY = MAX(self.navBackGroundView.tz_bottom + 1, self.imageView.tz_top);
    CGFloat maxY = MIN(self.toolBar.tz_top - 1, self.imageView.tz_bottom);
    
    for (int i = 0; i < 4; i++) {
        if (self.moveButtonList[i].tz_centerX < minX) {
            self.moveButtonList[i].tz_centerX = minX;
        } else if (self.moveButtonList[i].tz_centerX > maxX) {
            self.moveButtonList[i].tz_centerX = maxX;
        }
        if (self.moveButtonList[i].tz_centerY < minY) {
            self.moveButtonList[i].tz_centerY = minY;
        } else if (self.moveButtonList[i].tz_centerY > maxY) {
            self.moveButtonList[i].tz_centerY = maxY;
        }
    }
    
    [self areaChange];
    
}

- (void)point:(NSInteger)index moveToNewPoint:(CGPoint)p {
    UIButton *obj = self.moveButtonList[index];
    UIButton *xObj = self.moveButtonList[(index + 2) % 4];
    UIButton *yObj;
    if (index < 2) {
        yObj = self.moveButtonList[(index + 1) % 2];
    } else {
        yObj = self.moveButtonList[(index + 1) % 2 + 2];
    }
    CGPoint newP = CGPointMake(p.x, p.y);
    CGPoint oldP = obj.center;
    if ((newP.x - yObj.tz_centerX) < 50 && -(newP.x - yObj.tz_centerX) < 50) {
        newP.x = oldP.x;
    }
    if ((newP.y - xObj.tz_centerY) < 50 && -(newP.y - xObj.tz_centerY) < 50) {
        newP.y = oldP.y;
    }
    if (newP.x < self.imageView.tz_left) {
        newP.x = self.imageView.tz_left;
    }
    if (newP.x > self.imageView.tz_right) {
        newP.x = self.imageView.tz_right;
    }
    if (newP.y < self.imageView.tz_top) {
        newP.y = self.imageView.tz_top;
    }
    if (newP.y > self.imageView.tz_bottom) {
        newP.y = self.imageView.tz_bottom;
    }
    obj.center = newP;
    xObj.tz_centerX = newP.x;
    yObj.tz_centerY = newP.y;
    [self areaChange];
}

- (void)areaChange {
    
    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    CGFloat safeBottom = screenHeight / screenWidth > 1.9 ? 34 : 20;
    
    __block CGFloat minX = -999;
    __block CGFloat minY = -999;
    __block CGFloat maxX = -999;
    __block CGFloat maxY = -999;
    [self.moveButtonList enumerateObjectsUsingBlock:^(UIButton * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (minX == -999) {
            minX = obj.tz_centerX;
        } else {
            if (minX > obj.tz_centerX) {
                minX = obj.tz_centerX;
            }
        }
        if (minY == -999) {
            minY = obj.tz_centerY;
        } else {
            if (minY > obj.tz_centerY) {
                minY = obj.tz_centerY;
            }
        }
        if (maxX == -999) {
            maxX = obj.tz_centerX;
        } else {
            if (maxX < obj.tz_centerX) {
                maxX = obj.tz_centerX;
            }
        }
        if (maxY == -999) {
            maxY = obj.tz_centerY;
        } else {
            if (maxY < obj.tz_centerY) {
                maxY = obj.tz_centerY;
            }
        }
    }];

    self.areaViewList[4].frame = CGRectMake(minX - 0.5, minY - 0.5, maxX - minX + 1, maxY - minY + 1);
    UIView *obj = self.areaViewList[4];
    self.areaViewList[0].frame = CGRectMake(0, 0, obj.tz_left, obj.tz_top);
    self.areaViewList[1].frame = CGRectMake(obj.tz_left, 0, obj.tz_width, obj.tz_top);
    self.areaViewList[2].frame = CGRectMake(obj.tz_right, 0, screenWidth - obj.tz_right, obj.tz_top);
    self.areaViewList[3].frame = CGRectMake(0, obj.tz_top, obj.tz_left, obj.tz_height);
    self.areaViewList[5].frame = CGRectMake(obj.tz_right, obj.tz_top, screenWidth - obj.tz_right, obj.tz_height);
    self.areaViewList[6].frame = CGRectMake(0, obj.tz_bottom, obj.tz_left, screenHeight - obj.tz_bottom);
    self.areaViewList[7].frame = CGRectMake(obj.tz_left, obj.tz_bottom, obj.tz_width, screenHeight - obj.tz_bottom);
    self.areaViewList[8].frame = CGRectMake(obj.tz_right, obj.tz_bottom, screenWidth - obj.tz_right, screenHeight - obj.tz_bottom);
    self.avatarCircle.frame = self.areaViewList[4].frame;
    
    CGFloat maskMin = MIN(obj.tz_width, obj.tz_height);
    CGFloat offsetX = obj.tz_width - maskMin;
    CGFloat offsetY = obj.tz_height - maskMin;
    if (offsetX > 0) {
        self.circleMaskList[0].frame = CGRectMake(obj.tz_left, obj.tz_top, offsetX / 2.0, obj.tz_height);
        self.circleMaskList[1].frame = CGRectMake(obj.tz_right - offsetX / 2.0, obj.tz_top, offsetX / 2.0, obj.tz_height);
    } else {
        self.circleMaskList[0].frame = CGRectMake(obj.tz_left, obj.tz_top, obj.tz_width, offsetY/2.0);
        self.circleMaskList[1].frame = CGRectMake(obj.tz_left, obj.tz_bottom - offsetY / 2.0, obj.tz_width, offsetY/2.0);
    }
}

- (BOOL)point:(CGPoint)point isInPoint:(CGPoint)inPoint withCorner:(CGFloat)corner {
    CGFloat x = point.x - inPoint.x;
    CGFloat y = point.y - inPoint.y;
    if (x * x + y * y <= corner * corner) {
        return YES;
    }
    return NO;
}

- (NSArray<UIButton *> *)moveButtonList {
    if (!_moveButtonList) {
        UIButton *button0 = [[UIButton alloc] init];
        UIButton *button1 = [[UIButton alloc] init];
        UIButton *button2 = [[UIButton alloc] init];
        UIButton *button3 = [[UIButton alloc] init];
        _moveButtonList = @[button0, button1, button2, button3];
    }
    return _moveButtonList;
}

- (NSArray<UIView *> *)circleMaskList {
    if (!_circleMaskList) {
        UIView *view0 = [[UIView alloc] init];
        UIView *view1 = [[UIView alloc] init];
        _circleMaskList = @[view0, view1];
    }
    return _circleMaskList;
}

- (NSArray<UIView *> *)areaViewList {
    if (!_areaViewList) {
        UIView *view0 = [[UIView alloc] init];
        UIView *view1 = [[UIView alloc] init];
        UIView *view2 = [[UIView alloc] init];
        UIView *view3 = [[UIView alloc] init];
        UIView *view4 = [[UIView alloc] init];
        UIView *view5 = [[UIView alloc] init];
        UIView *view6 = [[UIView alloc] init];
        UIView *view7 = [[UIView alloc] init];
        UIView *view8 = [[UIView alloc] init];
        view4.layer.borderWidth = 1;
        view4.layer.borderColor = [UIColor colorWithWhite:0.5 alpha:0.5].CGColor;
        _areaViewList = @[
            view0, view1, view2,
            view3, view4, view5,
            view6, view7, view8,
        ];
    }
    return _areaViewList;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:1];
    }
    return self;
}



@end
