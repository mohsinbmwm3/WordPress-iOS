#import "BlogDetailHeaderView.h"
#import "Blog.h"
#import "UIImageView+Gravatar.h"
#import <WordPress-iOS-Shared/WPFontManager.h>

const CGFloat BlogDetailHeaderViewBlavatarSize = 40.0;
const CGFloat BlogDetailHeaderViewLabelHeight = 16.0;
const CGFloat BlogDetailHeaderViewLabelHorizontalPadding = 10.0;
const CGFloat BlogDetailHeaderViewLabelVerticalPadding = 3.0;

@interface BlogDetailHeaderView ()

@property (nonatomic, strong) UIImageView *blavatarImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;

@end

@implementation BlogDetailHeaderView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _blavatarImageView = [self imageViewForBlavatar];
        [self addSubview:_blavatarImageView];

        _titleLabel = [self labelForTitle];
        [self addSubview:_titleLabel];

        _subtitleLabel = [self labelForSubtitle];
        [self addSubview:_subtitleLabel];

        [self configureConstraints];
    }
    return self;
}

#pragma mark - Public Methods

- (void)setBlog:(Blog *)blog
{
    [self.blavatarImageView setImageWithBlavatarUrl:blog.blavatarUrl isWPcom:blog.isWPcom];
    [self.titleLabel setText:blog.blogName];
    [self.subtitleLabel setText:blog.url];
}

#pragma mark - Private Methods

- (void)configureConstraints
{
    NSDictionary *views = NSDictionaryOfVariableBindings(_blavatarImageView, _titleLabel, _subtitleLabel);
    NSDictionary *metrics = @{@"blavatarSize": @(BlogDetailHeaderViewBlavatarSize),
                              @"labelHeight":@(BlogDetailHeaderViewLabelHeight),
                              @"labelHorizontalPadding": @(BlogDetailHeaderViewLabelHorizontalPadding),
                              @"labelVerticalPadding": @(BlogDetailHeaderViewLabelVerticalPadding)};
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_blavatarImageView(blavatarSize)]|"
                                                                 options:0
                                                                 metrics:metrics
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[_blavatarImageView(blavatarSize)]-labelHorizontalPadding-[_titleLabel]|"
                                                                 options:0
                                                                 metrics:metrics
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[_blavatarImageView(blavatarSize)]-labelHorizontalPadding-[_subtitleLabel]|"
                                                                 options:0
                                                                 metrics:metrics
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-labelVerticalPadding-[_titleLabel(labelHeight)]-labelVerticalPadding-[_subtitleLabel(labelHeight)]"
                                                                 options:0
                                                                 metrics:metrics
                                                                   views:views]];
    [super setNeedsUpdateConstraints];
}

#pragma mark - Subview factories

- (UILabel *)labelForTitle
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.numberOfLines = 1;
    label.backgroundColor = [UIColor clearColor];
    label.opaque = YES;
    label.textColor = [WPStyleGuide littleEddieGrey];
    label.font = [WPFontManager openSansRegularFontOfSize:13.0];
    label.adjustsFontSizeToFitWidth = NO;

    return label;
}

- (UILabel *)labelForSubtitle
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.numberOfLines = 1;
    label.backgroundColor = [UIColor clearColor];
    label.opaque = YES;
    label.textColor = [WPStyleGuide allTAllShadeGrey];
    label.font = [WPFontManager openSansRegularFontOfSize:13.0];
    label.adjustsFontSizeToFitWidth = NO;

    return label;
}

- (UIImageView *)imageViewForBlavatar
{
    CGRect blavatarFrame = CGRectMake(0.0f, 0.0f, BlogDetailHeaderViewBlavatarSize, BlogDetailHeaderViewBlavatarSize);
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:blavatarFrame];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.layer.borderColor = [[UIColor whiteColor] CGColor];
    imageView.layer.borderWidth = 1.0;
    return imageView;
}

@end
