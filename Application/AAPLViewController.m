/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of our cross-platform view controller
*/

#import "AAPLViewController.h"
#import "AAPLRenderer.h"

#include "KeyCodes.h"

@implementation AAPLViewController
{
    MTKView *_view;

    AAPLRenderer *_renderer;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Set the view to use the default device
    _view = (MTKView *)self.view;

    // https://stackoverflow.com/questions/41675193/how-to-request-use-of-integrated-gpu-when-using-metal-api
    NSArray<id<MTLDevice>> *devices = MTLCopyAllDevices();

    _view.device = nil;
    // Low power device is sufficient - try to use it!
    for (id<MTLDevice> device in devices) {
        if (device.isLowPower) {
            _view.device = device;
            break;
        }
    }

    // below: probably not necessary since there is always
    // integrated GPU, but doesn't hurt.
    if (_view.device == nil)
        _view.device = MTLCreateSystemDefaultDevice();

    if(!_view.device)
    {
        NSLog(@"Metal is not supported on this device");
        return;
    }

    _renderer = [[AAPLRenderer alloc] initWithMetalKitView:_view];

    if(!_renderer)
    {
        NSLog(@"Renderer failed initialization");
        return;
    }

    // Initialize our renderer with the view size
    [_renderer mtkView:_view drawableSizeWillChange:_view.drawableSize];

    _view.delegate = _renderer;

    // [_view.window makeFirstResponder:self];
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^(NSEvent *event) {
        [self keyDown: event];
        return event;
    }];
}

- (void)keyDown:(NSEvent *)event {
//    NSLog(@"keyDown Detected");
    vector_float2 delta;
    delta.x = 0.0;
    delta.y = 0.0;

    if(event.keyCode == kVK_ANSI_E)
        delta.y = 10.0;
    if(event.keyCode == kVK_ANSI_D)
        delta.y = -10.0;
    if(event.keyCode == kVK_ANSI_S)
        delta.x = -10.0;
    if(event.keyCode == kVK_ANSI_F)
        delta.x = 10.0;

    if(delta.x != 0.0 || delta.y != 0.0) {
        [_renderer moveQuad:0 by:delta];
    }

    // Player 2
    delta.x = 0.0;
    delta.y = 0.0;

    if(event.keyCode == kVK_UpArrow)
        delta.y = 10.0;
    if(event.keyCode == kVK_DownArrow)
        delta.y = -10.0;
    if(event.keyCode == kVK_LeftArrow)
        delta.x = -10.0;
    if(event.keyCode == kVK_RightArrow)
        delta.x = 10.0;

    if(delta.x != 0.0 || delta.y != 0.0) {
        [_renderer moveQuad:1 by:delta];
    }
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

@end
