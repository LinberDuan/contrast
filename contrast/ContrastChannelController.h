//
//  ContrastChannelController.h
//  contrast
//
//  Created by Johan Halin on 9.7.2015.
//  Copyright © 2015 Aero Deko. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ContrastChannelView;

@interface ContrastChannelController : NSObject

- (void)addView:(ContrastChannelView *)channelView frequencyPosition:(float)frequencyPosition;
- (void)removeView:(ContrastChannelView *)channelView;

- (void)updateChannelWithView:(ContrastChannelView *)channelView
			frequencyPosition:(float)frequencyPosition
					   volume:(float)volume;

@end
