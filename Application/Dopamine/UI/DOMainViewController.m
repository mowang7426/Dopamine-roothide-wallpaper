//
//  DOMainViewController.m
//  Dopamine
//
//  Created by tomt000 on 08/01/2024.
//

#import "DOMainViewController.h"
#import "DOUIManager.h"
#import "DOEnvironmentManager.h"
#import "DOJailbreaker.h"
#import "DOGlobalAppearance.h"
#import "DOActionMenuButton.h"
#import "DOUpdateViewController.h"
#import "DOLogCrashViewController.h"
#import "DONavigationController.h"
#import "DOThemeManager.h"
#import <pthread.h>
#import <math.h>
#import <sys/sysctl.h>
#import <libjailbreak/libjailbreak.h>

static NSString * const DODashboardCardTransparencyDefaultsKey = @"DODashboardCardTransparencyPercent";

@interface DOCardOpacityViewController : UIViewController
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UILabel *accessibilityNote;
@property (nonatomic) CGFloat transparencyPercent;
@property (nonatomic, copy) void (^valueChanged)(CGFloat transparencyPercent);
@property (nonatomic, copy) void (^resetRequested)(void);
- (instancetype)initWithTransparencyPercent:(CGFloat)percent;
- (void)setTransparencyPercent:(CGFloat)percent;
- (void)setReduceTransparencyEnabled:(BOOL)enabled;
@end

@implementation DOCardOpacityViewController

- (instancetype)initWithTransparencyPercent:(CGFloat)percent
{
    if (self = [super init]) {
        _transparencyPercent = percent;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"卡片透明度";
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2];
    title.adjustsFontForContentSizeCategory = YES;

    UIButton *done = [UIButton buttonWithType:UIButtonTypeSystem];
    done.translatesAutoresizingMaskIntoConstraints = NO;
    [done setTitle:@"完成" forState:UIControlStateNormal];
    done.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    done.accessibilityHint = @"关闭卡片透明度设置";
    [done addTarget:self action:@selector(closeSettings) forControlEvents:UIControlEventTouchUpInside];

    UILabel *explanation = [[UILabel alloc] init];
    explanation.translatesAutoresizingMaskIntoConstraints = NO;
    explanation.text = @"滑块越大，卡片背景越透明。文字和图标颜色保持不变。";
    explanation.numberOfLines = 0;
    explanation.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    explanation.textColor = UIColor.secondaryLabelColor;
    explanation.adjustsFontForContentSizeCategory = YES;

    self.valueLabel = [[UILabel alloc] init];
    self.valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.valueLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.valueLabel.adjustsFontForContentSizeCategory = YES;

    self.slider = [[UISlider alloc] init];
    self.slider.translatesAutoresizingMaskIntoConstraints = NO;
    self.slider.minimumValue = 0;
    self.slider.maximumValue = 100;
    self.slider.continuous = YES;
    self.slider.accessibilityLabel = @"卡片背景透明度";
    self.slider.accessibilityHint = @"调整仪表盘卡片背景和边框的透明度，不会改变文字或图标";
    [self.slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self setTransparencyPercent:self.transparencyPercent];

    self.accessibilityNote = [[UILabel alloc] init];
    self.accessibilityNote.translatesAutoresizingMaskIntoConstraints = NO;
    self.accessibilityNote.numberOfLines = 0;
    self.accessibilityNote.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.accessibilityNote.textColor = UIColor.secondaryLabelColor;
    self.accessibilityNote.adjustsFontForContentSizeCategory = YES;

    UIButton *reset = [UIButton buttonWithType:UIButtonTypeSystem];
    reset.translatesAutoresizingMaskIntoConstraints = NO;
    [reset setTitle:@"恢复壁纸对应的默认样式" forState:UIControlStateNormal];
    reset.accessibilityHint = @"清除已保存的透明度，恢复当前壁纸类型的默认卡片外观";
    [reset addTarget:self action:@selector(resetSettings) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[explanation, self.valueLabel, self.slider, self.accessibilityNote, reset]];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 18;
    content.alignment = UIStackViewAlignmentFill;
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = NO;
    scroll.showsVerticalScrollIndicator = YES;
    [self.view addSubview:title];
    [self.view addSubview:done];
    [self.view addSubview:scroll];
    [scroll addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24],
        [title.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24],
        [done.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24],
        [done.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12],
        [content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:24],
        [content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-24],
        [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:12],
        [content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-12],
        [content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-48],
        [self.slider.heightAnchor constraintGreaterThanOrEqualToConstant:44]
    ]];
    [self updateAccessibilityState:UIAccessibilityIsReduceTransparencyEnabled()];
}

- (void)setTransparencyPercent:(CGFloat)percent
{
    _transparencyPercent = MIN(100.0, MAX(0.0, percent));
    if (!self.isViewLoaded) return;
    self.slider.value = _transparencyPercent;
    BOOL reduceTransparency = UIAccessibilityIsReduceTransparencyEnabled();
    NSString *value = reduceTransparency
        ? [NSString stringWithFormat:@"%.0f%% 透明（当前由系统设置覆盖）", round(_transparencyPercent)]
        : [NSString stringWithFormat:@"%.0f%% 透明", round(_transparencyPercent)];
    self.valueLabel.text = value;
    self.slider.accessibilityValue = value;
}

- (void)setReduceTransparencyEnabled:(BOOL)enabled
{
    if (self.isViewLoaded) [self updateAccessibilityState:enabled];
}

- (void)updateAccessibilityState:(BOOL)enabled
{
    self.slider.enabled = !enabled;
    NSString *value = enabled
        ? [NSString stringWithFormat:@"%.0f%% 透明（当前由系统设置覆盖）", round(self.transparencyPercent)]
        : [NSString stringWithFormat:@"%.0f%% 透明", round(self.transparencyPercent)];
    self.valueLabel.text = value;
    self.slider.accessibilityValue = value;
    self.accessibilityNote.text = enabled
        ? @"系统“降低透明度”已开启；为符合辅助功能设置，卡片以不透明样式显示，滑块暂不可用。"
        : @"0% 为不透明卡片背景，100% 为完全透明。设置会自动保存并在下次启动时恢复。";
}

- (void)sliderChanged:(UISlider *)sender
{
    CGFloat percent = roundf(sender.value);
    sender.value = percent;
    [self setTransparencyPercent:percent];
    if (self.valueChanged) self.valueChanged(percent);
}

- (void)resetSettings
{
    if (self.resetRequested) self.resetRequested();
}

- (void)closeSettings
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@interface DOMainViewController ()

@property DOActionMenuView *actionMenuView;
@property DOJailbreakButton *jailbreakBtn;
@property NSArray<NSLayoutConstraint *> *jailbreakButtonConstraints;
@property DOActionMenuButton *updateButton;
@property(nonatomic) BOOL hideStatusBar;
@property(nonatomic) BOOL hideHomeIndicator;
@property(nonatomic, strong) NSMutableArray<UIView *> *dashboardPanels;
@property(nonatomic, strong) NSMutableArray<UIView *> *dashboardHighlightFills;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *dashboardHighlightBaseAlphas;
@property(nonatomic, weak) DOCardOpacityViewController *opacitySettingsController;
@property(nonatomic, strong) UIScrollView *dashboardScroll;
@property(nonatomic, strong) UIView *dashboardTabBar;
@property(nonatomic, strong) UIStackView *dashboardFooter;
@property(nonatomic, strong) UILabel *supportLabel;
@property(nonatomic, strong) UILabel *systemVersionLabel;
@property(nonatomic, strong) UILabel *versionLabel;
@property(nonatomic, strong) UILabel *uptimeLabel;
@property(nonatomic, strong) UIButton *respringShortcut;
@property(nonatomic, strong) UIButton *userspaceShortcut;
@property(nonatomic, strong) NSTimer *uptimeTimer;


@end

@implementation DOMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupStack];
    [self refreshWallpaperPanelAppearance];
}

// Dashboard UI only: environment/exploit execution remains in startJailbreak below.
- (UIColor *)dashboardInk
{
    return [UIColor colorWithRed:0.12 green:0.23 blue:0.18 alpha:1.0];
}

- (UIView *)dashboardPanelWithRadius:(CGFloat)radius
{
    UIView *panel = [[UIView alloc] init];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.layer.cornerRadius = radius;
    panel.layer.cornerCurve = kCACornerCurveContinuous;
    panel.layer.masksToBounds = YES;
    panel.layer.borderWidth = 0.5;
    [self.dashboardPanels addObject:panel];
    return panel;
}

- (UILabel *)dashboardLabel:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight
{
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.textColor = [self dashboardInk];
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.numberOfLines = 0;
    return label;
}

- (UIStackView *)dashboardStack:(NSArray<UIView *> *)views spacing:(CGFloat)spacing
{
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = spacing;
    return stack;
}

- (void)pinDashboardContent:(UIView *)content inPanel:(UIView *)panel padding:(CGFloat)padding
{
    [panel addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:padding],
        [content.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-padding],
        [content.topAnchor constraintEqualToAnchor:panel.topAnchor constant:padding],
        [content.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-padding]
    ]];
}

- (void)addDashboardHighlightFill:(UIView *)view baseAlpha:(CGFloat)alpha
{
    [self.dashboardHighlightFills addObject:view];
    [self.dashboardHighlightBaseAlphas addObject:@(alpha)];
}

- (CGFloat)defaultCardTransparencyPercent
{
    // Match the existing dashboard appearance: 34% fill for custom photos,
    // 78% fill for the built-in theme.
    return [(DONavigationController *)self.navigationController customWallpaperActive] ? 66.0 : 22.0;
}

- (CGFloat)cardTransparencyPercent
{
    id saved = [NSUserDefaults.standardUserDefaults objectForKey:DODashboardCardTransparencyDefaultsKey];
    return saved ? MIN(100.0, MAX(0.0, [saved doubleValue])) : [self defaultCardTransparencyPercent];
}

- (void)setCardTransparencyPercent:(CGFloat)percent
{
    CGFloat value = round(MIN(100.0, MAX(0.0, percent)));
    [NSUserDefaults.standardUserDefaults setDouble:value forKey:DODashboardCardTransparencyDefaultsKey];
    [self refreshWallpaperPanelAppearance];
    [self.opacitySettingsController setTransparencyPercent:value];
}

- (void)resetCardTransparency
{
    [NSUserDefaults.standardUserDefaults removeObjectForKey:DODashboardCardTransparencyDefaultsKey];
    [self refreshWallpaperPanelAppearance];
    [self.opacitySettingsController setTransparencyPercent:[self defaultCardTransparencyPercent]];
}

- (void)presentCardOpacitySettings
{
    DOCardOpacityViewController *controller = [[DOCardOpacityViewController alloc] initWithTransparencyPercent:[self cardTransparencyPercent]];
    controller.title = @"卡片透明度";
    controller.preferredContentSize = CGSizeMake(460, 340);
    controller.modalPresentationStyle = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad
        ? UIModalPresentationFormSheet : UIModalPresentationPageSheet;
    __weak typeof(self) weakSelf = self;
    controller.valueChanged = ^(CGFloat percent) {
        [weakSelf setCardTransparencyPercent:percent];
    };
    controller.resetRequested = ^{
        [weakSelf resetCardTransparency];
    };
    self.opacitySettingsController = controller;
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)refreshWallpaperPanelAppearance
{
    BOOL wallpaper = [(DONavigationController *)self.navigationController customWallpaperActive];
    BOOL reduceTransparency = UIAccessibilityIsReduceTransparencyEnabled();
    CGFloat defaultPercent = [self defaultCardTransparencyPercent];
    CGFloat transparency = reduceTransparency ? 0.0 : [self cardTransparencyPercent];
    CGFloat relativeFill = (100.0 - transparency) / MAX(1.0, 100.0 - defaultPercent);
    CGFloat fillAlpha = wallpaper ? 0.34 : 0.78;
    CGFloat edgeAlpha = MIN(1.0, 0.32 * relativeFill);

    // Change only card fill and edge colors; never apply alpha to a container
    // holding labels, icons, or controls.
    for (UIView *panel in self.dashboardPanels) {
        panel.backgroundColor = [UIColor colorWithWhite:1 alpha:reduceTransparency ? 1.0 : MIN(1.0, fillAlpha * relativeFill)];
        panel.layer.borderColor = [UIColor colorWithWhite:1 alpha:reduceTransparency ? 0.32 : edgeAlpha].CGColor;
    }
    for (NSUInteger index = 0; index < self.dashboardHighlightFills.count; index++) {
        UIView *fill = self.dashboardHighlightFills[index];
        CGFloat baseAlpha = self.dashboardHighlightBaseAlphas[index].doubleValue;
        fill.backgroundColor = [UIColor colorWithWhite:1 alpha:reduceTransparency ? 1.0 : MIN(1.0, baseAlpha * relativeFill)];
    }
    if (self.updateButton) {
        CGFloat updateAlpha = reduceTransparency ? 1.0 : MIN(0.90, 0.90 * relativeFill);
        self.updateButton.backgroundColor = [UIColor colorWithWhite:1 alpha:updateAlpha];
    }
    if (!self.jailbreakBtn.didExpand) {
        self.jailbreakBtn.backgroundColor = [UIColor colorWithWhite:1 alpha:reduceTransparency ? 1.0 : MIN(1.0, fillAlpha * relativeFill)];
        self.jailbreakBtn.layer.borderColor = [UIColor colorWithWhite:1 alpha:reduceTransparency ? 0.32 : edgeAlpha].CGColor;
    }
    [self.opacitySettingsController setReduceTransparencyEnabled:reduceTransparency];
    [self setNeedsStatusBarAppearanceUpdate];
    [self.navigationController setNeedsStatusBarAppearanceUpdate];
}

- (UIStackView *)dashboardMetric:(NSString *)title value:(UILabel *)value
{
    UILabel *caption = [self dashboardLabel:title size:12 weight:UIFontWeightMedium];
    caption.textColor = [[self dashboardInk] colorWithAlphaComponent:0.72];
    return [self dashboardStack:@[caption, value] spacing:5];
}

- (UIButton *)dashboardShortcut:(NSString *)title subtitle:(NSString *)subtitle symbol:(NSString *)symbol action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = 24;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.masksToBounds = YES;
    button.layer.borderWidth = 0.5;
    [self.dashboardPanels addObject:button];
    UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
    config.title = title;
    config.subtitle = subtitle;
    config.image = [UIImage systemImageNamed:symbol withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:25 weight:UIImageSymbolWeightRegular]];
    config.imagePlacement = NSDirectionalRectEdgeTop;
    config.imagePadding = 8;
    config.titlePadding = 5;
    config.titleAlignment = UIButtonConfigurationTitleAlignmentLeading;
    config.contentInsets = NSDirectionalEdgeInsetsMake(14, 14, 14, 10);
    config.baseForegroundColor = [self dashboardInk];
    config.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attributes) {
        NSMutableDictionary *result = [attributes mutableCopy];
        result[NSFontAttributeName] = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        return result;
    };
    config.subtitleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attributes) {
        NSMutableDictionary *result = [attributes mutableCopy];
        result[NSFontAttributeName] = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        return result;
    };
    button.configuration = config;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:100].active = YES;
    return button;
}

- (UIButton *)dashboardTab:(NSString *)title symbol:(NSString *)symbol tag:(NSInteger)tag
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
    config.title = title;
    config.image = [UIImage systemImageNamed:symbol withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightRegular]];
    config.imagePlacement = NSDirectionalRectEdgeTop;
    config.imagePadding = 5;
    config.baseForegroundColor = [self dashboardInk];
    config.contentInsets = NSDirectionalEdgeInsetsMake(8, 4, 8, 4);
    button.configuration = config;
    button.layer.cornerRadius = 26;
    button.tag = tag;
    button.accessibilityLabel = title;
    if (tag == 0) {
        button.backgroundColor = [UIColor colorWithWhite:1 alpha:0.32];
        [self addDashboardHighlightFill:button baseAlpha:0.32];
        button.accessibilityTraits |= UIAccessibilityTraitSelected;
    }
    [button addTarget:self action:@selector(dashboardTabPressed:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)setupStack
{
    self.view.backgroundColor = UIColor.clearColor;
    self.dashboardPanels = [NSMutableArray array];
    self.dashboardHighlightFills = [NSMutableArray array];
    self.dashboardHighlightBaseAlphas = [NSMutableArray array];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    UILayoutGuide *column = [[UILayoutGuide alloc] init];
    [self.view addLayoutGuide:column];
    NSLayoutConstraint *preferredWidth = [column.widthAnchor constraintEqualToAnchor:safe.widthAnchor constant:-32];
    preferredWidth.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        preferredWidth,
        [column.widthAnchor constraintLessThanOrEqualToConstant:620],
        [column.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [column.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [column.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor]
    ]];

    // Keep bottom actions outside the scroll view on short devices and in landscape.
    self.dashboardTabBar = [self dashboardPanelWithRadius:30];
    [self.view addSubview:self.dashboardTabBar];
    UIStackView *tabs = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self dashboardTab:@"首页" symbol:@"house" tag:0],
        [self dashboardTab:@"设置" symbol:@"slider.horizontal.3" tag:1],
        [self dashboardTab:@"关于" symbol:@"info.circle" tag:2]
    ]];
    tabs.translatesAutoresizingMaskIntoConstraints = NO;
    tabs.distribution = UIStackViewDistributionFillEqually;
    [self pinDashboardContent:tabs inPanel:self.dashboardTabBar padding:4];
    [NSLayoutConstraint activateConstraints:@[
        [self.dashboardTabBar.leadingAnchor constraintEqualToAnchor:column.leadingAnchor],
        [self.dashboardTabBar.trailingAnchor constraintEqualToAnchor:column.trailingAnchor],
        [self.dashboardTabBar.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-6],
        [self.dashboardTabBar.heightAnchor constraintEqualToConstant:66]
    ]];

    UIView *statusPlaceholder = [[UIView alloc] init];
    statusPlaceholder.translatesAutoresizingMaskIntoConstraints = NO;
    [statusPlaceholder.heightAnchor constraintEqualToConstant:68].active = YES;
    self.dashboardFooter = [self dashboardStack:@[statusPlaceholder] spacing:8];
    [self.view addSubview:self.dashboardFooter];
    [NSLayoutConstraint activateConstraints:@[
        [self.dashboardFooter.leadingAnchor constraintEqualToAnchor:column.leadingAnchor],
        [self.dashboardFooter.trailingAnchor constraintEqualToAnchor:column.trailingAnchor],
        [self.dashboardFooter.bottomAnchor constraintEqualToAnchor:self.dashboardTabBar.topAnchor constant:-12]
    ]];

    self.dashboardScroll = [[UIScrollView alloc] init];
    self.dashboardScroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.dashboardScroll.alwaysBounceVertical = YES;
    self.dashboardScroll.showsVerticalScrollIndicator = NO;
    self.dashboardScroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.dashboardScroll];
    [NSLayoutConstraint activateConstraints:@[
        [self.dashboardScroll.leadingAnchor constraintEqualToAnchor:column.leadingAnchor],
        [self.dashboardScroll.trailingAnchor constraintEqualToAnchor:column.trailingAnchor],
        [self.dashboardScroll.topAnchor constraintEqualToAnchor:safe.topAnchor constant:10],
        [self.dashboardScroll.bottomAnchor constraintEqualToAnchor:self.dashboardFooter.topAnchor constant:-12]
    ]];
    UIStackView *content = [self dashboardStack:@[] spacing:14];
    [self.dashboardScroll addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:self.dashboardScroll.contentLayoutGuide.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:self.dashboardScroll.contentLayoutGuide.trailingAnchor],
        [content.topAnchor constraintEqualToAnchor:self.dashboardScroll.contentLayoutGuide.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:self.dashboardScroll.contentLayoutGuide.bottomAnchor constant:-8],
        [content.widthAnchor constraintEqualToAnchor:self.dashboardScroll.frameLayoutGuide.widthAnchor]
    ]];

    UIView *header = [self dashboardPanelWithRadius:25];
    [content addArrangedSubview:header];
    [header.heightAnchor constraintGreaterThanOrEqualToConstant:58].active = YES;
    UILabel *badge = [self dashboardLabel:@"D" size:21 weight:UIFontWeightBold];
    badge.textAlignment = NSTextAlignmentCenter;
    badge.backgroundColor = [UIColor colorWithWhite:1 alpha:0.32];
    [self addDashboardHighlightFill:badge baseAlpha:0.32];
    badge.layer.cornerRadius = 12;
    badge.layer.masksToBounds = YES;
    [badge.widthAnchor constraintEqualToConstant:34].active = YES;
    [badge.heightAnchor constraintEqualToConstant:34].active = YES;
    UILabel *name = [self dashboardLabel:@"多巴胺" size:24 weight:UIFontWeightBold];
    name.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle2] scaledFontForFont:name.font maximumPointSize:30];
    name.adjustsFontForContentSizeCategory = YES;
    // The shared label helper permits wrapping; the brand must stay on one line.
    name.numberOfLines = 1;
    name.adjustsFontSizeToFitWidth = YES;
    name.minimumScaleFactor = 0.65;
    name.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    [name setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [name setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh + 1 forAxis:UILayoutConstraintAxisHorizontal];
    [badge setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *brand = [[UIStackView alloc] initWithArrangedSubviews:@[badge, name]];
    brand.translatesAutoresizingMaskIntoConstraints = NO;
    brand.axis = UILayoutConstraintAxisHorizontal;
    brand.alignment = UIStackViewAlignmentCenter;
    brand.spacing = 10;
    [header addSubview:brand];
    // Prefer a centered brand, but let it shift before compressing on narrow screens.
    NSLayoutConstraint *brandCenter = [brand.centerXAnchor constraintEqualToAnchor:header.centerXAnchor];
    brandCenter.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        brandCenter,
        [brand.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [brand.leadingAnchor constraintGreaterThanOrEqualToAnchor:header.leadingAnchor constant:12],
        [brand.topAnchor constraintGreaterThanOrEqualToAnchor:header.topAnchor constant:10],
        [brand.bottomAnchor constraintLessThanOrEqualToAnchor:header.bottomAnchor constant:-10]
    ]];
    __weak typeof(self) weakSelf = self;
    UIButton *wallpaperMenu = [UIButton buttonWithType:UIButtonTypeSystem];
    wallpaperMenu.translatesAutoresizingMaskIntoConstraints = NO;
    UIButtonConfiguration *wallpaperConfiguration = [UIButtonConfiguration plainButtonConfiguration];
    wallpaperConfiguration.image = [UIImage systemImageNamed:@"photo.on.rectangle" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15]];
    wallpaperConfiguration.title = @"壁纸";
    wallpaperConfiguration.imagePlacement = NSDirectionalRectEdgeTop;
    wallpaperConfiguration.imagePadding = 2;
    wallpaperConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(2, 0, 2, 0);
    wallpaperConfiguration.baseForegroundColor = [self dashboardInk];
    wallpaperConfiguration.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attributes) {
        NSMutableDictionary *result = [attributes mutableCopy];
        result[NSFontAttributeName] = [UIFont systemFontOfSize:9 weight:UIFontWeightMedium];
        return result;
    };
    wallpaperMenu.configuration = wallpaperConfiguration;
    wallpaperMenu.accessibilityLabel = @"壁纸设置";
    wallpaperMenu.accessibilityHint = @"选择原比例壁纸、恢复默认背景或调整卡片透明度";
    wallpaperMenu.showsMenuAsPrimaryAction = YES;
    wallpaperMenu.menu = [UIMenu menuWithTitle:@"壁纸 · 原比例显示" children:@[
        [UIAction actionWithTitle:@"卡片透明度…" image:[UIImage systemImageNamed:@"slider.horizontal.3"] identifier:nil handler:^(__kindof UIAction *action) {
            [weakSelf presentCardOpacitySettings];
        }],
        [UIAction actionWithTitle:@"选择壁纸" image:[UIImage systemImageNamed:@"photo"] identifier:nil handler:^(__kindof UIAction *action) {
            [(DONavigationController *)weakSelf.navigationController chooseWallpaper];
        }],
        [UIAction actionWithTitle:@"恢复默认背景" image:[UIImage systemImageNamed:@"arrow.counterclockwise"] identifier:nil handler:^(__kindof UIAction *action) {
            [(DONavigationController *)weakSelf.navigationController resetWallpaper];
        }]
    ]];
    [header addSubview:wallpaperMenu];
    [NSLayoutConstraint activateConstraints:@[
        [brand.trailingAnchor constraintLessThanOrEqualToAnchor:wallpaperMenu.leadingAnchor constant:-8],
        [wallpaperMenu.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-2],
        [wallpaperMenu.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [wallpaperMenu.widthAnchor constraintEqualToConstant:44],
        [wallpaperMenu.heightAnchor constraintEqualToConstant:44]
    ]];

    UIView *devicePanel = [self dashboardPanelWithRadius:28];
    [content addArrangedSubview:devicePanel];
    UILabel *section = [self dashboardLabel:@"设备信息" size:13 weight:UIFontWeightSemibold];
    section.accessibilityTraits |= UIAccessibilityTraitHeader;
    UIView *innerCard = [self dashboardPanelWithRadius:23];
    self.supportLabel = [self dashboardLabel:@"" size:14 weight:UIFontWeightSemibold];
    UILabel *authors = [self dashboardLabel:@"项目作者：opa334、évelyne (ElleKit)" size:13 weight:UIFontWeightSemibold];
    self.systemVersionLabel = [self dashboardLabel:@"" size:14 weight:UIFontWeightSemibold];
    self.versionLabel = [self dashboardLabel:@"" size:14 weight:UIFontWeightSemibold];
    self.uptimeLabel = [self dashboardLabel:@"" size:14 weight:UIFontWeightSemibold];
    self.uptimeLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightSemibold];
    NSString *compileString = [NSString stringWithFormat:@"%s %s", __DATE__, __TIME__];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"MMM d yyyy HH:mm:ss";
    NSDate *compileDate = [formatter dateFromString:compileString];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    UILabel *build = [self dashboardLabel:compileDate ? [formatter stringFromDate:compileDate] : compileString size:13 weight:UIFontWeightSemibold];
    UIStackView *systemRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self dashboardMetric:@"系统版本" value:self.systemVersionLabel],
        [self dashboardMetric:@"越狱版本" value:self.versionLabel]
    ]];
    systemRow.distribution = UIStackViewDistributionFillEqually;
    systemRow.spacing = 12;
    UIStackView *timeRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self dashboardMetric:@"编译时间 · 构建机" value:build],
        [self dashboardMetric:@"开机时长" value:self.uptimeLabel]
    ]];
    timeRow.distribution = UIStackViewDistributionFillEqually;
    timeRow.spacing = 12;
    UIView *separator = [[UIView alloc] init];
    separator.backgroundColor = [[self dashboardInk] colorWithAlphaComponent:0.12];
    [separator.heightAnchor constraintEqualToConstant:0.5].active = YES;
    UILabel *notice = [self dashboardLabel:@"如有问题，请使用官方版本复现后再报告。" size:10.5 weight:UIFontWeightMedium];
    notice.textAlignment = NSTextAlignmentCenter;
    UIStackView *details = [self dashboardStack:@[self.supportLabel, authors, systemRow, timeRow, separator, notice] spacing:13];
    [self pinDashboardContent:details inPanel:innerCard padding:15];
    UILabel *rootHide = [self dashboardLabel:@"RootHide" size:12 weight:UIFontWeightSemibold];
    rootHide.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3];
    [self addDashboardHighlightFill:rootHide baseAlpha:0.3];
    rootHide.textAlignment = NSTextAlignmentCenter;
    rootHide.layer.cornerRadius = 9;
    rootHide.layer.masksToBounds = YES;
    [rootHide.widthAnchor constraintEqualToConstant:86].active = YES;
    [rootHide.heightAnchor constraintEqualToConstant:26].active = YES;
    UIView *badgeRow = [[UIView alloc] init];
    badgeRow.translatesAutoresizingMaskIntoConstraints = NO;
    [badgeRow addSubview:rootHide];
    [NSLayoutConstraint activateConstraints:@[
        [rootHide.leadingAnchor constraintEqualToAnchor:badgeRow.leadingAnchor],
        [rootHide.topAnchor constraintEqualToAnchor:badgeRow.topAnchor],
        [rootHide.bottomAnchor constraintEqualToAnchor:badgeRow.bottomAnchor]
    ]];
    UIStackView *deviceContents = [self dashboardStack:@[section, innerCard, badgeRow] spacing:12];
    [self pinDashboardContent:deviceContents inPanel:devicePanel padding:16];

    self.respringShortcut = [self dashboardShortcut:@"重启 SpringBoard" subtitle:@"刷新主屏界面" symbol:@"arrow.clockwise" action:@selector(confirmDashboardRespring)];
    self.userspaceShortcut = [self dashboardShortcut:@"重启用户空间" subtitle:@"重新加载越狱环境" symbol:@"arrow.clockwise.circle" action:@selector(confirmDashboardUserspace)];
    UIStackView *shortcuts = [[UIStackView alloc] initWithArrangedSubviews:@[self.respringShortcut, self.userspaceShortcut]];
    shortcuts.distribution = UIStackViewDistributionFillEqually;
    shortcuts.spacing = 12;
    [content addArrangedSubview:shortcuts];

    // Reuse the real jailbreak control, its mutex, package picker, log views and action.
    self.jailbreakBtn = [[DOJailbreakButton alloc] initWithAction:[UIAction actionWithTitle:[self jailbreakButtonTitle] image:[UIImage systemImageNamed:@"lock.open"] identifier:@"jailbreak" handler:^(__kindof UIAction *action) {
        [weakSelf beginDashboardJailbreak];
    }]];
    self.jailbreakBtn.layer.cornerRadius = 26;
    self.jailbreakBtn.layer.borderWidth = 0.5;
    UIButtonConfiguration *statusConfig = self.jailbreakBtn.button.configuration;
    statusConfig.baseForegroundColor = [self dashboardInk];
    statusConfig.imagePadding = 12;
    self.jailbreakBtn.button.configuration = statusConfig;
    [self.view addSubview:self.jailbreakBtn];
    self.jailbreakButtonConstraints = @[
        [self.jailbreakBtn.leadingAnchor constraintEqualToAnchor:statusPlaceholder.leadingAnchor],
        [self.jailbreakBtn.trailingAnchor constraintEqualToAnchor:statusPlaceholder.trailingAnchor],
        [self.jailbreakBtn.topAnchor constraintEqualToAnchor:statusPlaceholder.topAnchor],
        [self.jailbreakBtn.bottomAnchor constraintEqualToAnchor:statusPlaceholder.bottomAnchor]
    ];
    [NSLayoutConstraint activateConstraints:self.jailbreakButtonConstraints];
    [self refreshDashboardValues];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(dashboardNotification:) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(dashboardNotification:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(dashboardNotification:) name:UIApplicationDidBecomeActiveNotification object:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        BOOL environmentUpdate = [[DOUIManager sharedInstance] environmentUpdateAvailable];
        BOOL update = environmentUpdate || [[DOUIManager sharedInstance] isUpdateAvailable];
        if (update) dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf setupUpdateAvailable:environmentUpdate]; });
    });
}

- (void)dashboardNotification:(NSNotification *)notification
{
    if ([notification.name isEqualToString:UIAccessibilityReduceTransparencyStatusDidChangeNotification]) {
        [self refreshWallpaperPanelAppearance];
    } else if ([notification.name isEqualToString:UIApplicationDidEnterBackgroundNotification]) {
        [self stopDashboardTimer];
    } else if ([notification.name isEqualToString:UIApplicationDidBecomeActiveNotification]) {
        [self startDashboardTimer];
    }
}

- (void)refreshDashboardValues
{
    DOEnvironmentManager *environment = [DOEnvironmentManager sharedManager];
    self.supportLabel.text = [environment versionSupportString];
    self.systemVersionLabel.text = [environment systemVersion] ?: UIDevice.currentDevice.systemVersion;
    NSString *baseVersion = [environment jailbrokenVersion];
    NSString *rootVersion = [[environment jailbrokenVersionRootHide] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.versionLabel.text = baseVersion.length && rootVersion.length ? [NSString stringWithFormat:@"%@-%@", baseVersion, rootVersion] : [environment appVersion];
    [self updateDashboardUptime];
    BOOL jailbroken = [environment isJailbroken];
    self.respringShortcut.enabled = jailbroken;
    self.userspaceShortcut.enabled = jailbroken;
    if (!self.jailbreakBtn.didExpand) {
        [self.jailbreakBtn.button setTitle:[self jailbreakButtonTitle] forState:UIControlStateNormal];
        UIImage *image = [UIImage systemImageNamed:[environment isSupported] ? @"lock.open" : @"lock.slash"];
        [self.jailbreakBtn.button setImage:image forState:UIControlStateNormal];
        self.jailbreakBtn.enabled = !jailbroken && ![environment isJailbrokenWithOtherJailbreak] && [environment isSupported];
        // A disabled status is still important readable information.
        self.jailbreakBtn.alpha = 1.0;
    }
}

- (void)updateDashboardUptime
{
    unsigned long long seconds = (unsigned long long)MAX(0, NSProcessInfo.processInfo.systemUptime);
    self.uptimeLabel.text = [NSString stringWithFormat:@"%llu 天 %02llu:%02llu:%02llu", seconds / 86400, (seconds / 3600) % 24, (seconds / 60) % 60, seconds % 60];
}

- (void)startDashboardTimer
{
    [self stopDashboardTimer];
    if (!self.viewIfLoaded.window || self.navigationController.topViewController != self || self.jailbreakBtn.didExpand || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    [self updateDashboardUptime];
    __weak typeof(self) weakSelf = self;
    self.uptimeTimer = [NSTimer timerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
        [weakSelf updateDashboardUptime];
    }];
    self.uptimeTimer.tolerance = 0.2;
    [NSRunLoop.mainRunLoop addTimer:self.uptimeTimer forMode:NSRunLoopCommonModes];
}

- (void)stopDashboardTimer
{
    [self.uptimeTimer invalidate];
    self.uptimeTimer = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self startDashboardTimer];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self stopDashboardTimer];
    [super viewWillDisappear:animated];
}

- (void)dealloc
{
    [_uptimeTimer invalidate];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)dashboardTabPressed:(UIButton *)sender
{
    if (self.jailbreakBtn.didExpand || self.navigationController.topViewController != self) return;
    if (sender.tag == 0) {
        [self.dashboardScroll setContentOffset:CGPointZero animated:YES];
    } else {
        // Preserve the existing modal push/back transition and original controllers.
        UIViewController *destination = sender.tag == 1 ? [[DOSettingsController alloc] init] : [[DOCreditsViewController alloc] init];
        [self.navigationController pushViewController:destination animated:YES];
    }
}

- (void)confirmDashboardRespring
{
    [self confirmDashboardRestart:NO];
}

- (void)confirmDashboardUserspace
{
    [self confirmDashboardRestart:YES];
}

- (void)confirmDashboardRestart:(BOOL)userspace
{
    if (![[DOEnvironmentManager sharedManager] isJailbroken] || self.jailbreakBtn.didExpand || self.presentedViewController) return;
    NSString *title = userspace ? @"重启用户空间" : @"重启 SpringBoard";
    NSString *message = userspace ? @"将重新加载用户空间与越狱环境，当前应用会关闭。是否继续？" : @"将刷新主屏界面，当前应用会关闭。是否继续？";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"重新启动" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        if (![[DOEnvironmentManager sharedManager] isJailbroken]) return;
        [weakSelf fadeToBlack:^{
            if (userspace) [[DOEnvironmentManager sharedManager] rebootUserspace];
            else [[DOEnvironmentManager sharedManager] respring];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)beginDashboardJailbreak
{
    if (self.jailbreakBtn.didExpand || !self.jailbreakBtn.enabled) return;
    if (otherJailbreakActived(false)) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:DOLocalizedString(@"Error") message:DOLocalizedString(@"Your device currently has another jailbreak activated, please reboot device.") preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:DOLocalizedString(@"Button_Close") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    [self stopDashboardTimer];
    self.dashboardScroll.userInteractionEnabled = NO;
    self.dashboardTabBar.userInteractionEnabled = NO;
    self.updateButton.userInteractionEnabled = NO;
    [self.view bringSubviewToFront:self.jailbreakBtn];
    [self.jailbreakBtn expandButton:self.jailbreakButtonConstraints];
    [UIView animateWithDuration:0.3 animations:^{
        self.dashboardScroll.alpha = 0;
        self.dashboardTabBar.alpha = 0;
        self.updateButton.alpha = 0;
    }];
    [self startJailbreak];
}

- (NSString *)jailbreakButtonTitle
{
    BOOL isJailbroken = [[DOEnvironmentManager sharedManager] isJailbroken];
    BOOL isSupported = [[DOEnvironmentManager sharedManager] isSupported];
    BOOL removeJailbreakEnabled = [[DOPreferenceManager sharedManager] boolPreferenceValueForKey:@"removeJailbreakEnabled" fallback:NO];

    NSString *jailbreakButtonTitle = DOLocalizedString(@"Button_Jailbreak_Title");
    if (!isSupported)
        jailbreakButtonTitle = DOLocalizedString(@"Unsupported");
    else if (isJailbroken)
        jailbreakButtonTitle = DOLocalizedString(@"Status_Title_Jailbroken");
    else if (removeJailbreakEnabled)
        jailbreakButtonTitle = DOLocalizedString(@"Button_Remove_Jailbreak");
    
    return jailbreakButtonTitle;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self refreshDashboardValues];
    [self refreshWallpaperPanelAppearance];
}

- (void)startJailbreak
{
    DOJailbreaker *jailbreaker = [[DOJailbreaker alloc] init];

    [[DOUIManager sharedInstance] startLogCapture];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if ([jailbreaker contiguousMappingWorkaroundNeeded]) {
            
            cpu_subtype_t cpuFamily = 0;
            size_t cpuFamilySize = sizeof(cpuFamily);
            sysctlbyname("hw.cpufamily", &cpuFamily, &cpuFamilySize, NULL, 0);
            NSString *workaroundMessage = DOLocalizedString(@"Respring_Required_Message");
            if (cpuFamily == CPUFAMILY_ARM_TYPHOON) {
                workaroundMessage = [workaroundMessage stringByAppendingString:[NSString stringWithFormat:@"\n\n%@", DOLocalizedString(@"Respring_Required_Notice_A8")]];
            }

            UIAlertController *contiguousMappingWorkaroundAlertController = [UIAlertController alertControllerWithTitle:DOLocalizedString(@"Respring_Required") message:workaroundMessage preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:DOLocalizedString(@"Respring_Cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                exit(0);
            }];
            
            UIAlertAction *workaroundAction = [UIAlertAction actionWithTitle:DOLocalizedString(@"Apply_Workaround") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [jailbreaker applyContiguousMappingWorkaround];
            }];
            
            [contiguousMappingWorkaroundAlertController addAction:cancelAction];
            [contiguousMappingWorkaroundAlertController addAction:workaroundAction];
            contiguousMappingWorkaroundAlertController.preferredAction = workaroundAction;

            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentViewController:contiguousMappingWorkaroundAlertController animated:YES completion:nil];
            });
            return;
        }

        //We need to get the preconfig mutex to start the jailbreak (self.jailbreakBtn.canStartJailbreak)
        [self.jailbreakBtn lockMutex];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.hideHomeIndicator = YES;
        });

        NSError *error;
        BOOL didRemove = NO;
        BOOL showLogs = YES;
        [jailbreaker runWithError:&error didRemoveJailbreak:&didRemove showLogs:&showLogs];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error && showLogs) {
                [[DOUIManager sharedInstance] sendLog:[NSString stringWithFormat:@"Jailbreak failed with error: %@", error] debug:NO];
                [self.navigationController pushViewController:[[DOLogCrashViewController alloc] initWithTitle:[error localizedDescription]] animated:YES];
            }
            else if (error && !showLogs) {
                // Used when there is an error that is explainable in such detail that additional logs are not needed
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:DOLocalizedString(@"Log_Error") message:[error localizedDescription] preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *rebootAction = [UIAlertAction actionWithTitle:DOLocalizedString(@"Button_Reboot") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    exec_cmd_trusted(JBROOT_PATH("/sbin/reboot"), NULL);
                }];
                [alertController addAction:rebootAction];
                [self presentViewController:alertController animated:YES completion:nil];
            }
            else if (didRemove) {
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:DOLocalizedString(@"Removed_Jailbreak_Alert_Title") message:DOLocalizedString(@"Removed_Jailbreak_Alert_Message") preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *rebootAction = [UIAlertAction actionWithTitle:DOLocalizedString(@"Button_Close") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    exit(0);
                }];
                [alertController addAction:rebootAction];
                [self presentViewController:alertController animated:YES completion:nil];
            }
            else {
                // No errors
                [[DOUIManager sharedInstance] completeJailbreak];
                [self fadeToBlack: ^{
                    [jailbreaker finalize];
                }];
            }
        });
        [self.jailbreakBtn unlockMutex];
    });
}

-(void)setupUpdateAvailable:(BOOL)environmentUpdate
{
    if (self.jailbreakBtn.didExpand)
        return;

    NSString *title = environmentUpdate ? DOLocalizedString(@"Button_Update_Environment") : DOLocalizedString(@"Button_Update_Available");
    
    NSString *releaseFrom = [[DOUIManager sharedInstance] getLaunchedReleaseTag];
    NSString *releaseTo = [[DOUIManager sharedInstance] getLatestReleaseTag];

    if (environmentUpdate)
    {
/************************************* roothide specfic ***********************************/
        releaseFrom = [[DOEnvironmentManager sharedManager] jailbrokenVersionRootHide];
/************************************* roothide specfic ***********************************/
        releaseTo = [[DOUIManager sharedInstance] getLaunchedReleaseTag];
    }

    self.updateButton = [DOActionMenuButton buttonWithAction:[UIAction actionWithTitle:title image:[UIImage systemImageNamed:@"arrow.down.circle" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]] identifier:@"update-available" handler:^(__kindof UIAction * _Nonnull action) {
        [self.navigationController pushViewController:[[DOUpdateViewController alloc] initFromTag:releaseFrom toTag:releaseTo] animated:YES];
    }] chevron:NO];

    self.updateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.updateButton.layer.cornerRadius = 14;
    self.updateButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.90];
    UIButtonConfiguration *configuration = self.updateButton.configuration;
    configuration.baseForegroundColor = [self dashboardInk];
    self.updateButton.configuration = configuration;
    [self.dashboardFooter insertArrangedSubview:self.updateButton atIndex:0];
    [self.updateButton.heightAnchor constraintEqualToConstant:36].active = YES;
    [self refreshWallpaperPanelAppearance];

}

-(void)simulateJailbreak
{
    // Let's simulate a "jailbreak" using grand central dispatch

    DOUIManager *uiManager = [DOUIManager sharedInstance];

    static BOOL didFinish = NO; //not thread safe lol
    

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [uiManager completeJailbreak];
        [uiManager sendLog:@"Rebooting Userspace" debug: NO];
        didFinish = YES;
        [self fadeToBlack: ^{

        }];
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:0.2];
        [uiManager sendLog:@"Launching kexploitd" debug: NO];
        [NSThread sleepForTimeInterval:0.5];
        [uiManager sendLog:@"Launching oobPCI" debug: NO];
        [NSThread sleepForTimeInterval:0.15];
        [uiManager sendLog:@"Gaining r/w" debug: NO];
        [NSThread sleepForTimeInterval:0.8];
        [uiManager sendLog:@"Patchfinding" debug: NO];
        NSArray *types = @[@"AMFI", @"PAC", @"KTRR", @"KPP", @"PPL", @"KPF", @"APRR", @"AMCC", @"PAN", @"PXN", @"ASLR", @"OPA"]; //Ever heard of the legendary opa bypass
        while (true)
        {
            [NSThread sleepForTimeInterval:0.6 * rand() / RAND_MAX];
            if (didFinish) break;
            NSString *type = types[arc4random_uniform((uint32_t)types.count)];
            [uiManager sendLog:[NSString stringWithFormat:@"Bypassing %@", type] debug: NO];
        }
    });
}

- (void)fadeToBlack:(void (^)(void))completion
{
    static bool didFade = false;
    if (didFade)
        return;
    didFade = true;
    UIView *mainView = self.parentViewController.view;
    float deviceCornerRadius = [[[UIScreen mainScreen] valueForKey:@"_displayCornerRadius"] floatValue];

    mainView.layer.cornerRadius = deviceCornerRadius;
    mainView.layer.cornerCurve = kCACornerCurveContinuous;
    mainView.layer.masksToBounds = YES;
    
    self.hideStatusBar = YES;

    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:2.0 options: UIViewAnimationOptionCurveEaseInOut animations:^{
        mainView.transform = CGAffineTransformMakeScale(0.9, 0.9);
        mainView.alpha = 0.0;
    } completion:^(BOOL success) {
        completion();
    }];
}

#pragma mark - Action Menu Delegate

- (BOOL)actionMenuShowsChevronForAction:(UIAction *)action
{
    if ([action.identifier isEqualToString:@"settings"] || [action.identifier isEqualToString:@"credits"]) return YES;
    return NO;
}

- (BOOL)actionMenuActionIsEnabled:(UIAction *)action
{
    if ([action.identifier isEqualToString:@"respring"] || [action.identifier isEqualToString:@"reboot-userspace"]) {
        return [[DOEnvironmentManager sharedManager] isJailbroken];
    }
    return YES;
}

#pragma mark - Status Bar

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return [(DONavigationController *)self.navigationController customWallpaperActive] ? UIStatusBarStyleDarkContent : UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden
{
    return self.hideStatusBar;
}

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return self.hideHomeIndicator;
}

- (void)setHideStatusBar:(BOOL)hideStatusBar
{
    _hideStatusBar = hideStatusBar;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)setHideHomeIndicator:(BOOL)hideHomeIndicator
{
    _hideHomeIndicator = hideHomeIndicator;
    [self setNeedsUpdateOfHomeIndicatorAutoHidden];
}

@end
