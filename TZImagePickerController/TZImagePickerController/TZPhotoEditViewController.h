//
//  TZPhotoEditViewController.h
//  TZImagePickerController
//
//  Created by Administer on 2022/1/19.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TZPhotoEditViewController : UIViewController

@property (nonatomic, strong) UIImage *icon;

@property (nonatomic, copy) void(^finishHandel)(UIImage *resultImage, NSString *filePath);
@property (nonatomic, copy) void(^cancelHandel)(void);
@property (nonatomic, copy) void(^errorHandel)(NSError *error);

@end

NS_ASSUME_NONNULL_END
