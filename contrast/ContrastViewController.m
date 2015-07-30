//
//  ViewController.m
//  contrast
//
//  Created by Johan Halin on 6.7.2015.
//  Copyright © 2015 Aero Deko. All rights reserved.
//

#import "ContrastViewController.h"
#import "ContrastChannelView.h"
#import "ContrastChannelController.h"

static const NSInteger ContrastMaximumChannelCount = 8;

@interface ContrastViewController () <ContrastChannelViewDelegate>
@property (nonatomic) NSMutableArray *channels; // FIXME: maybe this isn't necessary
@property (nonatomic) ContrastChannelController *channelController;
@property (nonatomic) UILabel *introLabel;
@property (nonatomic) UIView *patternView;
@end

@implementation ContrastViewController

#pragma mark - Private

- (float)_frequencyPositionFromPoint:(CGPoint)point
{
	CGFloat heightRatio = point.y / self.view.bounds.size.height;
	CGFloat widthModifier = ((point.x / self.view.bounds.size.width) / 10.0) - 0.05;
	
	return (1.0f - heightRatio) + widthModifier;
}

- (float)_noiseAmountFromPoint:(CGPoint)point
{
	CGFloat width = self.view.bounds.size.width;
	CGFloat minThreshold = width * 0.1;
	CGFloat maxThreshold = width - minThreshold;
	
	if (point.x < minThreshold)
	{
		return 1.0f - (float)(point.x / minThreshold);
	}
	else if (point.x > maxThreshold)
	{
		return 1.0f - (float)((width - point.x) / minThreshold);
	}
	
	return 0;
}

- (float)_panPositionFromPoint:(CGPoint)point
{
	CGFloat halfWidth = self.view.bounds.size.width / 2.0;
	CGFloat panPosition = (point.x / halfWidth) - 1.0;
	
	return (float)panPosition;
}

- (void)_addChannelAtPoint:(CGPoint)point
{
	if (self.channels.count >= ContrastMaximumChannelCount)
	{
		// TODO: Maybe indicate somehow that more channels cannot be added?
		
		return;
	}
	
	if (self.introLabel != nil)
	{
		[UIView animateWithDuration:UINavigationControllerHideShowBarDuration animations:^{
			self.introLabel.alpha = 0;
		} completion:^(BOOL finished) {
			[self.introLabel removeFromSuperview];
			self.introLabel = nil;
		}];
	}
	
	ContrastChannelView *channelView = [[ContrastChannelView alloc] initWithCenter:point delegate:self];
	channelView.alpha = 0;
	channelView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0, 0);
	[self.view addSubview:channelView];
	[self.channels addObject:channelView];
	[self.channelController addView:channelView];
	[self.channelController updateChannelWithView:channelView
								frequencyPosition:[self _frequencyPositionFromPoint:point]
										   volume:0.5f
									 effectAmount:0
									  noiseAmount:[self _noiseAmountFromPoint:point]
									  panPosition:[self _panPositionFromPoint:point]];
	
	[UIView animateWithDuration:UINavigationControllerHideShowBarDuration delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:0 animations:^{
		channelView.alpha = 1;
		channelView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1, 1);
	} completion:nil];
}

- (void)_removeChannel:(ContrastChannelView *)channelView
{
	[self.channelController removeView:channelView];

	[UIView animateWithDuration:(UINavigationControllerHideShowBarDuration * 2.0) delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:0 animations:^{
		channelView.alpha = 0;
		channelView.transform = CGAffineTransformRotate(channelView.transform, M_PI_4);
		channelView.transform = CGAffineTransformScale(channelView.transform, 0.1, 0.1);
	} completion:^(BOOL finished) {
		[self.channels removeObject:channelView];
		[channelView removeFromSuperview];
	}];
}

- (void)_doubleTapRecognized:(UITapGestureRecognizer *)tapRecognizer
{
	CGPoint location = [tapRecognizer locationInView:self.view];
	UIView *view = [self.view hitTest:location withEvent:nil];
	
	if (view == self.view)
	{
		[self _addChannelAtPoint:location];
	}
}

- (float)_effectAmountFromRotation:(CGFloat)rotation
{
	if (rotation >= 0)
	{
		float amount = (float)(rotation / (M_PI * 2.0));

		if (amount > 1)
		{
			amount = 1;
		}
		
		return amount;
	}
	else
	{
		return 0;
	}
}

- (void)_startBackgroundPatternAnimation
{
	UIImage *patternImage = [[UIImage imageNamed:@"pattern"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	CGRect frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds) + patternImage.size.width, CGRectGetHeight(self.view.bounds));

	if (self.patternView == nil)
	{
		UIView *patternView = [[UIView alloc] initWithFrame:frame];
		patternView.backgroundColor = [UIColor colorWithPatternImage:patternImage];
		patternView.userInteractionEnabled = NO;
		[self.view addSubview:patternView];
		
		self.patternView = patternView;
	}
	else
	{
		self.patternView.frame = frame;
	}
	
	CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position.x"];
	CGFloat from = frame.size.width / 2.0;
	animation.fromValue = @(from);
	animation.toValue = @(from - patternImage.size.width);
	animation.duration = 1;
	animation.repeatCount = MAXFLOAT;
	[self.patternView.layer addAnimation:animation forKey:@"animation"];
}

- (void)_willEnterForeground:(NSNotification *)notification
{
	[self _startBackgroundPatternAnimation];
}

#pragma mark - ContrastChannelViewDelegate

- (void)channelView:(ContrastChannelView *)channelView updatedWithPosition:(CGPoint)position scale:(CGFloat)scale rotation:(CGFloat)rotation
{
	[self.channelController updateChannelWithView:channelView
								frequencyPosition:[self _frequencyPositionFromPoint:position]
										   volume:(scale - 0.5f)
									 effectAmount:[self _effectAmountFromRotation:rotation]
									  noiseAmount:[self _noiseAmountFromPoint:position]
									  panPosition:[self _panPositionFromPoint:position]];
}

- (void)channelViewReceivedTap:(ContrastChannelView *)channelView
{
	[self.channelController viewWasTouched:channelView];
}

- (void)channelViewReceivedDoubleTap:(ContrastChannelView *)channelView
{
	[self _removeChannel:channelView];
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
	
	self.view.backgroundColor = CONTRAST_COLOR_CYAN;
	
	UILabel *label = [[UILabel alloc] initWithFrame:self.view.bounds];
	label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	label.backgroundColor = [UIColor clearColor];
	label.font = [UIFont boldSystemFontOfSize:56.0];
	label.textColor = CONTRAST_COLOR_OUTLINE;
	label.numberOfLines = 0;
	label.lineBreakMode = NSLineBreakByCharWrapping;
	label.text = NSLocalizedString(@"Contrast by Johan & Jaakko Please use headphones Double-tap to begin", nil);
	[self.view addSubview:label];

	self.introLabel = label;
	
	self.channels = [[NSMutableArray alloc] init];
	self.channelController = [[ContrastChannelController alloc] init];
	
	UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_doubleTapRecognized:)];
	doubleTapRecognizer.numberOfTapsRequired = 2;
	[self.view addGestureRecognizer:doubleTapRecognizer];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	[self _startBackgroundPatternAnimation];
}

- (BOOL)prefersStatusBarHidden
{
	return YES;
}

@end
