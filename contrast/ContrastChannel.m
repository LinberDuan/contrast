//
//  ContrastChannel.m
//  contrast
//
//  Created by Johan Halin on 9.7.2015.
//  Copyright © 2015 Aero Deko. All rights reserved.
//

#import "ContrastChannel.h"

#define PI2   6.28318530717f // pi * 2
#define I_64K 0.000015259f // 1 / 65535

static const float ContrastChannelFrequencyMinimum = 40.0f;
static const float ContrastChannelFrequencyMaximum = 3000.0f;

@interface ContrastChannel ()
@property (nonatomic) AEAudioUnitFilter *reverbEffect;
@end

@implementation ContrastChannel
{
	float sampleRate;
	float invertedSampleRate;
	float angle;
	float previousActive;
	float previousVolume;
}

#pragma mark - AEAudioPlayable

static float getFrequencyFromPosition(float frequencyPosition)
{
	return ContrastChannelFrequencyMinimum + ((ContrastChannelFrequencyMaximum - ContrastChannelFrequencyMinimum) * convertToNonLinear(frequencyPosition));
}

static inline float convertToNonLinear(float value)
{
	return (value * value); // *shrug* you're not my dad
}

static OSStatus renderCallback(ContrastChannel *this, AEAudioController *audioController, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio)
{
	float frequency = getFrequencyFromPosition(this->_frequencyPosition);
	BOOL active = (this->_view != nil);
	BOOL shouldFadeOut = (active == NO && this->previousActive == YES);
	float startVolume = convertToNonLinear(this->_volume);
	float volume = startVolume;
	float previousVolume = this->previousVolume;
	BOOL volumeChanged = (volume != previousVolume);
	BOOL interpolating = shouldFadeOut || volumeChanged;

	// might want to interpolate between frequencies too, but I don't feel that's too important
	
	NSInteger interpolationMax = frames / 2;

	for (NSInteger i = 0; i < frames; i++)
	{
		if (i < interpolationMax)
		{
			float interpolationPosition = (float)i / (float)interpolationMax;
			
			if (shouldFadeOut)
			{
				volume = (startVolume * (1.0f - interpolationPosition));
			}
			else if (volumeChanged)
			{
				volume = previousVolume + ((startVolume - previousVolume) * interpolationPosition);
			}
		}
		else
		{
			interpolating = NO;
		}
		
		float sample;
		
		if (active || interpolating)
		{
			float angle = this->angle + (PI2 * frequency * this->invertedSampleRate);
			angle = fmodf(angle, PI2);
			this->angle = angle;
			
			float noise = ((float)(arc4random_uniform(131070) * I_64K) - 1.0f) * this->_noiseAmount;
			
			sample = (sin(angle) + convertToNonLinear(noise)) * volume;
		}
		else
		{
			sample = 0;
		}

		sample = clamp(sample, -1.0f, 1.0f);
		
		((float *)audio->mBuffers[0].mData)[i] = sample;
		((float *)audio->mBuffers[1].mData)[i] = sample;
	}
	
	this->previousActive = active;
	this->previousVolume = startVolume;
	
	return noErr;
}

static inline float clamp(float value, float min, float max)
{
	if (value < min)
	{
		value = min;
	}
	else if (value > max)
	{
		value = max;
	}
	
	return value;
}

- (AEAudioControllerRenderCallback)renderCallback
{
	return &renderCallback;
}

#pragma mark - Properties

- (AEAudioUnitFilter *)reverbEffect
{
	return _reverbEffect;
}

- (void)setFrequencyPosition:(float)frequencyPosition
{
	@synchronized(self)
	{
		_frequencyPosition = clamp(frequencyPosition, 0, 1);
	}
}

- (void)setVolume:(float)volume
{
	@synchronized(self)
	{
		volume = clamp(volume, 0, 1);
		
		// the real volume is 0.1 .. 1. if you want silence, remove the dang channel
		_volume = 0.1f + (0.9f * volume);
	}
}

- (void)setReverbAmount:(float)reverbAmount
{
	@synchronized(self)
	{
		_reverbAmount = clamp(reverbAmount, 0, 1);

		NSInteger amount = self.reverbAmount * 100;
		
		AudioUnitSetParameter(self.reverbEffect.audioUnit, kReverb2Param_DryWetMix, kAudioUnitScope_Global, 0, amount, 0);
	}
}

- (void)setNoiseAmount:(float)noiseAmount
{
	@synchronized(self)
	{
		_noiseAmount = clamp(noiseAmount, 0, 1);
	}
}

#pragma mark - Public

- (instancetype)initWithSampleRate:(float)aSampleRate reverbEffect:(AEAudioUnitFilter *)reverbEffect
{
	if ((self = [super init]))
	{
		self->sampleRate = aSampleRate;
		self->invertedSampleRate = 1.0f / aSampleRate;
		self->angle = 0;
		self->_frequencyPosition = 0.5f;
		self->_volume = 0.5f;
		self->previousActive = NO;
		self->previousVolume = 0.25f; // ugh.. this has to be set so that a volume change isn't triggered on start, and this is obviously the converted volume value :/
		self->_noiseAmount = 0;
		
		AudioUnitSetParameter(reverbEffect.audioUnit, kReverb2Param_DryWetMix, kAudioUnitScope_Global, 0, 0, 0);
		AudioUnitSetParameter(reverbEffect.audioUnit, kReverb2Param_DecayTimeAt0Hz, kAudioUnitScope_Global, 0, 3.0, 0);
		AudioUnitSetParameter(reverbEffect.audioUnit, kReverb2Param_DecayTimeAtNyquist, kAudioUnitScope_Global, 0, 3.0, 0);
		
		_reverbEffect = reverbEffect;
	}
	
	return self;
}

@end
