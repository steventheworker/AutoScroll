//
//  app.h
//  AutoScroll
//
//  Created by Steven G on 8/20/23.
//

#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

NS_ASSUME_NONNULL_BEGIN

@interface app : NSObject
+ (void) init;
+ (void) mousedown: (CGEventRef) e : (CGEventType) etype;
+ (void) mouseup: (CGEventRef) e : (CGEventType) etype;
+ (void) mousemove: (CGEventRef) e : (CGEventType) etype;
+ (void) startListening;
+ (void) stopListening;
+ (void) openPrefs;
@end

NS_ASSUME_NONNULL_END
