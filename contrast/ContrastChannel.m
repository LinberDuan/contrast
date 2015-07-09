//
//  ContrastChannel.m
//  contrast
//
//  Created by Johan Halin on 9.7.2015.
//  Copyright © 2015 Aero Deko. All rights reserved.
//

#import "ContrastChannel.h"

#define PI2 6.28318530717f // pi * 2

static const float ContrastChannelFrequencyMinimum = 100.0f;
static const float ContrastChannelFrequencyMaximum = 2000.0f;

@interface ContrastChannel ()
@end

@implementation ContrastChannel
{
	float sampleRate;
	float invertedSampleRate;
	float angle;
}

#pragma mark - AEAudioPlayable

static float getFrequencyFromPosition(float frequencyPosition)
{
	return ContrastChannelFrequencyMinimum + ((ContrastChannelFrequencyMaximum - ContrastChannelFrequencyMinimum) * frequencyPosition);
}

static OSStatus renderCallback(ContrastChannel *this, AEAudioController *audioController, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio)
{
	float frequency = getFrequencyFromPosition(this->_frequencyPosition);
	BOOL active = (this->_view != nil);
	
	for (NSInteger i = 0; i < frames; i++)
	{
		float sample;
		
		if (active)
		{
			float angle = this->angle + (PI2 * frequency * this->invertedSampleRate);
			angle = fmodf(angle, PI2);
			this->angle = angle;
			
			sample = sin(angle);
		}
		else
		{
			sample = 0;
		}
		
		((float *)audio->mBuffers[0].mData)[i] = sample;
		((float *)audio->mBuffers[1].mData)[i] = sample;
	}
	
	return noErr;
}

- (AEAudioControllerRenderCallback)renderCallback
{
	return &renderCallback;
}

#pragma mark - Properties

- (void)setFrequencyPosition:(float)frequencyPosition
{
	@synchronized(self)
	{
		if (frequencyPosition < 0)
		{
			frequencyPosition = 0;
		}
		else if (frequencyPosition > 1)
		{
			frequencyPosition = 1;
		}
		
		_frequencyPosition = frequencyPosition;
	}
}

#pragma mark - Public

- (instancetype)initWithSampleRate:(float)aSampleRate
{
	if ((self = [super init]))
	{
		self->sampleRate = aSampleRate;
		self->invertedSampleRate = 1.0f / aSampleRate;
		self->angle = 0;
		self->_frequencyPosition = 0.5f;
	}
	
	return self;
}

@end
