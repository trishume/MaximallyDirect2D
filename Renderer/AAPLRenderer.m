/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of renderer class which performs Metal setup and per frame rendering
*/

@import simd;
@import MetalKit;

#import "AAPLRenderer.h"

// Header shared between C code here, which executes Metal API commands, and .metal files, which
//   uses these types as inputs to the shaders
#import "AAPLShaderTypes.h"

#import "sys/kdebug_signpost.h"

#include "Networking.h"

static const AAPLVertex QUAD_VERTS[] =
    {
        // Pixel positions, RGBA colors
        { { -30,   30 },    { 1, 0, 0, 1 } },
        { {  30,   30 },    { 0, 0, 1, 1 } },
        { { -30,  -30 },    { 0, 1, 0, 1 } },

        { {  30,  -30 },    { 1, 0, 0, 1 } },
        { { -30,  -30 },    { 0, 1, 0, 1 } },
        { {  30,   30 },    { 0, 0, 1, 1 } },
    };
static const NSUInteger NUM_VERTICES_PER_QUAD = sizeof(QUAD_VERTS) / sizeof(AAPLVertex);


@implementation AAPLRenderer
{
    id<MTLDevice> _device;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLCommandQueue> _commandQueue;
    MTKView *_view;

    // GPU buffer which will contain our vertex array
    id<MTLBuffer> _vertexBuffer;

    vector_uint2 _viewportSize;

    // The number of vertices in our vertex buffer;
    NSUInteger _numVertices;
    AAPLVertex *_verts;

    int _sendSocket;
    bool _blockEvents;

    MPSemaphoreID _needsDisplay;
}

/// Initialize with the MetalKit view from which we'll obtain our Metal device
- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView
{
    self = [super init];
    if(self)
    {
        _device = mtkView.device;
        [self loadMetal:mtkView];
    }

    return self;
}

/// Creates a grid of 25x15 quads (i.e. 72000 bytes with 2250 vertices are to be loaded into
///   a vertex buffer)
+ (void)setQuad:(NSUInteger)index verts:(AAPLVertex *)verts at:(vector_float2)posn
{
    // const NSUInteger NUM_COLUMNS = 25;
    // const NSUInteger NUM_ROWS = 15;
    // const float QUAD_SPACING = 50.0;

    // NSUInteger dataSize = sizeof(QUAD_VERTS) * NUM_COLUMNS * NUM_ROWS;
    // NSMutableData *vertexData = [[NSMutableData alloc] initWithLength:dataSize];

    AAPLVertex* quad = verts + (index*NUM_VERTICES_PER_QUAD);

    // vector_float2 upperLeftPosition;
    // upperLeftPosition.x = ((-((float)NUM_COLUMNS) / 2.0) + column) * QUAD_SPACING + QUAD_SPACING/2.0;
    // upperLeftPosition.y = ((-((float)NUM_ROWS) / 2.0) + row) * QUAD_SPACING + QUAD_SPACING/2.0;

    memcpy(quad, &QUAD_VERTS, sizeof(QUAD_VERTS));

    for (NSUInteger vertexInQuad = 0; vertexInQuad < NUM_VERTICES_PER_QUAD; vertexInQuad++) {
        quad[vertexInQuad].position += posn;
    }

    // quad += 6;
}

- (void)moveQuad:(NSUInteger)index by:(vector_float2)delta {
    // if(_blockEvents) return;
    _blockEvents = YES;

    AAPLVertex *quad = _verts + (index*NUM_VERTICES_PER_QUAD);

    // NSLog(@"posn: %f", quad[0].position.y);
    for (NSUInteger vertexInQuad = 0; vertexInQuad < NUM_VERTICES_PER_QUAD; vertexInQuad++) {
        quad[vertexInQuad].position += delta;
    }

//    [_vertexBuffer didModifyRange:NSMakeRange(index*sizeof(QUAD_VERTS), sizeof(QUAD_VERTS))];
    sendData(_sendSocket, quad, sizeof(QUAD_VERTS), 9730+index);
    sendData(_sendSocket, quad, sizeof(QUAD_VERTS), 9740+index);
    // NSLog(@"sendem");
    kdebug_signpost(0,0,0,0,0);
    // [_view draw];
}


- (vector_float2)quadPos:(NSUInteger)index {
    AAPLVertex *quad = _verts + (index*NUM_VERTICES_PER_QUAD);
    return (quad[0].position + quad[3].position) * 0.5;
}

- (vector_uint2)viewportSize {
    return _viewportSize;
}

- (void)listenForIndex:(NSNumber *)indexNum {
    NSUInteger index = [indexNum unsignedLongValue];
    AAPLVertex *quad = _verts + (index*NUM_VERTICES_PER_QUAD);
    // NSLog(@"%lu hi there", index);
    int socket = createSocket(9730+index);
    if(!socket) socket = createSocket(9740+index);
    while(true) {
        listenData(socket, quad, sizeof(QUAD_VERTS));
        // NSLog(@"gotem");
        kdebug_signpost(1,0,0,0,0);
        // [_view draw];
        // [_view setNeedsDisplay];
        MPSignalSemaphore(_needsDisplay);
    }
}

- (void)renderThread {
    while(true) {
        MPWaitOnSemaphore(_needsDisplay, kDurationForever);
        [_view draw];
    }
}

/// Create our Metal render state objects including our shaders and render state pipeline objects
- (void)loadMetal:(nonnull MTKView *)mtkView
{
    MPCreateSemaphore(1, 0, &_needsDisplay);
    _blockEvents = YES;

    mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    mtkView.paused = YES;
    // mtkView.enableSetNeedsDisplay = YES;
    _view = mtkView;

    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];

    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"Simple Pipeline";
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;

    NSError *error = NULL;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                             error:&error];
    if (!_pipelineState)
    {
        // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
        //  If the Metal API validation is enabled, we can find out more information about what
        //  went wrong.  (Metal API validation is enabled by default when a debug build is run
        //  from Xcode)
        NSLog(@"Failed to created pipeline state, error %@", error);
    }

    NSUInteger numQuads = 3;
    _numVertices = NUM_VERTICES_PER_QUAD * numQuads;
    NSUInteger dataSize = sizeof(QUAD_VERTS) * numQuads;

    // Create a vertex buffer by allocating storage that can be read by the GPU
    _vertexBuffer = [_device newBufferWithLength:dataSize
                                         options:MTLResourceStorageModeShared];

    // Fill buffer
    _verts = _vertexBuffer.contents;
    vector_float2 posn;
    posn.x = 0.0;
    posn.y = 0.0;
    [AAPLRenderer setQuad:0 verts:_verts at:posn];
    posn.x = 90.0;
    [AAPLRenderer setQuad:1 verts:_verts at:posn];
    posn.x = 180.0;
    [AAPLRenderer setQuad:2 verts:_verts at:posn];

    // Copy the vertex data into the vertex buffer by accessing a pointer via
    // the buffer's `contents` property
//    memcpy(_vertexBuffer.contents, vertexData.bytes, vertexData.length);
    [mtkView draw];

    _commandQueue = [_device newCommandQueue];

    _sendSocket = createSocket(0);

    NSNumber *indexNum = [NSNumber numberWithUnsignedLong: 0];
    [NSThread detachNewThreadSelector:@selector(listenForIndex:) toTarget:self withObject:indexNum];
    indexNum = [NSNumber numberWithUnsignedLong: 1];
    [NSThread detachNewThreadSelector:@selector(listenForIndex:) toTarget:self withObject:indexNum];
    indexNum = [NSNumber numberWithUnsignedLong: 2];
    [NSThread detachNewThreadSelector:@selector(listenForIndex:) toTarget:self withObject:indexNum];

    [NSThread detachNewThreadSelector:@selector(renderThread) toTarget:self withObject:nil];
}

/// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    // Save the size of the drawable as we'll pass these
    //   values to our vertex shader when we draw
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
    [view draw];
}

/// Called whenever the view needs to render a frame
- (void)drawInMTKView:(nonnull MTKView *)view
{
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if(renderPassDescriptor != nil)
    {
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        // Set the region of the drawable to which we'll draw.
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, _viewportSize.x, _viewportSize.y, -1.0, 1.0 }];

        [renderEncoder setRenderPipelineState:_pipelineState];

        // We call -[MTLRenderCommandEncoder setVertexBuffer:offset:atIndex:] to send data in our
        //   preloaded MTLBuffer from our ObjC code here to our Metal 'vertexShader' function
        // This call has 3 arguments
        //   1) buffer - The buffer object containing the data we want passed down
        //   2) offset - They byte offset from the beginning of the buffer which indicates what
        //      'vertexPointer' point to.  In this case we pass 0 so data at the very beginning is
        //      passed down.
        //      We'll learn about potential uses of the offset in future samples
        //   3) index - An integer index which corresponds to the index of the buffer attribute
        //      qualifier of the argument in our 'vertexShader' function.  Note, this parameter is
        //      the same as the 'index' parameter in
        //              -[MTLRenderCommandEncoder setVertexBytes:length:atIndex:]
        //
        [renderEncoder setVertexBuffer:_vertexBuffer
                                offset:0
                               atIndex:AAPLVertexInputIndexVertices];

        [renderEncoder setVertexBytes:&_viewportSize
                               length:sizeof(_viewportSize)
                              atIndex:AAPLVertexInputIndexViewportSize];

        // Draw the vertices of the quads
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:_numVertices];

        [renderEncoder endEncoding];

        [commandBuffer presentDrawable:view.currentDrawable];
    }

    [commandBuffer commit];
    kdebug_signpost(2,0,0,0,0);
    _blockEvents = NO;
}

@end
