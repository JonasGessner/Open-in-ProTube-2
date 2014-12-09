//
//  OpeninProTube2.x
//  Open in ProTube 2
//
//  Created by Jonas Gessner on 09.12.2014.
//  Copyright (c) 2014 Jonas Gessner. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <substrate.h>
#import "SBUserAgent.h"

NS_INLINE BOOL pt2Available(void) {
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"pt2://"]];
}

NS_INLINE BOOL ptAvailable(void) {
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"protube://"]];
}

NS_INLINE BOOL anyAvailable(void) {
    return ptAvailable() || pt2Available();
}

NS_INLINE NSDictionary *dictionaryWithQueryString(NSString *string) {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    NSArray *fields = [string componentsSeparatedByString:@"&"];
    
    for (NSString *field in fields) {
        NSArray *pair = [field componentsSeparatedByString:@"="];
        if (pair.count == 2) {
            NSString *key = [pair firstObject];
            NSString *value = pair.lastObject;
            
            dictionary[key] = value;
        }
    }
    
    return dictionary.copy;
}

typedef NS_ENUM(NSUInteger, PTURLResourceType) {
    PTURLResourceTypeNone = 0,
    PTURLResourceTypeVideo,
    PTURLResourceTypeChannel,
    PTURLResourceTypePlaylist,
    PTURLResourceTypeSearch
};

NS_INLINE NSString *searchTermFromURL(NSURL *URL) {
    NSString *host = URL.host;
    if ([host hasPrefix:@"www."]) {
        host = [host substringFromIndex:4];
    }
    else if ([host hasPrefix:@"m."]) {
        host = [host substringFromIndex:2];
    }
    
    if ([host isEqualToString:@"youtube.com"]) {
        if ([URL.path isEqualToString:@"/results"]) {
            NSDictionary *dict = dictionaryWithQueryString(URL.query);
            NSString *query = dict[@"search_query"];
            
            if (query == nil) {
                query = dict[@"q"];
            }
            
            return query;
        }
    }
    
    return nil;
}


NS_INLINE NSString *playlistIDFromURL(NSURL *URL) {
    NSString *host = URL.host;
    if ([host hasPrefix:@"www."]) {
        host = [host substringFromIndex:4];
    }
    else if ([host hasPrefix:@"m."]) {
        host = [host substringFromIndex:2];
    }
    
    if ([host isEqualToString:@"youtube.com"]) {
        NSString *path = URL.path;
        
        NSMutableArray *components = [[path componentsSeparatedByString:@"/"] mutableCopy];
        
        while (components.firstObject != nil && [components.firstObject length] == 0) {
            [components removeObjectAtIndex:0];
        }
        
        while (components.lastObject != nil && [components.lastObject length] == 0) {
            [components removeLastObject];
        }
        
        if (components.count == 1 && [components.firstObject isEqualToString:@"playlist"]) {
            NSDictionary *query = dictionaryWithQueryString(URL.query);
            
            NSString *ID = query[@"list"];
            
            if (ID.length) {
                return ID;
            }
            
        }
    }
    
    return nil;
}

NS_INLINE NSString *channelIDFromURL(NSURL *URL, BOOL *channelName) {
    NSString *host = URL.host;
    if ([host hasPrefix:@"www."]) {
        host = [host substringFromIndex:4];
    }
    else if ([host hasPrefix:@"m."]) {
        host = [host substringFromIndex:2];
    }
    
    if ([host isEqualToString:@"youtube.com"]) {
        NSString *path = URL.path;
        
        NSMutableArray *components = [[path componentsSeparatedByString:@"/"] mutableCopy];
        
        while (components.firstObject != nil && [components.firstObject length] == 0) {
            [components removeObjectAtIndex:0];
        }
        
        while (components.lastObject != nil && [components.lastObject length] == 0) {
            [components removeLastObject];
        }
        
        if (components.count == 1 && URL.query.length == 0) {
            if (channelName) {
                *channelName = YES;
            }
            
            return components.firstObject;
        }
        else if (components.count == 2) {
            if ([components.firstObject isEqualToString:@"user"]) {
                if (channelName) {
                    *channelName = YES;
                }
                
                return components.lastObject;
            }
            else if ([components.firstObject isEqualToString:@"channel"]) {
                
                return components.lastObject;
            }
        }
    }
    
    return nil;
}

NS_INLINE NSString *videoIDFromURL(NSURL *URL) {
    if ([URL.scheme isEqualToString:@"youtube"]) {
        return URL.resourceSpecifier;
    }
    else {
        NSString *host = URL.host;
        if ([host hasPrefix:@"www."]) {
            host = [host substringFromIndex:4];
        }
        else if ([host hasPrefix:@"m."]) {
            host = [host substringFromIndex:2];
        }
        
        if ([host isEqualToString:@"youtube.com"]) {
            if ([URL.path isEqualToString:@"/watch"]) {
                NSDictionary *dict = dictionaryWithQueryString(URL.query);
                return dict[@"v"];
            }
        }
        else if ([host isEqualToString:@"youtu.be"]) {
            return [URL.path substringFromIndex:1];
        }
    }
    
    return nil;
}

//Type cannot be nil
NS_INLINE NSString *getResourceFromURL(NSURL *URL, PTURLResourceType *type, BOOL *channelIsUser) {
    NSString *videoID = videoIDFromURL(URL);
    
    if (videoID) {
        *type = PTURLResourceTypeVideo;
        return videoID;
    }
    
    NSString *channel = channelIDFromURL(URL, channelIsUser);
    
    if (channel) {
        *type = PTURLResourceTypeChannel;
        return channel;
    }
    
    NSString *playlist = playlistIDFromURL(URL);
    
    if (playlist) {
        *type = PTURLResourceTypePlaylist;
        return playlist;
    }
    
    NSString *term = searchTermFromURL(URL);
    
    if (term) {
        *type = PTURLResourceTypeSearch;
        return term;
    }
    
    return nil;
}

NSURL *buildProTubeURL(NSString *resource, PTURLResourceType type, BOOL channelIsUser) {
    BOOL pt2 = pt2Available();
    
    NSMutableString *URLString = [NSMutableString stringWithString:(pt2 ? @"pt2://" : @"protube://")];
    
    if (type == PTURLResourceTypeVideo) {
        if (pt2) {
            [URLString appendFormat:@"video/%@", resource];
        }
        else {
            [URLString appendFormat:@"m.youtube.com/watch?v=%@", resource];
        }
    }
    else if (type == PTURLResourceTypePlaylist && pt2) {
        [URLString appendFormat:@"playlist/%@", resource];
    }
    else if (type == PTURLResourceTypeChannel && pt2) {
        if (channelIsUser) {
            [URLString appendFormat:@"user/%@", resource];
        }
        else {
            [URLString appendFormat:@"channel/%@", resource];
        }
    }
    else if (type == PTURLResourceTypeSearch && pt2) {
        [URLString appendFormat:@"search/%@", resource];
    }
    else {
        return nil;
    }
    
    return [NSURL URLWithString:URLString];
}

%group iOS5

%hook SpringBoard

- (void)_openURLCore:(NSURL *)URL display:(id)arg2 publicURLsOnly:(BOOL)arg3 animating:(BOOL)arg4 additionalActivationFlag:(unsigned int)arg5 {
    if (anyAvailable) {
        PTURLResourceType type = 0;
        BOOL isUsername = NO;
        NSString *resource = getResourceFromURL(URL, &type, &isUsername);
        
        if (resource != nil) {
            NSURL *ptURL = buildProTubeURL(resource, type, isUsername);
            
            if (ptURL != nil) {
                [(SBUserAgent *)[%c(SBUserAgent) sharedUserAgent] openURL:ptURL animateIn:YES scale:0.0f start:0.0f duration:0.3f animateOut:YES];
                return;
            }
        }
    }
    
    %orig;
}

%end

%end



%group iOS6

%hook SpringBoard

- (void)_openURLCore:(NSURL *)URL display:(id)arg2 animating:(BOOL)arg3 sender:(id)arg4 additionalActivationFlags:(id)arg5 {
    if (anyAvailable) {
        PTURLResourceType type = 0;
        BOOL isUsername = NO;
        NSString *resource = getResourceFromURL(URL, &type, &isUsername);
        
        if (resource != nil) {
            NSURL *ptURL = buildProTubeURL(resource, type, isUsername);
            
            if (ptURL != nil) {
                [(SBUserAgent *)[%c(SBUserAgent) sharedUserAgent] openURL:ptURL animateIn:YES scale:0.0f start:0.0f duration:0.3f animateOut:YES];
                return;
            }
        }
    }
    
    %orig;
}

%end

%end


%group iOS7

%hook SpringBoard

- (void)_openURLCore:(NSURL *)URL display:(id)arg2 animating:(BOOL)arg3 sender:(id)arg4 additionalActivationFlags:(id)arg5 activationHandler:(id)arg6 {
    if (anyAvailable) {
        PTURLResourceType type = 0;
        BOOL isUsername = NO;
        NSString *resource = getResourceFromURL(URL, &type, &isUsername);
        
        if (resource != nil) {
            NSURL *ptURL = buildProTubeURL(resource, type, isUsername);
            
            if (ptURL != nil) {
                [[UIApplication sharedApplication] openURL:ptURL];
                return;
            }
        }
    }
    
    %orig;
}

%end

%end



%group iOS71

%hook SpringBoard

- (void)_openURLCore:(NSURL *)URL display:(id)arg2 animating:(BOOL)arg3 sender:(id)arg4 activationContext:(id)arg5 activationHandler:(id)arg6 {
    if (anyAvailable) {
        PTURLResourceType type = 0;
        BOOL isUsername = NO;
        NSString *resource = getResourceFromURL(URL, &type, &isUsername);
        
        if (resource != nil) {
            NSURL *ptURL = buildProTubeURL(resource, type, isUsername);
            
            if (ptURL != nil) {
                [[UIApplication sharedApplication] openURL:ptURL];
                return;
            }
        }
    }
    
    %orig;
}

%end

%end




%group iOS8

%hook SpringBoard

- (void)_openURLCore:(NSURL *)URL display:(id)arg2 animating:(BOOL)arg3 sender:(id)arg4 activationSettings:(id)arg5 withResult:(id)arg6 {
    if (anyAvailable) {
        PTURLResourceType type = 0;
        BOOL isUsername = NO;
        NSString *resource = getResourceFromURL(URL, &type, &isUsername);
        
        if (resource != nil) {
            NSURL *ptURL = buildProTubeURL(resource, type, isUsername);
            
            if (ptURL != nil) {
                [[UIApplication sharedApplication] openURL:ptURL];
                return;
            }
        }
    }
    
    %orig;
}

%end

%end


NS_INLINE NSString *getPT2Path(void) {
    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    
    if (!searchPaths.count) {
        return nil;
    }
    
    NSString *pathFile = [[searchPaths firstObject] stringByAppendingPathComponent:@"/Caches/com.apple.mobile.installation.plist"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:pathFile]) {
        NSString *p = @"/private/var/mobile/Containers/Bundle/Application";
        NSArray *containers = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:p error:nil];
        
        for (NSString *container in containers) {
            NSString *path = [p stringByAppendingPathComponent:container];
            
            NSArray *app = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
            
            for (NSString *file in app) {
                if ([file.pathExtension isEqualToString:@"app"] && [file hasPrefix:@"ProTube 2"]) {
                    NSString *ptPath = [path stringByAppendingPathComponent:file];
                    return ptPath;
                }
            }
        }
        
        return nil;
    }
    
    NSDictionary *file = [NSDictionary dictionaryWithContentsOfFile:pathFile];
    NSDictionary *user = file[@"User"];
    NSDictionary *pt = user[@"de.j-gessner.protube2"];
    
    if (!pt) {
        return nil;
    }
    
    NSString *path = pt[@"Path"];
    
    return path;
}

#ifndef NSFoundationVersionNumber_iOS_8_0
#define NSFoundationVersionNumber_iOS_8_0 1139.10
#endif

%ctor {
    @autoreleasepool {
        if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_8_0) {
            %init(iOS8);
        }
        else if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_1) {
            %init(iOS71);
        }
        else if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0) {
            %init(iOS7);
        }
        else if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_6_0) {
            %init(iOS6);
        }
        else if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_5_0) {
            %init(iOS5);
        }
        
        NSString *path = getPT2Path();
        
        if (path != nil) {
            NSString *infoPath = [path stringByAppendingPathComponent:@"Info.plist"];
            
            NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath];
            
            if ([info[@"CFBundleIdentifier"] hasPrefix:@"de.j-gessner."]) {
                NSMutableArray *types = info[@"CFBundleURLTypes"];
                
                NSMutableDictionary *type = [types firstObject];
                
                NSMutableArray *schemes = type[@"CFBundleURLSchemes"];
                
                if (![schemes containsObject:@"youtube"]) {
                    [schemes addObject:@"youtube"];
                    
                    type[@"CFBundleURLSchemes"] = schemes;
                    types[0] = type;
                    info[@"CFBundleURLTypes"] = types;
                    
                    if ([info writeToFile:infoPath atomically:YES]) {
                        system("uicache");
                    }
                }
            }
        }
    }
}
