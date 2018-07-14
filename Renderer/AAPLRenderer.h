/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header for renderer class which performs Metal setup and per frame rendering
*/

@import MetalKit;

// Our platform independent renderer class
@interface AAPLRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView;
- (void)moveQuad:(NSUInteger)index by:(vector_float2)delta;
- (vector_float2)quadPos:(NSUInteger)index;
- (vector_uint2)viewportSize;

@end
