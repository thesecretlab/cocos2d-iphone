//
//  SimpleAudioEngine+SoundEvents.h
//
//  Created by Jon Manning on 29/02/12.
//  Copyright (c) 2012 Secret Lab. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "SimpleAudioEngine.h"


typedef void(^SimpleAudioEngineCompletionBlock)(NSUInteger soundID);


@interface SimpleAudioEngine (SoundEvents)

// Play a sound with a given name. Returns the sound's ID. This may be an invalid sound ID, if something prevented the sound from playing.
- (NSUInteger) playSoundForEvent:(NSString*)eventName;


- (NSUInteger) playSoundForEvent:(NSString*)eventName completionBlock:(SimpleAudioEngineCompletionBlock)completionBlock;

// Stop the background music and clear the voiceover queue
- (void) stopSounds; 

// Interrupt the current voiceover line, and clear the voiceover queue.
// Cutting a line halfway through doesn't sound great, so use with caution.
- (void) interruptVoiceover;

// Mark a sound has having been played. Does not stop currently-playing sounds.
- (void) markSoundAsPlayed:(NSString*)eventName;

// Unmark sounds with a given prefix as played
- (void) unmarkSoundsWithPrefixAsPlayed:(NSString*)prefix;

- (void) resetCounterForEvent:(NSString*)eventName;

@end
