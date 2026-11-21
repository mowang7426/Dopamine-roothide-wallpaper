//
//  DOHeaderCell.m
//  Dopamine
//
//  Created by tomt000 on 26/01/2024.
//

#import "DOHeaderCell.h"

@implementation DOHeaderCell

- (id)initWithSpecifier:(PSSpecifier*)specifier
{
    if (self = [super init])
    {
        UILabel *titleLabel = [[UILabel alloc] init];
        [titleLabel setText:[specifier propertyForKey:@"title"]];
        [titleLabel setFont:[UIFont systemFontOfSize:17 weight:UIFontWeightMedium]];
        [titleLabel setTextColor:[UIColor whiteColor]];
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self.contentView addSubview:titleLabel];
        titleLabel.adjustsFontSizeToFitWidth = YES;
        titleLabel.minimumScaleFactor = 0.7;

        // Explicit navigation for dashboard destinations and nested settings alike.
        UIButton *backButton = [UIButton buttonWithType:UIButtonTypeSystem];
        backButton.translatesAutoresizingMaskIntoConstraints = NO;
        [backButton setTitle:@"返回" forState:UIControlStateNormal];
        [backButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        backButton.accessibilityHint = @"返回上一页；设置或关于首页返回主界面";
        [backButton addTarget:self action:@selector(returnToPreviousPage) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:backButton];

        [NSLayoutConstraint activateConstraints:@[
            [backButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
            [backButton.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
            [backButton.widthAnchor constraintEqualToConstant:44],
            [backButton.heightAnchor constraintEqualToConstant:44],
            [titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-3],
            [titleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:backButton.trailingAnchor constant:4],
            [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-56]
        ]];

        UIView *border = [[UIView alloc] init];
        border.translatesAutoresizingMaskIntoConstraints = NO;
        border.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
        [self.contentView addSubview:border];

        [NSLayoutConstraint activateConstraints:@[
            [border.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
            [border.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
            [border.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-2],
            [border.heightAnchor constraintEqualToConstant:1]
        ]];
    }
    return self;
}

- (void)returnToPreviousPage
{
    UIResponder *responder = self.nextResponder;
    while (responder && ![responder isKindOfClass:UIViewController.class]) {
        responder = responder.nextResponder;
    }
    if ([responder isKindOfClass:UIViewController.class]) {
        UIViewController *controller = (UIViewController *)responder;
        [controller.navigationController popViewControllerAnimated:YES];
    }
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
	return 60;
}

@end
