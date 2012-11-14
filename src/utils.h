#include <ApplicationServices/ApplicationServices.h>

/* Reverse engineered Space API */
typedef void *CGSConnectionID;
extern CGSConnectionID _CGSDefaultConnection(void);
#define CGSDefaultConnection _CGSDefaultConnection()

typedef uint64_t CGSSpace;
typedef enum _CGSSpaceType {
    kCGSSpaceUser,
    kCGSSpaceFullscreen,
    kCGSSpaceSystem,
    kCGSSpaceUnknown
} CGSSpaceType;
typedef enum _CGSSpaceSelector {
    kCGSSpaceCurrent = 5,
    kCGSSpaceOther = 6,
    kCGSSpaceAll = 7
} CGSSpaceSelector;

extern CFArrayRef CGSCopySpaces(const CGSConnectionID cid, CGSSpaceSelector type);

extern CGSSpaceType CGSSpaceGetType(const CGSConnectionID cid, CGSSpace space);

typedef uint64_t CGSManagedDisplay;
extern CGSManagedDisplay kCGSPackagesMainDisplayIdentifier;

extern bool CGSManagedDisplayIsAnimating(const CGSConnectionID cid, CGSManagedDisplay display);

/* Definitions */

#define WINDOW_NAME_LENGTH 255
#define WINDOWS_ELEMENTS_LENGTH 255
#define SPACE_NAME_LENGTH 255
#define SPACES_ELEMENTS_LENGTH 16

typedef struct {
    CGWindowID wid;
    AXUIElementRef uiElement;
    char *name;
    CGPoint pos;
    CGSize size;
} Window;

typedef struct {
    Window **elements;
} Windows;

typedef struct {
    CGSSpace spaceId;
    char xmonadName[SPACE_NAME_LENGTH];
} Space;

typedef struct {
    int keyCode;
    int altKey;
    int commandKey;
    int controlKey;
    int shiftKey;
} Event;

Event globalEvent;
Space globalSpaces[SPACES_ELEMENTS_LENGTH];
uint32_t globalSpacesLength = 0;
int currentSpaceIndex = -1;

int getSpacesCount();
void setupSpaces(int count, char **xmonadNames);
void changeToSpace(char *xmonadName);

int getWindows(Windows *);
void freeWindows(Windows *);
void setWindow(Window *);
void setWindowFocused(Window *);

void getFrame(CGPoint *, CGSize *);
bool isMainDisplayTransitioning();

void setupEventCallback();
void collectEvent();
