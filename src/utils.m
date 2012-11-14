#include "utils.h"

#import <AppKit/NSApplication.h>
#import <AppKit/NSScreen.h>

#include <Carbon/Carbon.h>

int getSpacesCount() {
    CFArrayRef spaces = CGSCopySpaces(CGSDefaultConnection, kCGSSpaceAll);
    int count = CFArrayGetCount(spaces) - 1;
    CFRelease(spaces);
    return count;
}

void setupSpaces(int xmonadCount, char **xmonadNames) {
    if(xmonadCount > SPACES_ELEMENTS_LENGTH) {
        xmonadCount = SPACES_ELEMENTS_LENGTH;
    }

    CFArrayRef spaces = CGSCopySpaces(CGSDefaultConnection, 7);
    uint32_t count = CFArrayGetCount(spaces);

    // Go through Spaces backwards. Seems to give correct order on my
    // computer.

    int i;
    for(i = count - 1; i >= 0 && globalSpacesLength < xmonadCount; i--) {
        CGSSpace spaceId = [CFArrayGetValueAtIndex(spaces, i) intValue];
        if(CGSSpaceGetType(CGSDefaultConnection, spaceId) == kCGSSpaceSystem)
            continue;

        Space *dest = &globalSpaces[globalSpacesLength];

        dest->spaceId = spaceId;

        strncpy(dest->xmonadName, xmonadNames[globalSpacesLength], SPACE_NAME_LENGTH - 1);
        dest->xmonadName[SPACE_NAME_LENGTH - 1] = '\0';

        globalSpacesLength++;
    }

    CFRelease(spaces);
}

void changeToSpace(char *xmonadName) {
    int i;
    for(i = 0; i < globalSpacesLength; i++) {
        if(strcmp(globalSpaces[i].xmonadName, xmonadName) != 0) continue;
        if(i == currentSpaceIndex) return;

        currentSpaceIndex = i;

        CFArrayRef currentSpace = CGSCopySpaces(CGSDefaultConnection, kCGSSpaceCurrent);
        uint64_t currentSpaceId = [CFArrayGetValueAtIndex(currentSpace, 0) intValue];
        CFRelease(currentSpace);

        NSNumber *n;
        NSArray *toChange;

        n = [NSNumber numberWithUnsignedLongLong:currentSpaceId];
        toChange = [NSArray arrayWithObjects:&n count:1];
        CGSHideSpaces(CGSDefaultConnection, toChange);

        n = [NSNumber numberWithUnsignedLongLong:globalSpaces[i].spaceId];
        toChange = [NSArray arrayWithObjects:&n count:1];
        CGSShowSpaces(CGSDefaultConnection, toChange);

        CGSManagedDisplaySetCurrentSpace(CGSDefaultConnection, kCGSPackagesMainDisplayIdentifier, globalSpaces[i].spaceId);

        return;
    }
}

void getProcessWindows(ProcessSerialNumber *psn, CFArrayRef *windows) {
    pid_t pid;
    GetProcessPID(psn, &pid);
    AXUIElementRef app = AXUIElementCreateApplication(pid);

    CFBooleanRef boolRef;
    AXUIElementCopyAttributeValue(app, kAXHiddenAttribute, &boolRef);
    if(boolRef == NULL || CFBooleanGetValue(boolRef)) {
        *windows = NULL;
    } else {
        AXUIElementCopyAttributeValue(app, kAXWindowsAttribute, windows);
    }

    CFRelease(app);
}

void getWindowTitle(CFStringRef *windowTitle, AXUIElementRef window) {
    AXUIElementCopyAttributeValue(window, kAXTitleAttribute, windowTitle);
}

CGPoint getWindowPosition(AXUIElementRef window) {
    AXValueRef valueRef;
    CGPoint pos;

    AXUIElementCopyAttributeValue(window, kAXPositionAttribute, &valueRef);
    AXValueGetValue(valueRef, kAXValueCGPointType, &pos);
    CFRelease(valueRef);

    return pos;
}

void setWindowPosition(CGPoint point, AXUIElementRef window) {
    AXValueRef valueRef = AXValueCreate(kAXValueCGPointType, &point);
    AXUIElementSetAttributeValue(window, kAXPositionAttribute, valueRef);
    CFRelease(valueRef);
}

CGSize getWindowSize(AXUIElementRef window) {
    AXValueRef valueRef;
    CGSize size;

    AXUIElementCopyAttributeValue(window, kAXSizeAttribute, &valueRef);
    AXValueGetValue(valueRef, kAXValueCGSizeType, &size);
    CFRelease(valueRef);

    return size;
}

void setWindowSize(CGSize size, AXUIElementRef window) {
    AXValueRef valueRef = AXValueCreate(kAXValueCGSizeType, &size);
    AXUIElementSetAttributeValue(window, kAXSizeAttribute, valueRef);
    CFRelease(valueRef);
}

bool isMainDisplayTransitioning() {
    return CGSManagedDisplayIsAnimating(CGSDefaultConnection, kCGSPackagesMainDisplayIdentifier);
}

void setWindow(Window *window) {
    setWindowPosition(window->pos, window->uiElement);
    setWindowSize(window->size, window->uiElement);
}

void setWindowFocused(Window *window) {
    AXUIElementSetAttributeValue(window->uiElement, kAXMainAttribute, kCFBooleanTrue);

    AXUIElementRef application;
    AXUIElementCopyAttributeValue(window->uiElement, kAXParentAttribute, &application);
    AXUIElementSetAttributeValue(application, kAXFrontmostAttribute, kCFBooleanTrue);
}

void addWindows(CFArrayRef windows, Windows *context, int *count) {
    int j;
    for(j = 0; j < CFArrayGetCount(windows) && *count < WINDOWS_ELEMENTS_LENGTH; j++) {
        AXUIElementRef window = CFArrayGetValueAtIndex(windows, j);

        CFBooleanRef boolRef;
        AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute, &boolRef);
        if(boolRef == NULL || CFBooleanGetValue(boolRef)) {
            continue;
        }

        CFStringRef windowTitle;
        getWindowTitle(&windowTitle, window);
        if(windowTitle == NULL) continue;

        char *buffer = malloc(sizeof(char) * WINDOW_NAME_LENGTH);
        CFStringGetCString(windowTitle, buffer, WINDOW_NAME_LENGTH, kCFStringEncodingUTF8);

        context->elements[*count] = malloc(sizeof(Window));
        _AXUIElementGetWindow(window, &context->elements[*count]->wid);
        context->elements[*count]->uiElement = window;
        context->elements[*count]->name = buffer;
        context->elements[*count]->size = getWindowSize(window);
        context->elements[*count]->pos = getWindowPosition(window);

        (*count)++;
    }
}

int getWindows(Windows *context) {
    int count = 0;

    context->elements = malloc(sizeof(Window*) * WINDOWS_ELEMENTS_LENGTH);
    memset(context->elements, 0, sizeof(Window*) * WINDOWS_ELEMENTS_LENGTH);

    ProcessSerialNumber psn = {0, kNoProcess};
    while(!GetNextProcess(&psn)) {
        CFArrayRef windows;
        getProcessWindows(&psn, &windows);
        if(windows == NULL) continue;

        addWindows(windows, context, &count);
    }

    return count;
}

void freeWindows(Windows *context) {
    int i;
    for(i = 0; context->elements[i] != NULL; i++) {
        free(context->elements[i]->name);
        context->elements[i]->name = NULL;

        free(context->elements[i]);
        context->elements[i] = NULL;
    }
    free(context->elements);
    context->elements = NULL;
}

void getFrame(CGPoint *pos, CGSize *size) {
    NSRect frame = [[NSScreen mainScreen] frame];
    NSRect visibleFrame = [[NSScreen mainScreen] visibleFrame];

    // The origin is not setup correct when reading the origin.
    // MenuBar is always up the top. Calculate where the "proper" origin is.
    pos->y = frame.size.height - visibleFrame.size.height;
    //pos->y = visibleFrame.origin.y;

    pos->x = visibleFrame.origin.x;
    size->width = visibleFrame.size.width;
    size->height = visibleFrame.size.height;
}

void collectEvent() {
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, INT_MAX, YES);
}

CGEventRef callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *ref) {
    globalEvent.keyCode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);

    CGEventFlags eventMask = CGEventGetFlags(event);
    globalEvent.altKey = (eventMask & kCGEventFlagMaskAlternate) != 0;
    globalEvent.commandKey = (eventMask & kCGEventFlagMaskCommand) != 0;
    globalEvent.controlKey = (eventMask & kCGEventFlagMaskControl) != 0;
    globalEvent.shiftKey = (eventMask & kCGEventFlagMaskShift) != 0;

    return event;
}

void setupEventCallback() {
    CGEventMask eventMask = CGEventMaskBit(kCGEventKeyDown);
    CFMachPortRef eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionListenOnly, eventMask, callback, NULL);

    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);

    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);

    CGEventTapEnable(eventTap, YES);
}
