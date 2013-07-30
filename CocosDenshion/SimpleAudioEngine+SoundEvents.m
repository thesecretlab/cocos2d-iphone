//
//  SimpleAudioEngine+SoundEvents.m
//  ClockPhysics
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

#import "SimpleAudioEngine+SoundEvents.h"

#import "SLConsole.h"

NSString* const SimpleAudioEngineQueueModeAlways = @"always";
NSString* const SimpleAudioEngineQueueModeNever = @"never";
NSString* const SimpleAudioEngineQueueModeReplace = @"replace";

static NSDictionary* _soundEvents = nil;
static NSTimer* _voiceoverTimer = nil;
static ALuint _currentVoiceoverEffect = 0;
static NSMutableArray* _voiceoverQueue = nil;
static NSMutableDictionary* _soundsPlayedOnce = nil;
static NSMutableDictionary* _countersForEvents = nil;

@implementation SimpleAudioEngine (SoundEvents)

+ (NSDictionary*)soundEvents {
    if (_soundEvents == nil) {
        
        // Try and load the file from documents
        NSString* documentsDirectory = [[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject] path];
        NSString* fileName = [documentsDirectory stringByAppendingPathComponent:@"SoundEvents.json"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:fileName]) {
            NSData* data = [NSData dataWithContentsOfFile:fileName];
            NSError* error = nil;
            _soundEvents = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            
            if (error)
                NSLog(@"%@", error);
            else {
                NSLog(@"Using SoundEvents.json in Documents folder");
            }
        }
        
        if (_soundEvents == nil)  {
            NSString* fileName = [[NSBundle mainBundle] pathForResource:@"SoundEvents" ofType:@"json"];
            NSData* data = [NSData dataWithContentsOfFile:fileName];
            NSError* error = nil;
            
            _soundEvents = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                NSLog(@"%@", error);
            } else {
                NSLog(@"Using built-in SoundEvents.json");
            }
        }
        
        
        // Go through all sound events, making sure the files are present
        for (NSString* soundEventKey in [_soundEvents allKeys]) {
            
            id soundEvent = [_soundEvents objectForKey:soundEventKey];
            
            if ([soundEvent isKindOfClass:[NSString class]]) {
                NSString* soundName = soundEvent;
                NSString* path = [self pathForFileNamed:soundName];
                
                if (path == nil)
                    NSLog(@"%@: can't find sound file \"%@\"", soundEventKey, soundName);
                continue;
            } else if ([soundEvent isKindOfClass:[NSDictionary class]]) {
                
                if ([soundEvent objectForKey:@"files"]) {
                    NSArray* files = [soundEvent objectForKey:@"files"];
                    for (NSString* soundFile in files) {
                        NSString* path = [self pathForFileNamed:soundFile];
                        if (path == nil)
                            NSLog(@"%@: can't find sound file \"%@\"", soundEventKey, soundFile);
                    }
                    continue;
                }
                
                if ([soundEvent objectForKey:@"file"]) {
                    NSString* path = [self pathForFileNamed:[soundEvent objectForKey:@"file"]];
                    if (path == nil)
                        NSLog(@"%@: can't find sound file \"%@\"", soundEventKey, [soundEvent objectForKey:@"file"]);
                }
                
                if ([soundEvent objectForKey:@"alternateFile"]) {
                    NSString* path = [self pathForFileNamed:[soundEvent objectForKey:@"alternateFile"]];
                    if (path == nil)
                        NSLog(@"%@: can't find sound file \"%@\"", soundEventKey, [soundEvent objectForKey:@"alternateFile"]);
                }
                
                
                
            }
            
        }
        
    }
    
    return _soundEvents;
}

+ (NSMutableArray*)voiceoverQueue {
    if (_voiceoverQueue == nil)
        _voiceoverQueue = [NSMutableArray array];
    return _voiceoverQueue;
}

+ (NSMutableDictionary*)soundsPlayedOnce {
    if (_soundsPlayedOnce == nil)
        _soundsPlayedOnce = [NSMutableDictionary dictionary];
    
    return _soundsPlayedOnce;
}

- (void) removeAllItemsFromVoiceoverQueue {
    [[SimpleAudioEngine voiceoverQueue] removeAllObjects];
}

- (void) playNextItemInQueue {
    // Only do work if there's something in the queue
    if ([[SimpleAudioEngine voiceoverQueue] count] <= 0)
        return;
    
    NSString* nextEvent = [[SimpleAudioEngine voiceoverQueue] objectAtIndex:0];
    [[SimpleAudioEngine voiceoverQueue] removeObjectAtIndex:0];
    
    [self playSoundForEvent:nextEvent];
}

- (void) addEffectToQueue:(NSString*)effect {
    [[SimpleAudioEngine voiceoverQueue] addObject:effect];
}

+ (NSString*) pathForFileNamed:(NSString*)fileName {
    // try and find the file in documents
    
    if ((id)fileName == [NSNull null])
        return nil;
    
    if ([fileName isEqualToString:@""])
        return nil;
    
    if ([[fileName pathExtension] isEqualToString:@"wav"] == NO && [[fileName pathExtension] isEqualToString:@"mp3"] == NO)
        fileName = [fileName stringByAppendingPathExtension:@"wav"];
    
    NSString* path = nil;
    
    NSString* documentsDirectory = [[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject] path];
    path = [documentsDirectory stringByAppendingPathComponent:fileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    
    // else try and play it from resources
    path = [[NSBundle mainBundle] pathForResource:[fileName stringByDeletingPathExtension] ofType:[fileName pathExtension]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    
    // else just give up
    return nil;
}

- (NSUInteger)playSoundForEvent:(NSString *)eventName completionBlock:(SimpleAudioEngineCompletionBlock)completionBlock {
    
    
    id event = [[SimpleAudioEngine soundEvents] objectForKey:eventName];
    
    NSString* fileName = nil;
    BOOL background = NO;
    BOOL looping = NO;
    NSString* queueMode;
    CGFloat gain = 1.0;
    CGFloat pitch = 1.0;
    
    if ([event isKindOfClass:[NSString class]]) {
        // if we're just mapping events to file names, just play the sound
        
        fileName = [SimpleAudioEngine pathForFileNamed:event];
    } else if ([event isKindOfClass:[NSDictionary class]]) {
        
        if ([event objectForKey:@"limit"]) {
            NSNumber* limit = [event objectForKey:@"limit"];
            if (limit.integerValue > 0) {
                if ([self counterValueForEvent:eventName] >= limit.integerValue) {
                    [[SLConsole sharedConsole] logMessage:@"Event %@ has been played too many times (>%@), skipping", eventName, limit];
                    
                    return 0;
                }
                [self incrementCounterForEvent:eventName];
            }
        }
        
        // If this sound event also triggers other events, kick those off too
        // Note: never create circular references!
        if ([event objectForKey:@"triggersEvents"]) {
            NSArray* otherEvents = [event objectForKey:@"triggersEvents"];
            
            if ([otherEvents isKindOfClass:[NSArray class]] == NO) {
                NSString* reason = [NSString stringWithFormat:@"Sound event %@'s 'triggersEvents' property is not an array", eventName];
                @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:reason userInfo:nil];
            }
            
            for (NSString* soundName in otherEvents) {
                [self playSoundForEvent:soundName];
            }
        }
        
        NSArray* array = [event objectForKey:@"files"];
        if ([array isKindOfClass:[NSArray class]] && array.count > 0) {
            fileName = [array objectAtIndex:rand() % array.count];
            fileName = [SimpleAudioEngine pathForFileNamed:fileName];
        } else {
            fileName = [SimpleAudioEngine pathForFileNamed:[event objectForKey:@"file"]];
        }
        
        if (fileName == nil) {
            
            [[SLConsole sharedConsole] logMessage:@"%@ - no filename was set", eventName];
            return NO;
        }
        
        // If an alternate sound is available, pick it 50% of the time
        if ([event objectForKey:@"alternateFile"]) {
            if (random() % 2 == 1) {
                fileName = [SimpleAudioEngine pathForFileNamed:[event objectForKey:@"alternateFile"]];
            }
        }
        
        background = [[event objectForKey:@"background"] boolValue];
        
        if ([[event objectForKey:@"once"] boolValue] == YES) {
            if ([[SimpleAudioEngine soundsPlayedOnce] objectForKey:eventName]) {
                
                [[SLConsole sharedConsole] logMessage:@"%@ - already played before; dropping.", eventName];
                return NO;
            }
            
            [[SimpleAudioEngine soundsPlayedOnce] setObject:@YES forKey:eventName];
        }
        
        looping = [[event objectForKey:@"loop"] boolValue];
        
        if ([event objectForKey:@"gain"]) {
            gain = [[event objectForKey:@"gain"] floatValue];
            if (gain < 0) gain = 0;
            if (gain > 1) gain = 1;
        }
        
        
        queueMode = [event objectForKey:@"queue"];
        
        if ([event objectForKey:@"pitch-variability"]) {
            CGFloat variability = [[event objectForKey:@"pitch-variability"] floatValue];
            CGFloat randomNumber = (random() % 10000 / 10000.0);
            pitch += randomNumber * (variability + variability) - variability;
            
        }
        
    } else {
        
        [[SLConsole sharedConsole] logMessage:@"%@ - no such event", eventName];
        return NO;
    }
    
    if (!background) {
        
        // No queue mode set? Go ahead and play it!
        // (It will overlap with any currently playing sound.)
        if (queueMode == nil) {
            
            
            
            if (fileName == nil) {
                [[SLConsole sharedConsole] logMessage:@"%@ - can't find file", eventName];
                return NO;
            }
            
            [[SLConsole sharedConsole] logMessage:@"%@ - playing", eventName];
            ALuint effectID = [self playEffect:fileName pitch:pitch pan:0 gain:gain loop:looping];
            
            if (completionBlock != nil) {
                if (looping) {
                    NSLog(@"Sound event %@ was triggered with a completion block, but is set to loop. This block will never be called.", eventName);
                } else {
                    float delayInSeconds = [self durationForEffect:fileName] - 0.1;
                    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
                    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                        
                        completionBlock(effectID);
                    });
                }
            }
            
            return  effectID;
            
        }
        
        // The queue mode is set, but we have a completion block - this isn't currently supported - log to let someone know
        if (completionBlock) {
            NSLog(@"Sound event %@ was triggered with a completion block, but has a queue mode set. This block will never be called.", eventName);
        }
        
        // If the effect is "replace queue", empty the queue
        if ([queueMode isEqualToString: SimpleAudioEngineQueueModeReplace]) {
            [self interruptVoiceover];
        }
        
        // Is the voiceover timer running? If it is, a queued sound is playing
        
        if (_voiceoverTimer != nil) {
            
            // If the effect is "never queue", drop it
            if ([queueMode isEqualToString:SimpleAudioEngineQueueModeNever]) {
                [[SLConsole sharedConsole] logMessage:@"%@ - dropped, queue='never' and something was already playing", eventName];
                return NO;
            }
            
            // If the effect is "always queue", queue it up
            else if ([queueMode isEqualToString:SimpleAudioEngineQueueModeAlways]) {
                [[SLConsole sharedConsole] logMessage:@"%@ - queued", eventName];
                [[SimpleAudioEngine soundsPlayedOnce] removeObjectForKey:eventName];
                
                [self addEffectToQueue:eventName];
                return YES;
            }
            
            // Otherwise, the queue mode is invalid and we should log a warning
            else {
                [[SLConsole sharedConsole] logMessage:@"%@ - invalid queue mode '%@'!", eventName, queueMode];
                return NO;
            }
        } else {
            // The timer is not running. Start it up!
            
            // First, get the duration of this effect.
            float timerDuration = [self durationForEffect:fileName];
            if (timerDuration <= 0) {
                [[SLConsole sharedConsole] logMessage:@"%@ - can't queue, duration <= 0.0 seconds! Missing file?", eventName];
                return NO;
            }
            
            timerDuration += [[event objectForKey:@"padding"] floatValue];
            
            [[SLConsole sharedConsole] logMessage:@"%@ - playing (%.1fs)", eventName, timerDuration];
            
            // Start the timer.
            _voiceoverTimer = [NSTimer scheduledTimerWithTimeInterval:timerDuration target:^{
                _voiceoverTimer = nil;
                _currentVoiceoverEffect = 0;
                [[SLConsole sharedConsole] logMessage:@"%@ - finished", eventName];
                [self playNextItemInQueue];
            } selector:@selector(invoke) userInfo:nil repeats:NO];
            
            // Finally, actually start the thing playing!
            _currentVoiceoverEffect = [self playEffect:fileName pitch:pitch pan:0 gain:gain];
            return _currentVoiceoverEffect;
        }
        
    } else {
        [[SLConsole sharedConsole] logMessage:@"%@ - playing in background (loop: %@)", eventName, looping ? @"yes" : @"no"];
        [self playBackgroundMusic:fileName loop:looping];
        return YES;
    }
}

- (NSMutableDictionary*) countersForEvents {
    if (_countersForEvents == nil)
        _countersForEvents = [NSMutableDictionary dictionary];
    
    return _countersForEvents;
}

- (void) incrementCounterForEvent:(NSString*)eventName {
    NSMutableDictionary* counters = [self countersForEvents];
    
    NSNumber* number = [counters objectForKey:eventName];
    number = @(number.integerValue + 1);
    
    [counters setObject:number forKey:eventName];
}

- (NSInteger) counterValueForEvent:(NSString*)eventName {
    NSMutableDictionary* counters = [self countersForEvents];
    
    NSNumber* number = [counters objectForKey:eventName];
    
    return number.integerValue;
}

- (void) resetCounterForEvent:(NSString*)eventName {
    NSMutableDictionary* counters = [self countersForEvents];
    
    [counters removeObjectForKey:eventName];
    
}

- (NSUInteger) playSoundForEvent:(NSString *)eventName {
    
    return [self playSoundForEvent:eventName completionBlock:nil];
}

- (void)stopSounds {
    [self stopBackgroundMusic];
    self.enabled = NO;
    self.enabled = YES;
    [self removeAllItemsFromVoiceoverQueue];
}

- (void)interruptVoiceover {
    [self stopEffect:_currentVoiceoverEffect];
    [self removeAllItemsFromVoiceoverQueue];
    [_voiceoverTimer invalidate];
    _voiceoverTimer = nil;
}

- (void)markSoundAsPlayed:(NSString *)eventName {
    [[SimpleAudioEngine soundsPlayedOnce] setObject:@YES forKey:eventName];
}

- (void)unmarkSoundsWithPrefixAsPlayed:(NSString *)prefix {
    NSArray* keys = [[SimpleAudioEngine soundsPlayedOnce] allKeys];
    
    for (NSString* soundName in keys) {
        if ([soundName hasPrefix:prefix])
            [[SimpleAudioEngine soundsPlayedOnce] removeObjectForKey:soundName];
    }
}

@end
