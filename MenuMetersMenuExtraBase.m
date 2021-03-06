//
//  NSMenuExtraBase.m
//  MenuMeters
//
//  Created by Yuji on 2015/08/01.
//
//

#import "MenuMetersMenuExtraBase.h"
#import "MenuMeterWorkarounds.h"

#import "MenuMeterCPUExtra.h"
#import "MenuMeterDiskExtra.h"
#import "MenuMeterMemExtra.h"
#import "MenuMeterNetExtra.h"

@implementation MenuMetersMenuExtraBase
-(instancetype)initWithBundleID:(NSString*)bundleID
{
    self=[super initWithBundle:[NSBundle mainBundle]];
    self.bundleID=bundleID;
    return self;
}
-(void)willUnload {
    [updateTimer invalidate];
    updateTimer = nil;
    [super willUnload];
}
-(void)timerFired:(id)notused
{
    NSImage *oldCanvas = statusItem.button.image;
    NSImage *canvas = oldCanvas;
    NSSize imageSize = NSMakeSize(self.length, self.view.frame.size.height);
    NSSize oldImageSize = canvas.size;
    if (imageSize.width != oldImageSize.width || imageSize.height != oldImageSize.height) {
        canvas = [[NSImage alloc] initWithSize:imageSize];
    }
    
    NSImage *image = self.image;
    [canvas lockFocus];
    [image drawAtPoint:CGPointZero fromRect:(CGRect) {.size = image.size} operation:NSCompositeCopy fraction:1.0];
    [canvas unlockFocus];
    
    if (canvas != oldCanvas) {
        statusItem.button.image = canvas;
    } else {
        [statusItem.button displayRectIgnoringOpacity:statusItem.button.bounds];
    }
}
- (void)configDisplay:(NSString*)bundleID fromPrefs:(MenuMeterDefaults*)ourPrefs withTimerInterval:(NSTimeInterval)interval
{
    if([ourPrefs loadBoolPref:bundleID defaultValue:YES]){
        if(!statusItem){
            statusItem=[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
            if(@available(macOS 10.12,*)){
//                statusItem.autosaveName=self.bundleID;
                statusItem.behavior=NSStatusItemBehaviorRemovalAllowed;
                [statusItem addObserver:self forKeyPath:@"visible" options:NSKeyValueObservingOptionNew context:nil];
            }
            statusItem.menu = self.menu;
            statusItem.menu.delegate = self;
        }
        [updateTimer invalidate];
        updateTimer=[NSTimer timerWithTimeInterval:interval target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
        [updateTimer setTolerance:.2*interval];
        [[NSRunLoop currentRunLoop] addTimer:updateTimer forMode:NSRunLoopCommonModes];
    }else if(![ourPrefs loadBoolPref:bundleID defaultValue:YES] && statusItem){
        [self removeStatusItem];
    }
}
-(void)removeStatusItem
{
    [updateTimer invalidate];
    [[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
    statusItem=nil;
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"menuExtraUnloaded" object:self.bundleID]];
}
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if(@available(macOS 10.12,*)){
        if(object==statusItem){
            if(!statusItem.visible){
                [self removeStatusItem];
            }
        }
    }
}
- (void)openMenuMetersPref:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"openPref" object:self]];
}
- (void)openActivityMonitor:(id)sender {

    if (![[NSWorkspace sharedWorkspace] launchApplication:@"Activity Monitor.app"]) {
        NSLog(@"MenuMeter unable to launch the Activity Monitor.");
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(),^{
        if(@available(macOS 10.15,*)){
            int tab=1;
            if([self isKindOfClass:[MenuMeterCPUExtra class]]){
                tab=1;
            }
            if([self isKindOfClass:[MenuMeterDiskExtra class]]){
                tab=4;
            }
            if([self isKindOfClass:[MenuMeterMemExtra class]]){
                tab=2;
            }
            if([self isKindOfClass:[MenuMeterNetExtra class]]){
                tab=5;
            }
            NSString*source=[NSString stringWithFormat:@"tell application \"System Events\" to tell process \"Activity Monitor\" to click radio button %@ of radio group 1 of group 2 of toolbar of window 1", @(tab)];
            NSAppleScript*script=[[NSAppleScript alloc] initWithSource:source];
            NSDictionary* errorDict=nil;
            [script executeAndReturnError:&errorDict];
            if(errorDict){
                NSLog(@"%@",errorDict);
            }
        }
    });
} // openActivityMonitor
- (void)addStandardMenuEntriesTo:(NSMenu*)extraMenu
{
    NSMenuItem* menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:NSLocalizedString(kOpenActivityMonitorTitle, kOpenActivityMonitorTitle)
                                                              action:@selector(openActivityMonitor:)
                                                       keyEquivalent:@""];
    [menuItem setTarget:self];
    menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:NSLocalizedString(kOpenMenuMetersPref, kOpenMenuMetersPref)
                                                  action:@selector(openMenuMetersPref:)
                                           keyEquivalent:@""];
    [menuItem setTarget:self];

}
- (void)setupAppearance {
    if(@available(macOS 10.14,*)){
        [NSAppearance setCurrentAppearance:[NSAppearance appearanceNamed:IsMenuMeterMenuBarDarkThemed()?NSAppearanceNameDarkAqua:NSAppearanceNameAqua]];
    }
}
#pragma mark NSMenuDelegate
- (void)menuNeedsUpdate:(NSMenu*)menu {
    statusItem.menu = self.menu;
    statusItem.menu.delegate = self;
}
- (void)menuWillOpen:(NSMenu*)menu {
    _isMenuVisible = YES;
}
- (void)menuDidClose:(NSMenu*)menu {
    _isMenuVisible = NO;
}

@end
