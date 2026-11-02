#ifndef MultitouchBridge_h
#define MultitouchBridge_h

#include <stdint.h>
#include <CoreFoundation/CoreFoundation.h>

// Struct layouts for Apple's private MultitouchSupport.framework.
// These are the community-documented layouts used by many open-source
// trackpad tools. Function symbols are loaded with dlsym in
// MultitouchService.swift so nothing here links against the framework.

typedef struct {
    float x;
    float y;
} MTPoint;

typedef struct {
    MTPoint position;
    MTPoint velocity;
} MTVector;

typedef enum {
    MTTouchStateNotTracking = 0,
    MTTouchStateStartInRange = 1,
    MTTouchStateHoverInRange = 2,
    MTTouchStateMakeTouch = 3,
    MTTouchStateTouching = 4,
    MTTouchStateBreakTouch = 5,
    MTTouchStateLingerInRange = 6,
    MTTouchStateOutOfRange = 7
} MTTouchState;

typedef struct {
    int32_t frame;
    double timestamp;
    int32_t identifier;
    int32_t state;
    int32_t fingerID;
    int32_t handID;
    MTVector normalized;   // position.x / position.y in 0...1, origin bottom-left
    float total;           // contact size / pressure
    int32_t pad0;
    float angle;
    float majorAxis;
    float minorAxis;
    MTVector absolute;     // millimetres
    int32_t pad1;
    int32_t pad2;
    float density;
} MTTouch;

typedef void *MTDeviceRef;
typedef void *MTActuatorRef;

typedef int32_t (*MTFrameCallback)(MTDeviceRef device,
                                   MTTouch *touches,
                                   int32_t count,
                                   double timestamp,
                                   int32_t frame);

#endif
