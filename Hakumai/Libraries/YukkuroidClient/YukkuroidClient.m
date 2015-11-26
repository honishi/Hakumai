//
//  YukkuroidClient.m
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/26/15.
//  Copyright © 2015 Hiroyuki Onishi. All rights reserved.
//

#import "YukkuroidClient.h"

@implementation YukkuroidClient

+(NSProxy *)getYukProxy {
    return [NSConnection rootProxyForConnectionWithRegisteredName:@"com.yukkuroid.rpc" host:@""];
}

#pragma mark - on panel
#pragma mark upper left
+(void)setKanjiText:(NSString *)utf8{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    [(id)proxy setKanjiText:utf8];
}

+(NSString *)getKanjiText{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    return [(id)proxy getKanjiText];
}

+(void)pushKoeTextGenerateButton{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    [(id)proxy pushKoeTextGenerateButton];
}

#pragma mark upper right
+(void)setKoeText:(NSString *)utf8{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    [(id)proxy setKoeText:utf8];
}

+(NSString *)getKoeText{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    return [(id)proxy getKoeText];
}

+(void)pushKoeTextClearButton{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    [(id)proxy pushKoeTextClearButton];
}

#pragma mark bottom left
+(void)setVoiceType:(int)index setting:(int)setting{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    [(id)proxy setVoiceType:index setting:setting];
}

+(int)getVoiceType:(int)setting{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    return [(id)proxy getVoiceType:setting];
}

+(void)setVoiceEffect:(int)index setting:(int)setting{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    [(id)proxy setVoiceEffect:index setting:setting];
}

+(int)getVoiceEffect:(int)setting{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    return [(id)proxy getVoiceEffect:setting];
}

+(void)setIntonation:(BOOL)isOn setting:(int)setting{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    // [(id)proxy setVoiceIntonation:isOn setting:setting];
    [(id)proxy setIntonation:isOn setting:setting];
}

+(BOOL)getIntonation:(int)setting{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    return [(id)proxy getIntonation:setting];
}

#pragma mark bottom center
+(void)pushPlayButton:(int)setting{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    [(id)proxy pushPlayButton:setting];
}

+(void)pushStopButton:(int)setting{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    [(id)proxy pushStopButton:setting];
}

+(void)pushSaveButton:(int)setting{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    [(id)proxy pushSaveButton:setting];
}

#pragma mark bottom right
+ (void)setVoiceSpeed:(int)speed setting:(int)setting{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    [(id)proxy setVoiceSpeed:speed setting:setting];
}

+ (int)getVoiceSpeed:(int)setting{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    return [(id)proxy getVoiceSpeed:setting];
}

+ (void)setVoiceVolume:(int)volume setting:(int)setting{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    [(id)proxy setVoiceVolume:volume setting:setting];
}

+ (int)getVoiceVolume:(int)setting{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    return [(id)proxy getVoiceVolume:setting];
}

#pragma mark - original functions
+ (BOOL)isAvailable {
    return [YukkuroidClient getYukProxy] != nil;
}

+ (NSNumber *)getVersion{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    return [(id)proxy getVersion];
}

+ (BOOL)isStillPlaying:(int)setting{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    return [(id)proxy isStillPlaying:setting];
}

+ (void)playSync:(int)setting{
    NSProxy *proxy = [YukkuroidClient getYukProxy];
    [(id)proxy playSync:setting];
}

@end
