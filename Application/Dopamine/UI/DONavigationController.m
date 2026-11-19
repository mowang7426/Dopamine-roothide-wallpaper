//
//  DONavigationController.m
//  Dopamine
//
//  Created by tomt000 on 04/01/2024.
//

#import "DONavigationController.h"
#import <objc/runtime.h>
#import "DOModalBackAction.h"
#import "DOGlobalAppearance.h"
#import "DOThemeManager.h"
#import <Photos/Photos.h>

static NSString * const DOWallpaperPathName = @"DopamineWallpaper.png";

@interface DONavigationController (DOWallpaper)
- (NSString *)wallpaperPath;
- (void)reloadWallpaper;
- (void)showWallpaperAlert:(NSString *)message;
@end

@interface DOWallpaperPickerDelegate : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, weak) DONavigationController *navigationController;
@end

@implementation DOWallpaperPickerDelegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *, id> *)info
{
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (image) {
        // UIImage drawing applies rotation/mirroring; use oriented pixel dimensions,
        // not points, and render at scale 1 so the longest stored edge is <= 4096 px.
        CGFloat maxPixels = 4096.0;
        CGSize pixelSize = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
        CGFloat scale = MIN(1.0, maxPixels / MAX(pixelSize.width, pixelSize.height));
        CGSize size = CGSizeMake(MAX(1.0, floor(pixelSize.width * scale)),
                                 MAX(1.0, floor(pixelSize.height * scale)));
        UIGraphicsBeginImageContextWithOptions(size, NO, 1.0);
        [image drawInRect:(CGRect){CGPointZero, size}];
        UIImage *normalized = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        NSData *data = UIImagePNGRepresentation(normalized);
        NSString *path = [self.navigationController wallpaperPath];
        BOOL saved = data != nil && [data writeToFile:path atomically:YES];
        if (saved) {
            [self.navigationController reloadWallpaper];
        } else {
            [self.navigationController showWallpaperAlert:@"无法保存壁纸，请检查存储空间后重试。"];
        }
    } else {
        [self.navigationController showWallpaperAlert:@"无法读取所选图片。"];
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end

static DOWallpaperPickerDelegate *gWallpaperPickerDelegate;

@interface DONavigationController ()

@property (nonatomic) UIImageView *backgroundImageView;
@property (nonatomic, readwrite) BOOL customWallpaperActive;
@property (nonatomic) DOMainViewController *mainView;
@property (nonatomic) DOModalBackAction *backAction;
@property (nonatomic) UIImage *defaultBackgroundImage;
@property (nonatomic) NSLayoutConstraint *backgroundTopConstraint;
@property (nonatomic) NSLayoutConstraint *backgroundBottomConstraint;

@end

@interface UINavigationController (Private)
-(CGRect)_frameForViewController:(id)arg1;
@end

@implementation DONavigationController

- (void)viewDidLoad
{
    [self setupBackground];
    [super viewDidLoad];
    [self setNavigationBarHidden:YES];
    [self pushViewController:(self.mainView = [[DOMainViewController alloc] init]) animated:NO];
    [self setDelegate:self];
    [self setOverrideUserInterfaceStyle:UIUserInterfaceStyleDark];
}

- (void)setupBackground
{
    DOTheme *theme = [[DOThemeManager sharedInstance] enabledTheme];
    self.defaultBackgroundImage = [theme image];

    self.view.backgroundColor = [UIColor blackColor];
    self.backgroundImageView = [[UIImageView alloc] init];
    self.backgroundImageView.backgroundColor = [UIColor blackColor];
    self.backgroundImageView.clipsToBounds = YES;
    self.backgroundImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundImageView.userInteractionEnabled = NO;
    self.backgroundImageView.layer.zPosition = -1;

    [self.view insertSubview:self.backgroundImageView atIndex:0];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.backgroundImageView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backgroundImageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        (self.backgroundTopConstraint = [self.backgroundImageView.topAnchor constraintEqualToAnchor:self.view.topAnchor]),
        (self.backgroundBottomConstraint = [self.backgroundImageView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]),
    ]];
    [self reloadWallpaper];

    self.backAction = [[DOModalBackAction alloc] initWithAction:^{
        [self popViewControllerAnimated:YES];
    }];
    self.backAction.translatesAutoresizingMaskIntoConstraints = NO;
    self.backAction.hidden = YES;
    
    [self.view insertSubview:self.backAction atIndex:2];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.backAction.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backAction.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.backAction.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.backAction.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (NSString *)wallpaperPath
{
    NSArray *directories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[directories.firstObject stringByAppendingPathComponent:DOWallpaperPathName] copy];
}

- (UIImage *)savedWallpaper
{
    return [UIImage imageWithContentsOfFile:[self wallpaperPath]];
}

- (void)reloadWallpaper
{
    UIImage *wallpaper = [self savedWallpaper];
    BOOL hasWallpaper = wallpaper != nil;
    self.customWallpaperActive = hasWallpaper;
    [self.mainView refreshWallpaperPanelAppearance];
    self.backgroundImageView.image = wallpaper ?: self.defaultBackgroundImage;
    self.backgroundImageView.contentMode = hasWallpaper ? UIViewContentModeScaleAspectFit : UIViewContentModeScaleAspectFill;
    self.backgroundImageView.clipsToBounds = hasWallpaper;
    // Custom photos fit the visible view. Keep the theme's original overscan.
    self.backgroundTopConstraint.constant = hasWallpaper ? 0 : -100;
    self.backgroundBottomConstraint.constant = hasWallpaper ? 0 : 100;
    [self.view setNeedsLayout];
}

- (void)showWallpaperAlert:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"壁纸"
            message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self.topViewController presentViewController:alert animated:YES completion:nil];
    });
}

- (void)chooseWallpaper
{
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusDenied || status == PHAuthorizationStatusRestricted) {
        [self showWallpaperAlert:@"无法访问照片，请在系统设置中允许照片权限。"];
        return;
    }
    if (status == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus newStatus) {
            if (newStatus == PHAuthorizationStatusAuthorized || newStatus == PHAuthorizationStatusLimited) {
                dispatch_async(dispatch_get_main_queue(), ^{ [self chooseWallpaper]; });
            }
        }];
        return;
    }

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = NO;
    gWallpaperPickerDelegate = [[DOWallpaperPickerDelegate alloc] init];
    gWallpaperPickerDelegate.navigationController = self;
    picker.delegate = gWallpaperPickerDelegate;
    [self.topViewController presentViewController:picker animated:YES completion:nil];
}

- (void)resetWallpaper
{
    NSError *error = nil;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[self wallpaperPath]];
    if (exists && ![[NSFileManager defaultManager] removeItemAtPath:[self wallpaperPath] error:&error]) {
        [self showWallpaperAlert:@"无法恢复默认背景，请稍后重试。"];
        return;
    }
    [self reloadWallpaper];
}

- (void)setBackgroundDimmed:(BOOL)dimmed
{
    [UIView animateWithDuration:0.3 animations:^{
        self.backgroundImageView.alpha = dimmed ? 0.4 : 1;
    }];
    self.backgroundImageView.userInteractionEnabled = dimmed;
    self.backAction.hidden = !dimmed;
}

#pragma mark - Delegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
           animationControllerForOperation:(UINavigationControllerOperation)operation
                        fromViewController:(UIViewController *)fromVC
                          toViewController:(UIViewController *)toVC {
    
    
    if (fromVC.class == DOMainViewController.class || toVC.class == DOMainViewController.class)
        return [[DOModalTransitionScale alloc] initForwards: operation == UINavigationControllerOperationPush];
    return [[DOModalTransitionPush alloc] initForwards: operation == UINavigationControllerOperationPush];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [self setBackgroundDimmed:![viewController isKindOfClass:[DOMainViewController class]]];
    [self.backAction setIgnoreFrame:[self _frameForViewController:viewController]];
}

#pragma mark - Overrides

-(CGRect)_frameForViewController:(id)viewController
{
    CGRect orig = [super _frameForViewController: viewController];
    if ([[viewController class] isEqual: [DOMainViewController class]])
        return orig;
    
    orig.size.width = fmin(orig.size.width - UI_MODAL_PADDING * 2, UI_IPAD_MAX_WIDTH);
    orig.size.height *= [DOGlobalAppearance isSmallDevice] ? 0.8 : 0.7;
    orig.origin.x = (self.view.frame.size.width - orig.size.width) / 2;
    orig.origin.y = (self.view.frame.size.height - orig.size.height) / 2;

    return orig;

}


@end
