//
//  GlobalAppearance.m
//  Dopamine
//
//  Created by Lars Fröder on 10.10.23.
//

#import "DOGlobalAppearance.h"
#import <CoreGraphics/CoreGraphics.h>
#import "DOThemeManager.h"

@implementation DOGlobalAppearance

+ (UIImageSymbolConfiguration *)smallIconImageConfiguration
{
    return [UIImageSymbolConfiguration configurationWithPointSize: 14 weight:UIImageSymbolWeightMedium];
}

+ (UIButtonConfiguration *)defaultButtonConfiguration
{
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.imagePadding = 10;
    configuration.baseForegroundColor = [UIColor whiteColor];
    configuration.titleLineBreakMode = NSLineBreakByClipping;

    // IN DARK MODE, APPLE JUST ADDS WHITE WHEN A BUTTON IS HIGHLIGHTED WHEN IT'S SET UP VIA UIButtonConfiguration
    // UNFORTUNATELY THEY FORGOT ABOUT THE POSSIBILITY ABOUT THERE BEING A WHITE BUTTON, SO THOSE JUST DON'T SHOW ANY HIGHLIGHT COLOR
    // HACKY WORKAROUND TO FIX FIX THIS MESS; SCREW APPLE
    configuration.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull textAttributes) {
        // Something makes me think the person that developed this API never actually used it...
        // OR ELSE WHERE IS MY BUTTON REFERENCE TO KNOW WHAT STATE I'M EVEN DEALING WITH???
        // THIS IS A SUPER HACKY WAY OF DETERMINING WHETHER THE BUTTON IS HIGHLIGHTED OR NOT
        // WHEN IT'S HIGHLIGHTED THE COLOR WILL BE IN UIExtendedSRGBColorSpace
        // WHEN NOT HIGHLIGHTED IT WILL BE IN UIExtendedGrayColorSpace
        // WHEN NOT IN DARK MODE IT WILL ALREADY BE WHAT WE WANT, JUST SKIP
        NSMutableDictionary<NSAttributedStringKey,id> *textAttributesM = textAttributes.mutableCopy;
        UIColor *foregroundColor = textAttributes[NSForegroundColorAttributeName];
        CGFloat alpha, white;
        [foregroundColor getWhite:&white alpha:&alpha];
        if ((int)white == 1 && (int)alpha == 1) {
            CGColorSpaceRef colorSpace = CGColorGetColorSpace(foregroundColor.CGColor);
            CGColorSpaceModel model = CGColorSpaceGetModel(colorSpace);
            if (model == kCGColorSpaceModelRGB) {
                textAttributesM[NSForegroundColorAttributeName] = [[UIColor whiteColor] colorWithAlphaComponent:0.75];
            }
        }
        // textAttributesM[NSFontAttributeName] = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        return textAttributesM;
    };
    configuration.imageColorTransformer = ^UIColor * _Nonnull(UIColor * _Nonnull color) {
        // Something makes me think the person that developed this API never actually used it...
        // OR ELSE WHERE IS MY BUTTON REFERENCE TO KNOW WHAT STATE I'M EVEN DEALING WITH???
        // THIS IS A SUPER HACKY WAY OF DETERMINING WHETHER THE BUTTON IS HIGHLIGHTED OR NOT
        // WHEN IT'S HIGHLIGHTED THE COLOR WILL BE IN UIExtendedSRGBColorSpace
        // WHEN NOT HIGHLIGHTED IT WILL BE IN UIExtendedGrayColorSpace
        // WHEN NOT IN DARK MODE IT WILL ALREADY BE WHAT WE WANT, JUST SKIP
        CGFloat alpha, white;
        [color getWhite:&white alpha:&alpha];
        if ((int)white == 1 && (int)alpha == 1) {
            CGColorSpaceRef colorSpace = CGColorGetColorSpace(color.CGColor);
            CGColorSpaceModel model = CGColorSpaceGetModel(colorSpace);
            if (model == kCGColorSpaceModelRGB) {
                return [color colorWithAlphaComponent:0.75];
            }
        }
        return color;
    };
    
    return configuration;
}

+ (UIButtonConfiguration *)defaultButtonConfigurationWithImagePadding:(CGFloat)imagePadding
{
    UIButtonConfiguration *configuration = [DOGlobalAppearance defaultButtonConfiguration];
    configuration.imagePadding = imagePadding;
    return configuration;
}

#pragma mark - Attributed Strings

+ (NSAttributedString*)mainSubtitleString:(NSString*)string
{
    return [[NSAttributedString alloc] initWithString:string attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:14 weight:UIFontWeightMedium],
        NSForegroundColorAttributeName: [UIColor whiteColor],
    }];
}

+ (NSAttributedString*)secondarySubtitleString:(NSString*)string
{
    return [[NSAttributedString alloc] initWithString:string attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:14 weight:UIFontWeightRegular],
        NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:0.60],
    }];
}

+ (BOOL)isHomeButtonDevice
{
   return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && [[UIApplication sharedApplication] keyWindow].safeAreaInsets.bottom == 0;
}

+ (BOOL)isRTL
{
    return [UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
}

+ (BOOL)isSmallDevice
{
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    return window.frame.size.height < SE_PHONE_SIZE_CONST + 50;
}

@end


@interface DOLightGlassView ()
@property (nonatomic) UIVisualEffectView *blurView;
@property (nonatomic) UIView *tintView;
@property (nonatomic) UIViewPropertyAnimator *blurAnimator;
@end

@implementation DOLightGlassView

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        self.accessibilityElementsHidden = YES;
        self.layer.cornerRadius = 20;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.clipsToBounds = YES;
        self.blurView = [[UIVisualEffectView alloc] initWithEffect:nil];
        self.tintView = [[UIView alloc] init];
        for (UIView *view in @[self.blurView, self.tintView]) {
            view.frame = self.bounds;
            view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self addSubview:view];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshGlass)
            name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshGlass)
            name:UIApplicationDidBecomeActiveNotification object:nil];
        [self refreshGlass];
    }
    return self;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self refreshGlass];
}

- (void)refreshGlass
{
    [self.blurAnimator stopAnimation:YES];
    self.blurAnimator = nil;
    self.blurView.effect = nil;
    BOOL reduced = UIAccessibilityIsReduceTransparencyEnabled();
    self.backgroundColor = reduced ? [[DOThemeManager menuColorWithAlpha:1.0] colorWithAlphaComponent:1.0] : UIColor.clearColor;
    self.tintView.backgroundColor = reduced ? UIColor.clearColor : [UIColor colorWithWhite:1 alpha:0.065];
    self.layer.borderWidth = 0.5;
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:reduced ? 0.16 : 0.32].CGColor;
    if (!reduced && self.window) {
        // Public API, partial light blur. Keep the effect view at alpha 1;
        // only the two rounded card bounds sample the wallpaper behind them.
        UIVisualEffectView *blurView = self.blurView;
        self.blurAnimator = [[UIViewPropertyAnimator alloc] initWithDuration:1 curve:UIViewAnimationCurveLinear animations:^{
            blurView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        }];
        [self.blurAnimator startAnimation];
        [self.blurAnimator pauseAnimation];
        self.blurAnimator.fractionComplete = 0.18;
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.blurAnimator stopAnimation:YES];
}
@end
