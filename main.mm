#include <Metal/Metal.h>
#include <Metal/MTLDevice.h>

#include <MetalKit/MetalKit.h>

#include <QuartzCore/CAMetalLayer.h>
#include <QuartzCore/CVDisplayLink.h>

static float vertexData[] = {
    0.0f, 0.87f, 1.0f, 0.0f,    1.0f, 0.0f, 0.0f, 1.0f,
    0.5f, 0.0f,  0.0f, 0.0f,    0.0f, 1.0f, 0.0f, 1.0f,
   -0.5f, 1.0f,  0.0f, 0.0f,    0.0f, 0.0f, 1.0f, 1.0f,
};

static NSString *shaderLib = @"\n"
"#include <metal_stdlib>\n"
"#include <simd/simd.h>\n"
"\n"
"using namespace metal;\n"
"\n"
"typedef struct\n"
"{\n"
"    float4 position;\n"
"    float4 color;\n"
"} VertexIn;\n"
"\n"
"typedef struct {\n"
"    float4 position [[position]];\n"
"    half4  color;\n"
"} VertexOut;\n"
"\n"
"vertex VertexOut vertex_function(device VertexIn *vertices [[buffer(0)]],\n"
"                                 uint vid [[vertex_id]])\n"
"{\n"
"    VertexOut out;\n"
"    out.position = vertices[vid].position;\n"
"    out.color = half4(vertices[vid].color);\n"
"    return out;\n"
"}\n"
"\n"
"fragment half4 fragment_function(VertexOut in [[stage_in]])\n"
"{\n"
"    return half4(1.0, 1.0, 1.0, 1.0);\n"
"}\n";

@interface Renderer : NSObject<MTKViewDelegate>
// Long-lived Metal objects
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLLibrary> defaultLibrary;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;

// Vertex buffer
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@end

@implementation Renderer
- (id)init:(MTKView *)view {
    self = [super init];
    if (!self) {
        return self;
    }

    [self setupMetal:view];
    [self buildPipeline];
    return self;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size
{
}

- (void)setupMetal:(MTKView *)view {
    // Create the default Metal device
    self.device = view.device;

    // Create a long-lived command queue
    self.commandQueue = [self.device newCommandQueue];

    // Comile shaders
    MTLCompileOptions* compileOptions = [MTLCompileOptions new];
    compileOptions.languageVersion = MTLLanguageVersion1_1;
    NSError* compileError;
    self.defaultLibrary = [self.device newLibraryWithSource:shaderLib
                                                    options:compileOptions
                                                      error:&compileError];
    if (!self.defaultLibrary) {
        NSLog(@"Failed to compile shaders, error:\n%@", compileError);
    }
}

- (void)buildPipeline {
    // Generate a vertex buffer for holding the vertex data of the triangle
    self.vertexBuffer = [self.device newBufferWithBytes:vertexData
                                                 length:sizeof(vertexData)
                                                options:MTLResourceOptionCPUCacheModeDefault];

    // Fetch the vertex and fragment functions from the library
    id<MTLFunction> vertexProgram = [self.defaultLibrary newFunctionWithName:@"vertex_function"];
    id<MTLFunction> fragmentProgram = [self.defaultLibrary newFunctionWithName:@"fragment_function"];

    // Build a render pipeline descriptor with the desired functions
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    [pipelineStateDescriptor setVertexFunction:vertexProgram];
    [pipelineStateDescriptor setFragmentFunction:fragmentProgram];
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    // Compile the render pipeline
    NSError *error = NULL;
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    if (!self.pipelineState) {
        NSLog(@"Failed to created pipeline state, error %@", error);
    }
}

- (void)drawInMTKView:(MTKView *)view {
    [self update];

    // command buffer
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];

    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    // encoder
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderEncoder setRenderPipelineState:self.pipelineState];
    [renderEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
    [renderEncoder setFragmentBuffer:self.vertexBuffer offset:0 atIndex:0];

    // draw command encoded here!
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [renderEncoder endEncoding];

    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (void)update {
}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
}
@end

@implementation AppDelegate
- (id)init {
    self = [super init];
    if (!self) {
        return self;
    }

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    MTKView *mtkView = [[MTKView alloc] init];
    mtkView.device = device;
    mtkView.delegate = [[Renderer alloc] init:mtkView];

    // Window and application stuff
    NSViewController* controller = [[NSViewController alloc] init]; //initWithNibName:nil bundle:nil];
    [controller setView:mtkView];
    [controller viewDidLoad];

    NSRect frame = NSMakeRect(100, 300, 640, 480);
    NSUInteger styleMask =
        NSWindowStyleMaskTitled |
        NSWindowStyleMaskResizable |
        NSWindowStyleMaskClosable |
        NSWindowStyleMaskMiniaturizable;
    NSBackingStoreType backing = NSBackingStoreBuffered;
    window = [[NSWindow alloc] initWithContentRect:frame styleMask:styleMask backing:backing defer:YES];
    [window setContentView:mtkView];
    return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    [window makeKeyAndOrderFront:self];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        NSApplication* app = [NSApplication sharedApplication];
        AppDelegate* appDelegate = [[AppDelegate alloc] init];

        [app setDelegate:appDelegate];
        [app run];
    }

    return EXIT_SUCCESS;
}
