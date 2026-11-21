//
//  DOActionMenuButton.m
//  Dopamine
//
//  Created by tomt000 on 07/01/2024.
//

#import "DOActionMenuButton.h"
#import "DOGlobalAppearance.h"

@interface DOActionMenuButton () {
    UIView *_separator;
}

@property (nonatomic) UIImpactFeedbackGenerator *feedbackGenerator;
@property (nonatomic, copy) UIButtonConfiguration *standardConfiguration;
@property (nonatomic) UIImage *standardImage;

@end

@implementation DOActionMenuButton 

+(DOActionMenuButton*)buttonWithAction:(UIAction *)action chevron:(BOOL)chevron
{
    DOActionMenuButton *button = [DOActionMenuButton buttonWithConfiguration:[DOGlobalAppearance defaultButtonConfiguration] primaryAction:action];
    [button.titleLabel setAdjustsFontSizeToFitWidth:YES];
    [button setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];

    if ([DOGlobalAppearance isRTL])
        [button setContentHorizontalAlignment:UIControlContentHorizontalAlignmentRight];

    if (chevron)
    {
        UIImage *chevronImage = [UIImage systemImageNamed:@"chevron.right"];
        chevronImage = [chevronImage imageWithConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightRegular]];
        UIImageView *chevronView = [[UIImageView alloc] initWithImage:chevronImage];
        chevronView.translatesAutoresizingMaskIntoConstraints = NO;
        chevronView.tintColor = [UIColor colorWithWhite:1 alpha:0.6];
        [button addSubview:chevronView];
        [NSLayoutConstraint activateConstraints:@[
            [chevronView.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-10],
            [chevronView.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        ]];
    }

    button.feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [button addTarget:button action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];

    return button;
}

- (void)setLightGlassAppearance:(BOOL)lightGlassAppearance
{
    _lightGlassAppearance = lightGlassAppearance;
    if (!self.standardConfiguration) {
        self.standardConfiguration = [self.configuration copy];
        self.standardImage = self.currentImage;
    }
    UIButtonConfiguration *configuration = [self.standardConfiguration copy];
    // Settings can change the resting status title after initial construction.
    configuration.title = self.currentTitle;
    configuration.image = self.standardImage;
    if (lightGlassAppearance) {
        UIImage *symbol = [self.standardImage imageWithConfiguration:
            [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium]];
        if (symbol) {
            // Identical 24 pt icon slots keep all six Chinese labels aligned.
            UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(24, 24)];
            CGFloat scale = MIN(20.0 / symbol.size.width, 20.0 / symbol.size.height);
            CGSize size = CGSizeMake(symbol.size.width * scale, symbol.size.height * scale);
            configuration.image = [[renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
                [symbol drawInRect:CGRectMake((24 - size.width) / 2, (24 - size.height) / 2, size.width, size.height)];
            }] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        configuration.imagePadding = 12;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(0, 4, 0, 4);
        UIConfigurationTextAttributesTransformer original = configuration.titleTextAttributesTransformer;
        configuration.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *attributes) {
            NSMutableDictionary *result = [(original ? original(attributes) : attributes) mutableCopy];
            result[NSFontAttributeName] = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
            NSShadow *shadow = [[NSShadow alloc] init];
            shadow.shadowColor = [UIColor colorWithWhite:0 alpha:0.8];
            shadow.shadowOffset = CGSizeMake(0, 1);
            shadow.shadowBlurRadius = 3;
            result[NSShadowAttributeName] = shadow;
            return result;
        };
    }
    self.configuration = configuration;
    [self setBottomSeparator:self.bottomSeparator];
}

-(void)buttonPressed
{
    [self.feedbackGenerator impactOccurred];
}

-(void)setBottomSeparator:(BOOL)bottomSeparator
{
    _bottomSeparator = bottomSeparator;
    if (_separator)
        [_separator removeFromSuperview];
    if (bottomSeparator)
    {
        _separator = [[UIView alloc] init];
        _separator.backgroundColor = self.lightGlassAppearance ? [UIColor colorWithWhite:1 alpha:0.16] : [UIColor colorWithWhite:0.6 alpha:0.3];
        _separator.translatesAutoresizingMaskIntoConstraints = NO;
        _separator.layer.cornerRadius = 0.5;
        _separator.layer.masksToBounds = YES;
        [self addSubview:_separator];
        [NSLayoutConstraint activateConstraints:@[
            [_separator.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:self.lightGlassAppearance ? 40 : 10],
            [_separator.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
            [_separator.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [_separator.heightAnchor constraintEqualToConstant:self.lightGlassAppearance ? 0.5 : 1],
        ]];
    }
}

@end
