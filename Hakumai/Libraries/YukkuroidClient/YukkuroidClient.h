//
//  YukkuroidClient.h
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/26/15.
//  Copyright © 2015 Hiroyuki Onishi. All rights reserved.
//

// based on YukkuroidRPCClient; reference implementation of Yukkuroid API.
// http://www.yukkuroid.com/#history

#import <Foundation/Foundation.h>

@interface YukkuroidClient : NSObject

#pragma mark - functions on Yukkuroid Panel
#pragma mark top left
+(void)setKanjiText:(NSString *)string_UTF8;
+(NSString *)getKanjiText;
+(void)pushKoeTextGenerateButton;

#pragma mark top right
+(void)setKoeText:(NSString *)string_UTF8;
+(NSString *)getKoeText;
+(void)pushKoeTextClearButton;

#pragma mark bottom left
+(void)setVoiceType:(int)index setting:(int)setting;
+(int)getVoiceType:(int)setting;
+(void)setVoiceEffect:(int)index setting:(int)setting;
+(int)getVoiceEffect:(int)setting;
+(void)setIntonation:(BOOL)isOn setting:(int)setting;
+(BOOL)getIntonation:(int)setting;

#pragma mark bottom center
+(void)pushPlayButton:(int)setting;
+(void)pushStopButton:(int)setting;
+(void)pushSaveButton:(int)setting;

#pragma mark bottom right
+(void)setVoiceSpeed:(int)speed setting:(int)setting;
+(int)getVoiceSpeed:(int)setting;
+(void)setVoiceVolume:(int)volume setting:(int)setting;
+(int)getVoiceVolume:(int)setting;

#pragma mark - original functions
+(NSNumber *)getVersion;
+(BOOL)isStillPlaying:(int)setting;
+(void)playSync:(int)setting;

@end
